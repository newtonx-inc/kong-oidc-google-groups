local typedefs = require("kong.db.schema.typedefs")

return {
  name = "kong-google-auth",
  fields = {
    {
      consumer = typedefs.no_consumer
    },
    {
      protocols = typedefs.protocols_http
    },
    {
      config = {
        type = "record",
        fields = {
            -- Describe your plugin's configuration's schema here.
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
              -- What methods to apply this to (defaults to "all")
              paths = {
                  type = "array",
                  required = false,
                  elements = typedefs.http_method,
                  default = {
                      "GET",
                      "POST",
                      "PUT",
                      "PATCH",
                      "DELETE",
                      "OPTIONS",
                  },
              },
            },
            {
              -- Service account to use for Google Directory API (full JSON string)
              service_account = {
                  type = "string",
                  required = false,
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
        },
      },
    },
  },
}