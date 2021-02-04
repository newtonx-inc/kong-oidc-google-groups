local JSON = require("JSON")
local constants = require("kong.constants")

-- Utilities
local Utilities = {}

-- HTTP
function Utilities:exitWithForbidden(msg)
    -- Exits the current request and responds with a 403: Forbidden
    -- :param msg: Custom message. If not provided, will use the default below.
    -- Returns: nothing
    kong.response.exit(403, msg or "Access forbidden. You do not have sufficient Google Groups access to this resource.")
end

-- Kong-OIDC
local function parseFilters(csvFilters)
  local filters = {}
  if (not (csvFilters == nil)) then
    for pattern in string.gmatch(csvFilters, "[^,]+") do
      table.insert(filters, pattern)
    end
  end
  return filters
end

function Utilities:getRedirectUriPath()
  local function dropQuery()
    local uri = ngx.var.request_uri
    local x = uri:find("?")
    if x then
      return uri:sub(1, x - 1)
    else
      return uri
    end
  end

  local function tackleSlash(path)
    local args = ngx.req.get_uri_args()
    if args and args.code then
      return path
    elseif path == "/" then
      return "/cb"
    elseif path:sub(-1) == "/" then
      return path:sub(1, -2)
    else
      return path .. "/"
    end
  end

  return tackleSlash(dropQuery())
end

function Utilities:getOptionsForRestyOIDC(config)
  -- Gets options from configuration, to send to resty-openidc
  return {
    client_id = config.client_id,
    client_secret = config.client_secret,
    discovery = 'https://accounts.google.com/.well-known/openid-configuration',
    introspection_endpoint = false,
    bearer_only = 'no',
    realm = 'kong',
    redirect_uri_path = config.redirect_uri_path or Utilities:getRedirectUriPath(),
    scope = 'openid profile email',
    response_type = 'code',
    ssl_verify = 'no',
    token_endpoint_auth_method = 'client_secret_post',
    filters = parseFilters(nil),
    logout_path = config.logout_path,
    redirect_after_logout_uri = config.redirect_after_logout_uri,
  }
end

function Utilities:exit(httpStatusCode, message)
  kong.response.exit(httpStatusCode, message)
end

function Utilities:injectAccessToken(accessToken)
  ngx.req.set_header("X-Access-Token", accessToken)
end

function Utilities:injectIDToken(idToken)
  local tokenStr = JSON:encode(idToken)
  ngx.req.set_header("X-ID-Token", ngx.encode_base64(tokenStr))
end

function Utilities:injectUser(user)
  local tmp_user = user
  tmp_user.id = user.sub
  tmp_user.username = user.preferred_username
  ngx.ctx.authenticated_credential = tmp_user
  local userinfo = JSON:encode(user)
  ngx.req.set_header("X-User-Info", ngx.encode_base64(userinfo))
  ngx.req.set_header("X-Auth-Mechanism", "google-oidc")
  ngx.req.set_header(constants.HEADERS.CONSUMER_ID, user.email)
end

function Utilities:injectAnonymousConsumer(anonymousUserId)
  local consumer_cache_key, consumer, err
  local cache = kong.cache
  consumer_cache_key = kong.db.consumers:cache_key(anonymousUserId)
  consumer, err      = cache:get(consumer_cache_key, nil,
                                 kong.client.load_consumer,
                                 anonymousUserId)
  if err then
    kong.log.err(err)
    return false
  end

  ngx.req.set_header(constants.HEADERS.ANONYMOUS, true)
  ngx.req.set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  ngx.req.set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
end

local function set_consumer(consumer, credential)
  kong.client.authenticate(consumer, credential)

  local set_header = kong.service.request.set_header
  local clear_header = kong.service.request.clear_header

  if consumer and consumer.id then
    set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
  else
    clear_header(constants.HEADERS.CONSUMER_ID)
  end

  if consumer and consumer.custom_id then
    set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
  else
    clear_header(constants.HEADERS.CONSUMER_CUSTOM_ID)
  end

  if consumer and consumer.username then
    set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  else
    clear_header(constants.HEADERS.CONSUMER_USERNAME)
  end

  if credential and credential.client_id then
    set_header(constants.HEADERS.CREDENTIAL_IDENTIFIER, credential.client_id)
  else
    clear_header(constants.HEADERS.CREDENTIAL_IDENTIFIER)
  end

  clear_header(constants.HEADERS.CREDENTIAL_USERNAME)

  if credential then
    clear_header(constants.HEADERS.ANONYMOUS)
  else
    set_header(constants.HEADERS.ANONYMOUS, true)
  end
end


function Utilities:setConsumer(config)
  -- Retrieve the consumer from the config and set it in the headers (important if doing multiple auth)
  -- Returns: nil
  if config.anonymous then
    local consumer_cache_key = kong.db.consumers:cache_key(config.anonymous)
    local consumer, err = kong.cache:get(consumer_cache_key, nil,
            kong.client.load_consumer,
            config.anonymous, true)
    if err then
      kong.log.err("[utilities.lua] : Error in fetching consumer" .. err)
      return kong.response.error(err.status, err.message, err.headers)
    end

    set_consumer(consumer)
  else
    return kong.response.error(err.status, err.message, err.headers)
  end
end


return Utilities