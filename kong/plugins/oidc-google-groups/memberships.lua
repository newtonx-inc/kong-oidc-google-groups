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

local function fetchMembershipFromCache(user)
    -- Checks the cache (and then the DB if needed) for membership to at least one of the allowed groups
    -- :param user: The user to check for membership
    -- Returns: The google_group_memberships entity, error (if applicable)

    -- Check cache (and check DB as backup)
    local cache_key = kong.db.google_group_memberships:cache_key(user)
    local entity, err = kong.cache:get(cache_key, nil, fetchMembershipFromDB, cache_key)
    if not entity then
        kong.log.err("[memberships.lua] Could not fetch fetch membership from Cache: " .. err)
        return nil, err
    end

    return entity, nil
end

local function isRecentMemberOfAllowedGroups(membership, allowedGroups, ttl)
    -- Checks all Google groups records and determines whether any of the groups overlap with the permitted groups and the data is up to date
    -- :param allowedGroups: A list (table) of allowed groups to compare against
    -- :param ttl: The time in seconds that the record should be valid for
    -- Returns: bool


    -- Check if token is stale first before returning
    -- See if current memberships intersect w/ allowedGroups
    -- Iterate through all Google groups found in the membership record, then compare against the allowed groups to see if there is a match
    for _, g in ipairs(membership.google_groups) do
        for _, ag in ipairs(allowedGroups) do
            local splittedGroupStr = g.split(':')
            local groupName = splittedGroupStr[0]
            -- If there is a matching group, check to make sure the record isn't stale
            ngx.log(ngx.DEBUG, "[memberships.lua] Comparing membership group: " .. groupName .. "with: " .. ag)
            if groupName == ag then
                local groupDate = splittedGroupStr[1]
                local currentUnixTimestamp = os.time(os.date("!*t"))
                if groupDate <= currentUnixTimestamp - ttl then
                    return true
                end
            end
        end
    end
    return false
end

local function saveMembershipToDB(user, group)
    -- Saves membership info to the DB for a certain user
    -- :param user: The user to save membership info for
    -- :param group: The group to save
    -- Returns nothing

    -- Init
    local currentUnixTimestamp = os.time(os.date("!*t"))

    -- Fetch membership entity for a user
    local membership, _ = fetchMembershipFromDB(user)
    -- If no membership found, create a new record
    if not membership then
        local groupStr = group .. ":" .. currentUnixTimestamp
        local entity, err = kong.db.google_group_memberships:insert({
            google_user = user,
            google_groups = { groupStr }
        })
        if not entity then
          kong.log.err("[memberships.lua] Error when inserting membership: " .. err)
          return
        end
    end
    -- If a membership record is found
    -- Examine what groups the user belongs to
    local groupMemberships = membership.google_groups
    for i, g in ipairs(groupMemberships) do
        local groupName = g.split(':')[0]
        if groupName == group then
            -- If matching group present, replace that value with group:expiration string (with new date) and continue
            groupMemberships[i] = group .. ":" .. currentUnixTimestamp
        else
            -- If no matching groups present, append group:expiration string
            table.insert(groupMemberships, group .. ":" .. currentUnixTimestamp)
        end
    end
    -- Update the record
    local entity, err = kong.db.google_group_memberships:update({
        { google_user = user },
        { google_groups = groupMemberships }
    })

    -- LOG any errors
    if not entity then
      kong.log.err("[memberships.lua] : Error when updating membership: " .. err)
    end
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
    local membership, _ = fetchMembershipFromCache(self.user)
    if membership then
        return isRecentMemberOfAllowedGroups(membership, self.confg.allowedGroups, self.config.db_cache_period_secs)
    end

    -- Then check Directory API if needed
    local directorySvc = GoogleDirectoryApi.new(self.user, self.config)
    local isAMember, memberOfGroup = directorySvc:checkMembership()

    -- If group is allowed, add it to the db for that user
    if isAMember then
        saveMembershipToDB(self.user, memberOfGroup)
    end

    return isAMember
end

return Memberships