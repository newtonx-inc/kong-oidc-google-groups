local JSON = require("JSON")
local http = require("resty.http")
local googleoauth = require('kong.plugins.oidc-google-groups.googleoauth')


local DirectoryApi = {
    user = nil,
    config = nil,
}

local function callDirectoryApi(user, group, config)
    -- Calls Google Directory API with provided user and group and determines whether the user belongs to the group
    -- :param user: The user to check (should be a plain email)
    -- :param group: The group to check if the user has membership to
    -- :param config: The plugin configuration object
    -- Returns: bool

    -- Authenticate
    local authSvc = googleoauth:new(config)
    local accessToken, _ = authSvc:authenticate()

    if not accessToken then
        kong.log.err("[directoryapi.lua] : Could not fetch Google access token! Aborting...")
        return false
    end

    -- Calls the provided directory API
    local url = "https://admin.googleapis.com/admin/directory/v1/groups/" .. group .. "/hasMember/" .. user
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. accessToken,
    }
    local httpc = http.new()
    local params = {
        method = "GET",
        headers = headers,
        ssl_verify = false,
        keepalive = true,
    }
    local res, err = httpc:request_uri(url, params)
    if err or not res then
        kong.log.err("[directoryapi.lua] : Error when calling Google Directory API endpoint: " .. err)
        return false
    end
    kong.log.debug("[directoryapi.lua] : Google Directory endpoint status: " .. res.status)
    kong.log.debug("[directoryapi.lua] : Google Directory endpoint response: " .. res.body)
    if res.status ~= 200 then
        return false
    end
    local respBody = res.body
    kong.log.debug("[directoryapi.lua] Response from Google Directory API (unparsed): " .. respBody)
    local parsedRespBody = JSON:decode(respBody)
    return parsedRespBody['isMember']
end

function DirectoryApi:new(user, config)
    -- Constructor
    -- :param user: The user to check (should be a plain email)
    -- :param config: The plugin configuration object
    self.user = user
    self.config = config
    return DirectoryApi
end

function DirectoryApi:checkMembership()
    -- Checks to see if a user belongs to any of the provided groups
    -- Returns true if is a member, matching group

    -- Iterate through groups
    local isAMember = false
    local memberOfGroup = nil
    for _, group in ipairs(self.config.allowed_groups) do
        kong.log.debug("[directoryapi.lua] : Calling Directory API for group: " .. group)
        isAMember = callDirectoryApi(self.user, group, self.config)
        -- If a membership is identified, break the loop and return true
        if isAMember then
            memberOfGroup = group
            break
        end
    end
    kong.log.debug("[directoryapi.lua] : At least one membership to an allowed group found? : " .. tostring(isAMember))
    return isAMember, memberOfGroup
end

return DirectoryApi