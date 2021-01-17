# Kong Google OIDC Google Groups
This library is a Kong Gateway Plugin built in Lua, which authenticates your Kong upstreams using Google OIDC (Open ID Connect),
and authorizes them based on what groups they belong to in your Google Workspace.

# Installation

```bash
luarocks install kong-oidc-google-groups
```

Make sure you set your `KONG_PLUGINS` environment variable such that it reflects this plugin:

```bash
export KONG_PLUGINS=bundled,oidc-google-groups
```

## Notes
Depending on your setup, you may want to make sure your host that runs Kong also has the following 
Linux packages (as the luarocks installation of certain dependencies requires them):

- curl 
- gcc 
- musl-dev

Often a clean way of doing this is creating your own Docker image that uses Kong as a base image, but installs these 
packages in the build steps. 

# How it works
TODO: <Lucid Chart Diagram Overview>

# Example
Show upstream request

# Requirements
* Kong DB (does not work in db-less mode)
* Service account, loaded into env var: GOOGLE_APPLICATION_CREDENTIALS

# Dependencies

## Infrastructure dependencies
- Google Workspace (formally "Gsuite") organization
- A Google Cloud Platform service account with domain-wide delegation turned, and authorized in your Google 
  Worskpace with proper scopes. [See instructions]()
- Enable the Google Directory API in Google Cloud Platform
- Set up a GCP OAuth client (and thus a Client ID and Client Secret) and consent screen. [See instructions]()
- Create one or more groups and add users to them in Google Workspace. These will be your "allowed groups" for Google 
  Groups based authorization after OIDC authentication is done.
- Kong (This plugin tested in production w/ version 2.2)
  
## Plugin dependencies
The following are some of the main software dependencies for this plugin. The Rockspec will automatically load these.
- [lua-resty-openidc](https://github.com/zmartzone/lua-resty-openidc) 
- [lua-resty-jwt](https://github.com/SkyLothar/lua-resty-jwt)


# Configuration

| Parameter            | Default | Required? | Description                                                                                                                                                                                  |
|----------------------|---------|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| client_id            |         | Yes       | The OAuth Client ID of your client in GCP used for performing OIDC auth                                                                                                                      |
| client_secret        |         | Yes       | The OAuth Client Secret of your client in GCP used for performing OIDC auth                                                                                                                  |
| logout_path          |         | No        | Absolute path used to logout from the OIDC Relying Party (RP)                                                                                                                 |
| service_account      |         | Yes       | The json string representation of your GCP service account                                                                                                                                   |
| admin_user           |         | Yes       | The email address of a user in your Google Workspace who has admin privileges. This is used to look up info on the Google Directory API                                                      |
| allowed_groups       | {}      | No        | A list of email addresses of groups in your org that you want to authorize. Any user belonging to one of these groups will be let through. If left blank, all users will be allowed through. |
| paths                | {"/"}   | No        | A list of paths to apply this plugin to                                                                                                                                                      |
| db_cache_period_secs | 300     | No        | The time period in seconds for which to cache Google Group membership information. This helps reduce latency and API calls to the Google Directory API                                       |

# Development
## Publishing to LuaRocks
TODO



