local base64 = require('base64')
local json = require('json')
local googleapi = require('kong.plugins.kong-google-auth.googleapi')

local Access = {}

function Access.start(config)
    -- TODO add in kong-oidc (simplified - don't need all the extra params)
    -- TODO intercept user info and check for group membership
    -- TODO account for 429s or 4XXs from Google. Should have a way of alerting on this (Sentry?)
    -- TODO - need to account for when allowedGroups is empty
    -- * Identify user from Header * --
    -- Try first the Kong OAuth2 header

    -- Try second the HTTP_X_USERINFO header from OIDC


    -- * Check if user belongs to one of the allowedGroups * --
    -- If user doesn't exist, exit with 403
    -- Check cached values first
    -- If values expired, check using the Google APIs, below.

    -- Check using Google APIs
    -- Store result in DB

    -- If user is part of an allowed group, proceed as normal
    -- If user does not belong to one of the valid groups, exit with 403
end

return Access