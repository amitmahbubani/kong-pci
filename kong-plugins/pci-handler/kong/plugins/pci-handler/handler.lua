local cjson = require "cjson"
local socket = require "socket"
local http = require "socket.http"
local ltn12 = require "ltn12"

local BasePlugin = require "kong.plugins.base_plugin"
local PciHandler = BasePlugin:extend()

PciHandler.PRIORITY = 50

local str_lower = string.lower
local str_find = string.find
local set_raw_body = kong.service.request.set_raw_body
local set_header = kong.service.request.set_header

local CONTENT_TYPE = "content-type"
local CONTENT_LENGTH = "content-length"

-- The plugin handler's constructor. It's only role is to instantiate itself
-- with a name, "pci-handler" in this case.
function PciHandler:new()
  PciHandler.super.new(self, "pci-handler")
end

local function parse_json(body)
  if body then
    local status, res = pcall(cjson.decode, body)
    if status then
      return res
    end
  end
end

-- Checks if content_type is "application/json"
local function is_json_body(content_type)
  return content_type and str_find(str_lower(content_type), "application/json", nil, true)
end

-- Validates card attributes in the request body
local function validate_body_params(conf, card_fields_schema, body)
  -- Test for parameter presence (and other validations)
  for i,field in pairs(card_fields_schema) do
    if body[field] == nil then
      return false
    end
  end

  return true
end

-- Extracts card attributes from the request body as per config
-- specified in card_fields_schema and saves it tp a new table: "card_data"
local function set_card_data(card_fields_schema, body)
  local card_data = {}
  for i,field in pairs(card_fields_schema) do
    card_data[field] = body[field]
  end

  return card_data
end

-- Transforms the request body. Removes the card_fields attributes
-- and adds a new attribute with the generated token string
local function transform_body(conf, card_fields_schema, body, token)
  local new_body = body
  for i,field in pairs(card_fields_schema) do
    new_body[field] = nil
  end

  new_body[conf.card_token_output_field] = token
  return new_body
end

-- Makes a HTTP call to the tokenizer service for card tokenization
local function tokenize_card(conf, card_data)
  local req_body = cjson.encode(card_data)
  local res_body = {} -- for the response body

  local _, response_code, _, _ = http.request {
    method = "POST",
    url = conf.tokenizer_url,
    source = ltn12.source.string(req_body),
    headers = {
      ["content-type"] = "application/json",
      ["content-length"] = tostring(#req_body),
    },
    sink = ltn12.sink.table(res_body)
  }

  res_body = table.concat(res_body)
  local r, err = cjson.decode(res_body)
  if err then
    kong.log.err("failed to parse the response from tokenizer")
    return kong.response.exit(500, { error = "Request failed" })
  end

  return r.token
end

function PciHandler:access(conf)
  PciHandler.super.access(self)

  local card_fields_schema = {
    num = conf.card_number_field,
    exp_month = conf.card_expiry_month_field,
    exp_year = conf.card_expiry_year_field,
    cvv = conf.card_cvv_field
  }

  local has_card_data = false
  local req_body = {}
  local is_body_transformed = false
  local new_req_body = {}

  if is_json_body(kong.request.get_header(CONTENT_TYPE)) then
    -- Parse the JSON body, to a lua table
    req_body = parse_json(kong.request.get_raw_body())

    -- Validates body for card attributes
    if not validate_body_params(conf, card_fields_schema, req_body) then
      return kong.response.exit(400, { error = "Invalid request: card data" })
    end

    has_card_data = true
  end

  if has_card_data then
    -- Extracts card data from the request body and sets it to the
    -- format defined in the the card_fields_schema table
    local card_data = set_card_data(card_fields_schema, req_body)

    -- Tokenize the card attributes
    token = tokenize_card(conf, card_data)

    -- Transform the request body - replaces the card attributes with
    -- token received in the previous step
    new_req_body = transform_body(conf, card_fields_schema, req_body, token)

    -- Reset the request body
    local new_req_body_json = cjson.encode(new_req_body)
    set_raw_body(new_req_body_json)
    set_header(CONTENT_LENGTH, #new_req_body_json)
  end
end

return PciHandler
