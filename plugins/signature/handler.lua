
local hmac = require 'gateway.tools.hmac'
local singletons = require "gateway.singletons"
local cjson = require "cjson"
local log = require "gateway.tools.log"
local ngx_get_headers = ngx.req.get_headers
local ngx_var = ngx.var
local ngx_hmac = ngx.hmac_sha1
local ngx_now = ngx.now
local ngx_base64 = ngx.encode_base64
local ngx_log = ngx.log

local expired
local signature = ""

local BasePlugin = require "gateway.plugins.base_plugin"

local SignatureHandler = BasePlugin:extend()

SignatureHandler.PRIORITY = 999

local function validate_signature(x_signature, signature, salt)
	local expired = 86400 * 10
	log.debug("X-Sinature-Expire:" .. expired-(ngx_now() - salt))
	if (x_signature == ngx_base64(signature)) and (ngx_now() - salt) < expired then
		return true
	end
	return false
end

function SignatureHandler:new()
  SignatureHandler.super.new(self, "signature")
end

function SignatureHandler:access()
	SignatureHandler.super.access(self)
	local ngx_headers = ngx_get_headers()

	-- local current_timestamp = timestamp.get_utc()
	-- log.debug('utc_time:' .. current_timestamp)
	-- log.debug('ngx_now:' .. math.floor(ngx.now()) * 1000)

	local x_signature = ngx_headers['X-Signature'] or ""
	local salt = ngx_headers['X-Timestamp'] or 0

	signature = ngx_hmac(singletons.configuration.sign_private_secret, ngx_var.request_uri .. salt)

	ngx_log(ngx.DEBUG, 'string:' .. ngx_var.request_uri .. salt)
	ngx_log(ngx.DEBUG, 'signature:'..ngx_base64(signature))
	ngx_log(ngx.DEBUG, 'x-signature:'..x_signature)
	local ret = validate_signature(x_signature, signature, salt)
	if not ret then
		--ngx.say('deny access!')
		return ngx.exit(ngx.HTTP_FORBIDDEN)
	end
end

return SignatureHandler