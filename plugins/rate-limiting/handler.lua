local policies = require "gateway.plugins.rate-limiting.policies"
local BasePlugin = require "gateway.plugins.base_plugin"
local singletons = require "gateway.singletons"
local responses = require "gateway.tools.responses"
local cjson = require "cjson"

local ngx_var = ngx.var
local pairs = pairs
local math_floor = math.floor
local ngx_now = ngx.now
local ngx_log = ngx.log
local ngx_timer_at = ngx.timer.at


local RateLimitingHandler = BasePlugin:extend()

RateLimitingHandler.PRIORITY = 100

local function get_identifier()
	local identifier
	if ngx_var.http_x_forwarded_for ~= nil then
		identifier = ngx_var.http_x_forwarded_for
	else
		identifier = ngx_var.remote_addr
	end

	return identifier
end

local function get_usage(policy,identifier,current_timestamp,limits)
	local usage = {}
	local stop
	-- print(cjson.encode(policies))

	for name, limit in pairs(limits) do
		local current_usage, err = policies[policy].usage(singletons.configuration, identifier, current_timestamp, name)
	    if err then
	      return nil, nil, err
	    end

	    local remaining = limit - current_usage

	    usage[name] = {
	    	limit = limit,
	    	remaining = remaining
	    }

	    if remaining <= 0 then
	      stop = name
	    end
	end

	return usage, stop
end

function RateLimitingHandler:new()
	RateLimitingHandler.super.new(self, "rate-limiting")
end

function RateLimitingHandler:access()
	RateLimitingHandler.super.access(self)

	local identifier = get_identifier()
	local policy = singletons.configuration.rate_policy

	-- Load current metric for configured period
	local limits = {
		second = 5,
		minute = 200,
	}

	local current_timestamp = math_floor(ngx_now()) * 1000
	local usage, stop, err = get_usage(singletons.configuration.rate_policy, identifier, current_timestamp, limits)
	if err then
		return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
	end

	if usage then
		for k, v in pairs(usage) do
			ngx_log(ngx.DEBUG, "X-RateLimiting-limit-" .. k .. "=" .. v.limit)
			ngx_log(ngx.DEBUG, "X-RateLimiting-remaining-" .. k .. "=" .. math.max(0, (stop == nil or stop == k) and v.remaining - 1 or v.remaining) )
		end

	    -- If limit is exceeded, terminate the request
	    if stop then
	        return responses.send(429, "API rate limit exceeded")
	    end
	end

	local incr = function(premature, limits, identifier, current_timestamp, value)
    if premature then
      return
    end
    policies[policy].increment(singletons.configuration, limits, identifier, current_timestamp, value)
  end

  -- Increment metrics for configured periods if the request goes through
  local ok, err = ngx_timer_at(0, incr, limits, identifier, current_timestamp, 1)
  if not ok then
    ngx_log(ngx.ERR, "failed to create timer: ", err)
  end

end

return RateLimitingHandler

