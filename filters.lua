local Filters = {
    config = nil
}

function Filters:new(config)
    -- Constructor
    self.config = config
end

function Filters:checkMethod()
    -- Checks whether the current method matches any of the methods specified in the plugin configuration
    -- Returns: bool
    local currentMethod = kong.request.get_method()
    for _, method in ipairs(self.config.methods) do
        if currentMethod == method then
            return true
        end
    end
end

function Filters:checkPath()
    -- Checks whether the current path is a subpath of any one of the paths specified in the plugin configuration
    -- Returns: bool
    local currentPath = kong.request.get_path()
    for _, path in ipairs(self.config.paths) do
        local match = string.find(currentPath, "^" .. path)
        if match then
            return true
        end
    end
    return false
end

function Filters:checkIfAllowedGroupsPresent()
    -- Checks if plugin configuration specifies at least one allowed group
    -- Returns: bool
    return table.getn(self.config.allowed_groups) > 0
end

return Filters

