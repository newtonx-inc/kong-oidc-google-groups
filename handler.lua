-- Extending the Base Plugin handler is optional, as there is no real
-- concept of interface in Lua, but the Base Plugin handler's methods
-- can be called from your child implementation and will print logs
-- in your `error.log` file (where all logs are printed).
local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.kong-google-auth.access"

local GoogleAuthHandler = BasePlugin:extend()

GoogleAuthHandler.VERSION = "0.0.0"
-- Set priority to run after OAuth and OIDC
GoogleAuthHandler.PRIORITY = 1010


-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instantiate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function GoogleAuthHandler:new()
    GoogleAuthHandler.super.new(self, "kong-google-auth")
end

function GoogleAuthHandler:init_worker()
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.init_worker(self)

    -- Implement any custom logic here
end

function GoogleAuthHandler:preread(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.preread(self)

    -- Implement any custom logic here
end

function GoogleAuthHandler:certificate(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.certificate(self)

    -- Implement any custom logic here
end

function GoogleAuthHandler:rewrite(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.rewrite(self)

    -- Implement any custom logic here
end

function GoogleAuthHandler:access(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.access(self)
    -- Implement any custom logic here
    access.execute(config)
end

function GoogleAuthHandler:header_filter(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.header_filter(self)

    -- Implement any custom logic here
end

function GoogleAuthHandler:body_filter(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.body_filter(self)

    -- Implement any custom logic here
end

function GoogleAuthHandler:log(config)
    -- Eventually, execute the parent implementation
    -- (will log that your plugin is entering this context)
    GoogleAuthHandler.super.log(self)

    -- Implement any custom logic here
end

-- This module needs to return the created table, so that Kong
-- can execute those functions.
return GoogleAuthHandler