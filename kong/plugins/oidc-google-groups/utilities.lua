-- Utilities
local Utilities = {}

-- HTTP
function Utilities:exitWithForbidden(msg)
    -- Exits the current request and responds with a 403: Forbidden
    -- :param msg: Custom message. If not provided, will use the default below.
    -- Returns: nothing
    kong.response.exit(403, msg or "Access forbidden. You do not have sufficient Google Groups access to this resource.")
end

return Utilities