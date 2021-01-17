local typedefs = require "kong.db.schema.typedefs"

return {
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
        -- Inserted by the DAO itself
        updated_at = typedefs.auto_timestamp_s,
      },
      {
        -- The user
        google_user = {
          type      = "string",
          required  = true,
          unique    = true,
        },
      },
      {
        -- The corresponding group(s) it belongs to
        google_groups = {
          type      = "array",
          required  = true,
          elements  = {
            type = "string",
          },
        },
      },
    },
  },
  google_tokens = {
    name                  = "google_tokens", -- the actual table in the database
    primary_key           = { "name" },
    cache_key             = { "name" },
    fields = {
      {
        -- Inserted by the DAO itself
        created_at = typedefs.auto_timestamp_s,
      },
      {
        -- Inserted by the DAO itself
        updated_at = typedefs.auto_timestamp_s,
      },
      {
        -- The name of the token
        name = {
          type      = "string",
          required  = true,
          unique    = true,
        },
      },
      {
        -- The corresponding value of the token
        value = {
          type      = "string",
          required  = true,
        },
      },
      {
        -- The expiration time, expressed as a unix timestamp
        expires_at = {
          type      = "number",
          required  = true,
        },
      },
    },
  },
}
