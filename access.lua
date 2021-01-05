local base64 = require('base64')
local json = require('json')
local googleapi = require('kong.plugins.kong-google-auth.googleapi')

local Access = {}

function Access.start(config)
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

-- Persistence
local function setMembership(user, groups)
    local entity, err = kong.db.google_group_memberships:upsert({
        { google_user = user },
        { google_groups = groups }
    })
    if err then
        kong.log.err("Could not upsert user. Err: " .. err)
        return
    end
    return entity
end

local function getMemberships(user)
    local entity, err = kong.db.google_group_memberships:select({
        google_user = user
    })
    if err then
        kong.log.err("Could not get user. Err: " .. err)
        return {}
    end
    return entity.google_groups, entity.created_at
end

-- Memberships
local function checkMemberships()
    -- Checks for membership in any of the allowed groups
    -- First with the database (actually with the cache)
    if checkMembershipsInDB() then
        return
    end
    -- Then check with APIs
    -- Start with OIDC
    if googleapi.checkServiceAccountMembershipAPI() then
        return
    end
    -- Then OAuth2
    if googleapi.checkServiceAccountMembershipAPI() then
        return
    end

    -- If all else fails, exit with a 403
    exitWithForbidden()
end

local function checkMembershipsInDB(user)
    -- Checks the DB for recent records. If the records are stale, false will be returned. Uses cache as well
    groups, updated_at = getMemberships(user)
    -- TODO check if stale using updated_at
    -- TODO function needs to accept two arrays
    return groupIsAMemberOfGroups(groups, group)
end

local function groupIsAMemberOfGroups(groups, group)
    -- Checks to see if the provided group is part of the allowed_groups
    for _, value in ipairs(groups) do
        if value == group then
            return true
        end
    end
    return false
end


-- HTTP
local function getValueFromHeader(headerKey, requiresBase64Decode, decodedObjectKey)
    -- Gets header, decodes if necessary, parses if necessary
    local headerValue = kong.request.get_header(headerKey)

    if requiresBase64Decode then
        local decoded = base64.decode(headerValue)
        if decodedObjectKey then
            -- Parse JSON and return value corresponding to the key of the JSON object
            local t = json.decode(decoded)
            return t[decodedObjectKey]
        else
            return decoded
        end
    else
        return headerValue
    end
end

local function exitWithForbidden()
    kong.response.exit(403, "Access forbidden. You do not have sufficient Google Groups access to this resource.")
end

return Access