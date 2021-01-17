local typedefs = require "kong.db.schema.typedefs"
-- TODO - consider putting the svc account in directly

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
          required = false,
          elements = typedefs.name,
          default = {},
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
      -- Environment variable name that stores service account to use for Google Directory API
      service_account_env_name = {
          type = "string",
          required = false,
          default = "KONG_GOOGLE_APPLICATION_CREDENTIALS",
      },
    },
    {
      -- Name of admin user for Google Directory API
      admin_user = {
          type = "string",
          required = true,
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