local typedefs = require "kong.db.schema.typedefs"

return {
  -- this plugin only results in one custom DAO, named `google_group_memberships`:
  google_group_memberships = {
    name                  = "google_group_memberships", -- the actual table in the database
    primary_key           = { "google_user" },
    cache_key             = { "google_user" },
    fields = {
      {
        -- Inserted by the DAO itself
        created_at = typedefs.auto_timestamp_s,
      },
      {
        -- The user
        google_user = {
          type      = "string",
          required  = true,
          unique    = false,
        },
      },
      {
        -- The corresponding group(s) it belongs to
        google_groups = {
          type      = "array",
          required  = true,
          unique    = false,
        },
      },
    },
  },
}
