local http = require("resty.http")
local JSON = require("JSON")
--local pretty = require('pl.pretty')
local jwt = require('resty.jwt')

local googleOAuthAccessToken = "google-oauth2-access-token"

local OAuth = {
    config = nil,
    scopes = "https://www.googleapis.com/auth/admin.directory.group",
}

local function fetchServiceAccount()
    -- Tries to fetch a service account from the environment and parses it to a table
    -- Returns a table of the service account, or nil if not found
    local svcAcct = os.getenv(self.config.service_account_env_name)
    if svcAcct == nil or svcAcct == '' then
        kong.log.err("No service account found. Make sure to load one in GOOGLE_APPLICATION_CREDENTIALS")
        return nil
    end
    --local svcAcct = '/usr/local/share/lua/5.1/kong/plugins/oidc/serviceaccount.json'
    --local file, err = io.open(svcAcct, "rb")
    --if err then
    --    ngx.log(ngx.DEBUG, "Error opening file: " .. err)
    --    return nil
    --end
    --local svcAcctStr = file:read "*a"
    return JSON:decode(svcAcct)
end

local function generateJWT(scopes, delegatedUser)
    -- Generates a Google OAuth2 compliant JWT from a service account
    -- scopes: space delimited set of scopes for the Google API
    -- delegatedUser: the email address of the user who is delegating access
    -- Returns: a JWT token string or nil
    local svcAcct = fetchServiceAccount()
    if svcAcct == nil then
        ngx.log(ngx.DEBUG, "[googleoauth.lua] No service account found, no JWT generated.")
        return nil
    end
    ngx.log(ngx.DEBUG, "[googleoauth.lua] Fetched service account for Google OAuth: ")
    --pretty.dump(svcAcct)
    local currentUnixTimestamp = os.time(os.date("!*t"))
    local claimSet = {
        iss = svcAcct['client_email'],
        scope = scopes,
        aud = 'https://oauth2.googleapis.com/token',
        exp = currentUnixTimestamp + 3600,
        iat = currentUnixTimestamp,
        sub = delegatedUser,
    }
    local jwtTable = {
        header = {
            typ = 'JWT',
            alg = 'RS256',
        },
        payload = claimSet,
    }
    local key = svcAcct['private_key']
    return jwt:sign(key, jwtTable)
end

local function requestAccessToken(jwtToken)
    -- Makes a REST call to Google's OAuth2 servers to get the access tokens
    -- :param jwtToken: A string representation of a valid base64 encoded JWT
    -- Returns: the access token, and the expiration time expressed as a unix timestamp or (nil, nil) if request unsuccessful
    local reqBody = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" .. jwtToken
    ngx.log(ngx.DEBUG, "[googleoauth.lua] in requestAccessToken with body: " .. reqBody)
    local headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["content-length"] = string.len(reqBody)
    }
    local httpc = http.new()
    local url = "https://oauth2.googleapis.com/token"
    local params = {
        method = "POST",
        body = reqBody,
        headers = headers,
        ssl_verify = false,
        keepalive = true,
    }
    local res, err2 = httpc:request_uri(url, params)
    if err2 or not res then
        ngx.log(ngx.ERR, "[googleoauth.lua] : Error when calling Google OAuth token endpoint: " .. err2)
        return nil, nil
    end
    ngx.log(ngx.DEBUG, "[googleoauth.lua] : Google OAuth token endpoint status: " .. res.status)
    ngx.log(ngx.DEBUG, "[googleoauth.lua] : Google OAuth token endpoint response: " .. res.body)
    if res.status ~= 200 then
        return nil, nil
    end
    local respBody = res.body
    ngx.log(ngx.DEBUG, "[googleoauth.lua] in requestAccessToken, made request. Response (unparsed): " .. respBody)
    local parsedRespBody = JSON:decode(respBody)
    local expiresAt = parsedRespBody['expires_in'] + os.time(os.date("!*t"))
    return parsedRespBody['access_token'], expiresAt
