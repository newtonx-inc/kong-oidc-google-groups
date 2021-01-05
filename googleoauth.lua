local json = require('json')
local base64 = require('base64')
local http = require('socket.http')
local ltn12 = require('ltn12')

local googleOAuthAccessToken = "google-oauth2-access-token"

local OAuth = {}

local function generateJWT(scopes, delegatedUser)
    -- Generates a Google OAuth2 compliant JWT from a service account
    -- scopes: space delimited set of scopes for the Google API
    -- delegatedUser: the email address of the user who is delegating access
    -- Returns: a JWT token string
    local svcAcct = fetchServiceAccount()
    local currentUnixTimestamp = os.time(os.date("!*t"))
    local claimSet = {
        iss = svcAcct['client_email'],
        scope = scopes,
        aud = 'https://oauth2.googleapis.com/token',
        exp = currentUnixTimestamp + 3000,
        iat = currentUnixTimestamp,
        sub = delegatedUser,
    }
    jwtTable = {
        header = {
            typ = 'JWT',
            alg = 'SHA256',
        },
        payload = claimSet,
    }
    key = svcAcct['private_key']
    local jwtToken = jwt:sign(key, jwtTable)
    return base64.encode(jwtToken)
end

local function fetchServiceAccount()
    -- Tries to fetch a service account from the environment and parses it to a table
    local svcAcct = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if svcAcct == nil or svcAcct == '' then
        kong.log.err("No service account found. Make sure to load one in GOOGLE_APPLICATION_CREDENTIALS")
        return
    end
    return json.decode(svcAcct)
end

local function requestAccessToken(jwtToken)
    -- Makes a REST call to Google's OAuth2 servers to get the access tokens
    -- jwtToken: A string representation of a valid base64 encoded JWT
    -- Returns: the access token, and the expiration time expressed as a unix timestamp
    local reqBody = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" .. jwtToken
    local headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["content-length"] = string.len(reqBody)
    }
    local respBody = {}
    http.request{
        url = "https://oauth2.googleapis.com/token",
        method = "POST",
        headers = headers,
        source = ltn12.source.string(reqBody),
        sink = ltn12.sink.table(respBody)
    }
    local parsedRespBody = json.decode(respBody)
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
    local token = generateJWT()
    accessToken, err = requestAccessToken(token)
    if err then
        kong.log.err("Could not get access token from Google: " .. err)
        return nil, err
    end
    return accessToken, nil
end

return OAuth