-- Extending the Base Plugin handler is optional, as there is no real
-- concept of interface in Lua, but the Base Plugin handler's methods
-- can be called from your child implementation and will print logs
-- in your `error.log` file (where all logs are printed).
local BasePlugin = require "kong.plugins.base_plugin"
local Access = require('kong.plugins.oidc-google-groups.access')

local GoogleAuthHandler = BasePlugin:extend()

GoogleAuthHandler.VERSION = "0.0.0"
GoogleAuthHandler.PRIORITY = 990


-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instantiate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function GoogleAuthHandler:new()
    GoogleAuthHandler.super.new(self, "oidc-google-groups")
end

function GoogleAuthHandler:init_worker()
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.init_worker(self)

    -- Implement any custom logic here
end

function GoogleAuthHandler:access(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.access(self)
    -- Implement any custom logic here
    Access:start(config)
end


-- This module needs to return the created table, so that Kong
-- can execute those functions.
return GoogleAuthHandler