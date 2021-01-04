local M = {}

function M.access(config)
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

end

local function getMemberships(user)

end

return M