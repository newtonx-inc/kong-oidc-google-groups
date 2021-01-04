local typedefs = require "kong.db.schema.typedefs"


return {
  name = "kong-google-auth",
  fields = {
    {
      -- whether plugin is enabled
      enabled = {
          type = "boolean",
          default = true,
      },
    },
    {
      -- What Google groups to check for membership in
      allowed_groups = {
          type = "array",
          required = true,
          elements = typedefs.name,
      },
    },
    {
      -- What paths to apply this to (defaults to "/")
      paths = {
          type = "array",
          required = false,
          elements = typedefs.path,
          default = {
              "/",
          },
      },
    },
    {
      -- How long (in seconds) to cache group membership info in the database
      db_cache_period_secs = {
          type = "number",
          required = false,
          default = 300,
      },
    },
    {
      config = {
        type = "record",
        fields = {
          -- Describe your plugin's configuration's schema here.
        },
      },
    },
  },
}