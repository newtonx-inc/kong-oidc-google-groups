local http = require('socket.http')
local json = require('json')
local googleoauth = require('kong.plugins.kong-google-auth.googleoauth')

local scopes = {
    'https://www.googleapis.com/auth/admin.directory.group.readonly'
}

local GoogleDirectoryApi = {
    service = nil,
    accessToken = nil
}

function GoogleDirectoryApi:new()
    -- TODO create service and authenticate
    self.accessToken = googleoauth.authenticate()

end

function GoogleDirectoryApi.checkServiceAccountMembershipAPI(user)
    -- Checks whether a service account belongs to a Google Group, using the Google Cloud IAM REST API
    -- TODO
end

function GoogleDirectoryApi.checkHumanAccountMembershipAPI(user)
    -- Checks whether a user belongs to a Google Group, using the Google Directory REST API
    url = "https://admin.googleapis.com/admin/directory/v1/groups/" .. groupKey .. "/hasMember/" .. memberKey
    -- TODO: Add in bearer token
    resp, err = http.request(url)
    if err then
        kong.log.err("Could not make GoogleDirectoryAPI request: " .. err)
    end
    local decodedJson = json.decode(resp)
    return decodedJson['isMember']
end

return GoogleDirectoryApi