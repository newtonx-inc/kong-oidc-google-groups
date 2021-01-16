local GoogleDirectoryApi = require('directoryapi')

-- Memberships
local Memberships = {
    config = nil,
}

local function fetchMembershipFromDB(user)
    -- Checks the DB for membership to at least one of the allowed groups
    -- :param user: The user to check for membership
    -- Returns: The google_group_memberships entity, error (if applicable)
    local entity, err = kong.db.google_group_memberships:select({
        google_user = user,
    })

    if err then
        kong.log.err("[memberships.lua] Could not fetch membership from DB: " .. err)
        return nil, err
    end

    return entity, nil
end

local function compareMemberships(groups, allowedGroups)
    -- Compares groups found with the allowed groups, and determines whether there is at least one match
    -- Returns: bool
    for _, g in ipairs(groups) do
        for _, ag in ipairs(allowedGroups) do
            if g == ag then
                return true
            end
        end
    end
    return false
end

local function checkMembershipsInCache(user, allowedGroups, ttl)
    -- Checks the cache (and then the DB if needed) for membership to at least one of the allowed groups
    -- :param user: The user to check for membership
    -- :param allowedGroups: The groups to check for membership of
    -- :param ttl: time in seconds since created_at that the record should be considered valid
    -- Returns: bool

    -- Check cache (and check DB as backup)
    local cache_key = kong.db.google_group_memberships:cache_key(user)
    local entity, err = kong.cache:get(cache_key, nil, fetchMembershipFromDB, cache_key)
    if err then
        kong.log.err("[memberships.lua] Could not fetch fetch membership from Cache: " .. err)
        return false
    end

    if not entity then
        kong.log.err("[memberships.lua] Cache returned nil for membership.")
        return false
    end

    -- Check if token is stale first before returning
    local currentUnixTimestamp = os.time(os.date("!*t"))
    ngx.log(ngx.DEBUG, "[memberships.lua] Membership data expires at: ", entity.expires_at)
    -- TODO - The date formats here need some investigation!
    if entity.created_at + ttl <= currentUnixTimestamp then
        kong.log.debug("[memberships.lua] Membership data has already expired!")
        return false
    end
    -- See if current memberships intersect w/ allowedGroups
    -- TODO
    -- Split google_groups from group:expiration into tuples.
    -- Iterate through each one, seeing if there is a match by group name
    -- If there is a match, check that entry hasn't expired.
    -- If no match, log and return error
    return compareMemberships(entity.google_groups, allowedGroups)
end

local function saveMembershipToDB(user, group)
    -- Saves membership info to the DB for a certain user
    -- :param user: The user to save membership info for
    -- :param group: The group to save
    -- Returns nothing

    -- TODO
    -- Fetch membership entity for a user
    -- If no membership found, create a new record
    -- If a membership record is found
    -- Examine what groups the user belongs to
    -- If no matching groups present, add group:expiration string
    -- If matching group present, replace that value with group:expiration string (with new date) and continue
    -- Update the record

    -- LOG any errors
end

function Memberships:new(config, user)
    -- Constructor
    -- :param config: The plugin configuration object
    -- :param user: The user to check for membership
    self.config = config
    self.user = user
end

function Memberships:checkMemberships()
    -- Checks for membership in any of the allowed groups
    -- :param user: The user to check for membership
    -- Returns: bool

    -- First with the database (actually with the cache)
    local res = checkMembershipsInCache(self.user, self.config.allowedGroups, self.config.ttl)

    -- Then check Directory API if needed
    if res == false then
        local memberOfGroup = nil
        local directorySvc = GoogleDirectoryApi.new(self.user, self.config)
        res, memberOfGroup = directorySvc:checkMembership()

        -- TODO if group is allowed, add it to the db for that user
        if res == true then
            saveMembershipToDB(self.user, memberOfGroup)
        end
    end

    return res
end

return Memberships