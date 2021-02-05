local typedefs = require("kong.db.schema.typedefs")

return {
  name = "kong-oidc-google-groups",
  fields = {
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
              client_id = {
                  type = "string",
                  required = true,
              },
            },
            {
              -- What Google groups to check for membership in
              client_secret = {
                  type = "string",
                  required = true,
              },
            },
            {
              -- What Google groups to check for membership in
              allowed_groups = {
                  type = "array",
                  required = false,
                  elements = {
                      type = "string"
                  },
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
              methods = {
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
                  required = true,
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
              -- Where to redirect from OIDC
              redirect_uri_path = {
                  type = "string",
                  required = false,
              },
            },
            {
              -- Absolute path used to logout from the OIDC RP
              logout_path = {
                  type = "string",
                  required = false,
                  default = '/logout',
              },
            },
            {
              -- Where to redirect to after logout
              redirect_after_logout_uri = {
                  type = "string",
                  required = false,
                  default = '/',
              },
            },
            {
              -- Where to redirect to on OIDC failure
              recovery_page_path = {
                  type = "string",
                  required = false,
                  default = '/',
              },
            },
            {
              -- The id of an anonymous consumer
              anonymous = {
                  type = "string",
                  required = false,
              },
            },
        },
      },
    },
  },
}