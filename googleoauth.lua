local base64 = require('base64')
local http = require("resty.http")
local JSON = require("JSON")
local pretty = require('pl.pretty')
local jwt = require('resty.jwt')

local googleOAuthAccessToken = "google-oauth2-access-token"

local OAuth = {}

local function fetchServiceAccount()
    -- Tries to fetch a service account from the environment and parses it to a table
    --local svcAcct = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    --if svcAcct == nil or svcAcct == '' then
    --    kong.log.err("No service account found. Make sure to load one in GOOGLE_APPLICATION_CREDENTIALS")
    --    return
    --end
    -- TODO change this to an actual config value
    local svcAcct = '/usr/local/share/lua/5.1/kong/plugins/oidc/serviceaccount.json'
    local file, err = io.open(svcAcct, "rb")
    if err then
        ngx.log(ngx.DEBUG, "Error opening file: " .. err)
        return nil
    end
    local svcAcctStr = file:read "*a"
    return JSON:decode(svcAcctStr)
end

local function generateJWT(scopes, delegatedUser)
    -- Generates a Google OAuth2 compliant JWT from a service account
    -- scopes: space delimited set of scopes for the Google API
    -- delegatedUser: the email address of the user who is delegating access TODO - This should probably be a config property
    -- Returns: a JWT token string
    local svcAcct = fetchServiceAccount()
    ngx.log(ngx.DEBUG, "[googleoauth.lua] Fetched service account for Google OAuth: ")
    pretty.dump(svcAcct)
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

    --ngx.log(ngx.DEBUG, "[googleoauth.lua] Created JWT for Google OAuth (not yet base64 encoded): " .. jwtToken)
    --return base64.encode(jwtToken)
end

local function requestAccessToken(jwtToken)
    -- Makes a REST call to Google's OAuth2 servers to get the access tokens
    -- jwtToken: A string representation of a valid base64 encoded JWT
    -- Returns: the access token, and the expiration time expressed as a unix timestamp
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

local function retrieveAccessTokenFromCache()
    local entity, err = kong.db.google_tokens:select({
        name = googleOAuthAccessToken,
    })

    if err then
        kong.log.err("Could not fetch GoogleOAuthAccessToken: " .. err)
        return nil
    end

    -- TODO: Check if token is stale first before returning

    return entity
end

function OAuth.authenticate()
    -- TODO: First check DB to see if there is an up to date token and return it. Otherwise, perform the OAuth2 flow
    local scopes = "https://www.googleapis.com/auth/admin.directory.group"
    local delegatedUser = "kristoph.matthews@newtonx.com"
    local token = generateJWT(scopes, delegatedUser)
    ngx.log(ngx.DEBUG, "[googleoauth.lua] Called generateJWT, which returned base64 encoded token: " .. token)
    local accessToken, expiresAt = requestAccessToken(token)
    ngx.log(ngx.DEBUG, "[googleoauth.lua] Called requestAccessToken, which gave an access token value of: " .. accessToken)
    --if err then
    --    kong.log.err("Could not get access token from Google: " .. err)
    --    return nil, err
    --end
    return accessToken, expiresAt
end

return OAuth