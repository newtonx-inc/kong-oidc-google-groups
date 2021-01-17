local base64 = require('base64')
local JSON = require("JSON")
local Memberships = require('memberships')
local Utilities = require('utilities')
local Filters = require('filters')

local Access = {}

function Access:start(config)
    -- The main function for this plugin
    -- Returns nothing. If successful, the request passes through to the upstream. If unsuccessful, a 403: Forbidden response is generated.

    -- TODO add in kong-oidc (simplified - don't need all the extra params) - later
    -- TODO account for 429s or 4XXs from Google. Should have a way of alerting on this (Sentry?)


    kong.log.debug("[access.lua] : Starting Kong Google Groups Authorization.")

    -- Check various conditions
    local filters = Filters:new(config)
    -- Check if this plugin config specifies any allowed groups
    if not filters:checkIfAllowedGroupsPresent() then
        kong.log.debug("[access.lua] : No allowed groups found. Skipping Google Groups authorization.")
        return
    end

    -- Checks if this plugin should be applied to any specific paths
    if not filters:checkPath() then
        kong.log.debug("[access.lua] : No matching paths found. Skipping Google Groups authorization.")
        return
    end

    -- Checks if this plugin should be applied to any specific methods
    if not filters:checkMethod() then
        kong.log.debug("[access.lua] : No matching methods found. Skipping Google Groups authorization.")
        return
    end


    -- TEMP Try second the HTTP_X_USERINFO header from OIDC
    local userHeaderValue = kong.request.get_header('HTTP_X_USERINFO')
    local rawDecodedValue = base64.decode(userHeaderValue)
    local parsedUserInfo = JSON:decode(rawDecodedValue)
    local userEmail = parsedUserInfo['email']
    -- Check if user belongs to one of the allowedGroups. If user doesn't exist, exit with 403
    local m = Memberships:new(config, userEmail)
    local res = m:checkMemberships()
    if not res then
        Utilities:exitWithForbidden()
    end
end

return Access