end

local function setAccessTokenInCache(token, expiresAt)
    -- Persists access token and expiration date in db
    -- :param token: A token string representing the access token provided by Google OAuth
    -- :param expiresAt: Datetime of the expiration
    local entity, err = kong.db.google_tokens:upsert({
        { name = googleOAuthAccessToken },
        {
            value = token,
            expires_at = expiresAt
        },
    })
    if err then
        kong.log.err("Could not save GoogleOAuthAccessToken: " .. err)
    end
    kong.log.debug("Saved GoogleOAuthAccessToken")
    return entity
end

local function retrieveAccessTokenFromDB()
    -- Retrieves access token from DB
    -- Returns token, expiration date (or nil, nil) if not present
    local entity, err = kong.db.google_tokens:select({
        name = googleOAuthAccessToken,
    })

    if err then
        kong.log.err("[googleoauth.lua] Could not fetch GoogleOAuthAccessToken from DB: " .. err)
        return nil, nil
    end

    return entity.value, entity.expires_at
end

local function retrieveAccessTokenFromCache()
    -- Retrieves access token from cache (and if not available, retrieve from DB)
    -- Returns: token, expiration date

    -- Check cache (and check DB as backup)
    local cache_key = kong.db.google_tokens:cache_key(googleOAuthAccessToken)
    local entity, err = kong.cache:get(cache_key, nil, retrieveAccessTokenFromDB, cache_key)
    if err then
        kong.log.err("[googleoauth.lua] Could not fetch fetch GoogleOAuthAccessToken from Cache: " .. err)
        return nil, nil
    end

    if not entity then
        kong.log.err("[googleoauth.lua] Cache returned nil for GoogleOAuthAccessToken.")
        return nil, nil
    end

    -- Check if token is stale first before returning
    local currentUnixTimestamp = os.time(os.date("!*t"))
    ngx.log(ngx.DEBUG, "[googleoauth.lua] Access token expires at: ", entity.expires_at)
    -- TODO - The date formats here need some investigation!
    if entity.expires_at <= currentUnixTimestamp then
        kong.log.debug("[googleoauth.lua] Access token has already expired!")
        return nil, nil
    end
    return entity.value, entity.expires_at
end

function OAuth:new(config)
    -- Constructor
    -- :param config: The Kong plugin configuration object
    self.config = config
end

function OAuth:authenticate()
    -- Performs all the operations to get a valid Google OAuth token
    -- Will first check the cache to see if a token exists. If not, a JWT OAuth will be used to get an access token from Google
    -- Returns a token and expiration date if authentication is successful. Otherwise, returns nil, nil

    -- Initialize by checking from cache/db
    local accessToken, accessTokenExpiresAt = retrieveAccessTokenFromCache()

    -- If no access token in cache, go through normal flow
    if accessToken == nil then
        -- Generate JWT
        local jwtToken = generateJWT(self.scopes, self.config.admin_user)
        ngx.log(ngx.DEBUG, "[googleoauth.lua] Called generateJWT, which returned base64 encoded token: " .. jwtToken)
        -- If could not generate, fail gracefully by returning nil, nil
        if jwtToken == nil then
            ngx.log(ngx.DEBUG, "[googleoauth.lua] Could not get a token. Authentication failed." )
            return nil, nil
        end
        -- Otherwise if successful, request access token
        accessToken, accessTokenExpiresAt = requestAccessToken(jwtToken)
        ngx.log(ngx.DEBUG, "[googleoauth.lua] Called requestAccessToken, which gave an access token value of: " .. accessToken)
        -- If access token was present, set in db/cache
        setAccessTokenInCache(accessToken, accessTokenExpiresAt)
    end

    -- Otherwise if access token already present in db (and unexpired), simply return it
    return accessToken, expiresAt
end

return OAuth