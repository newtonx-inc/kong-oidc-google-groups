local Memberships = require('kong.plugins.oidc-google-groups.memberships')
local Utilities = require('kong.plugins.oidc-google-groups.utilities')
local Filters = require('kong.plugins.oidc-google-groups.filters')

local Access = {
    oidcConfig = nil
}

function Access:callRestyOIDC()
    -- Calls resty-oidc with options
    -- Returns: response or nil
    kong.log.debug("OidcHandler calling authenticate, requested path: " .. ngx.var.request_uri)

    -- Unauth action for resty oidc (for anonymous flow)
    local unauth_action = nil
    if self.oidcConfig.anonymous ~= "" and self.oidcConfig.anonymous ~= nil then
        unauth_action = "pass"
    end

    -- Run resty oidc
    local res, err = require("resty.openidc").authenticate(self.oidcConfig, nil, unauth_action)
    if err then
        if oidcConfig.recovery_page_path then
            kong.log.debug("Entering recovery page: " .. self.oidcConfig.recovery_page_path)
            ngx.redirect(self.oidcConfig.recovery_page_path)
        end
        Utilities:exit(500, err, ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    return res
end

function Access:handleOIDC()
    -- Handles the main OIDC flow
    -- Returns: user or nil
    local response = self:callRestyOIDC()
    if response then
        if (response.user) then
            Utilities:injectUser(response.user)
        end
        if (response.access_token) then
            Utilities:injectAccessToken(response.access_token)
        end
        if (response.id_token) then
            Utilities:injectIDToken(response.id_token)
        end
        return response.user
    end

    -- Set anonymous headers if necessary
    if self.oidcConfig.anonymous ~= "" and self.oidcConfig.anonymous ~= nil then
        Utilities:injectAnonymousConsumer(self.oidcConfig.anonymous)
    end
end

function Access:start(config)
    -- The main function for this plugin
    -- Returns nothing. If successful, the request passes through to the upstream. If unsuccessful, a 403: Forbidden response is generated.

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

    -- OIDC main flow
    -- Load config object to prepare for sending resty-oidc
    self.oidcConfig = Utilities:getOptionsForRestyOIDC(config)
    local user = self:handleOIDC()
    kong.log.debug("OidcHandler done")

    -- TODO account for 429s or 4XXs from Google. Should have a way of alerting on this (Sentry?)

    -- Google Groups flow begin
    if user then
        local userEmail = user['email']
        -- Check if user belongs to one of the allowedGroups. If user doesn't exist, exit with 403
        local m = Memberships:new(config, userEmail)
        local res = m:checkMemberships()
        if not res then
            Utilities:exitWithForbidden()
        end
        kong.log.debug("[access.lua] : Authorized via Google Groups. Continuing to upstream...")
        return
    end
    Utilities:exit(500, 'Could not get user information from Google OIDC to authenticate')
end

return Access