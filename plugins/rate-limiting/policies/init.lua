local timestamp = require "gateway.tools.timestamp"
local cache = require "gateway.tools.database_cache"
local redis = require "resty.redis"
local pairs = pairs
local fmt = string.format
local ngx_var = ngx.var
local ngx_log = ngx.log
local cjson = require "cjson"

local fmt = string.format

local get_local_key = function(identifier, period_date, name)
  return fmt("ratelimit:%s:%s:%s",identifier, period_date, name)
end

local EXPIRATIONS = {
  second = 1,
  minute = 60,
  hour = 3600,
}
return {
	["local"] = {
		increment = function(conf, limits, identifier, current_timestamp, value)
			local periods = timestamp.get_timestamps(current_timestamp)
			for period, period_date in pairs(periods) do
				if limits[period] then
					local cache_key = get_local_key(identifier, period_date, period)
					-- todo
					local _, err = cache.sh_incr(cache_key, value, 0)
					if err then
						ngx_log("[rate-limiting] could not increment counter for period '" .. period .. "': " .. tostring(err))
						return nil, err
					end
				end
			end

			return true
		end,
		usage = function(conf, identifier,current_timestamp,name)
			local periods = timestamp.get_timestamps(current_timestamp)
			local cache_key = get_local_key(identifier, periods[name], name)

			local current_metric, err = cache.sh_get(cache_key)
			if err then
				return nil, err
			end
			return current_metric and current_metric or 0
		end
	},
	["redis"] = {
		increment = function(conf, limits, identifier, current_timestamp, value)
			local red = redis:new()
			red:set_timeout(conf.redis_timeout)
			local ok, err = red:connect(conf.redis_host, conf.redis_port)
			if not ok then
				ngx_log(ngx.ERR, "failed to connect to Redis: ", err)
				return nil, err
			end

			if conf.redis_password and conf.redis_password ~= "" then
				local ok, err = red:auth(conf.redis_password)
				if not ok then
				  ngx_log(ngx.ERR, "failed to connect to Redis: ", err)
				  return nil, err
				end
			end

			if conf.redis_database ~= nil and conf.redis_database > 0 then
				local ok, err = red:select(conf.redis_database)
				if not ok then
				  ngx_log(ngx.ERR, "failed to change Redis database: ", err)
				  return nil, err
				end
			end
			local periods = timestamp.get_timestamps(current_timestamp)
			for period, period_date in pairs(periods) do
				if limits[period] then
					local cache_key = get_local_key(identifier, period_date, period)
					local exists, err = red:exists(cache_key)
			        if err then
			            ngx_log(ngx.ERR, "failed to query Redis: ", err)
			            return nil, err
			        end
			        red:init_pipeline((not exists or exists == 0) and 2 or 1)
			        red:incrby(cache_key, value)
			        if not exists or exists == 0 then
			            red:expire(cache_key, EXPIRATIONS[period])
			        end

			        local _, err = red:commit_pipeline()
			        if err then
			            ngx_log(ngx.ERR, "failed to commit pipeline in Redis: ", err)
			            return nil, err
			        end
				end
			end

			local ok, err = red:set_keepalive(10000, 100)
	        if not ok then
	        	ngx_log(ngx.ERR, "failed to set Redis keepalive: ", err)
	        	return nil, err
	        end

	      	return true
		end,
		usage = function(conf, identifier,current_timestamp,name)

			local red = redis:new()
			red:set_timeout(conf.redis_timeout)
			local ok, err = red:connect(conf.redis_host, conf.redis_port)
			if not ok then
				ngx_log(ngx.ERR, "failed to connect to Redis: ", err)
				return nil, err
			end

			if conf.redis_password and conf.redis_password ~= "" then
				local ok, err = red:auth(conf.redis_password)
				if not ok then
					ngx_log(ngx.ERR, "failed to connect to Redis: ", err)
					return nil, err
				end
			end

			if conf.redis_database ~= nil and conf.redis_database > 0 then
				local ok, err = red:select(conf.redis_database)
				if not ok then
					ngx_log(ngx.ERR, "failed to change Redis database: ", err)
					return nil, err
				end
			end
			local periods = timestamp.get_timestamps(current_timestamp)
			local cache_key = get_local_key(identifier, periods[name], name)
			local current_metric, err = red:get(cache_key)
			if err then
				return nil, err
			end
			if current_metric == ngx.null then
		        current_metric = nil
		    end
			return current_metric and current_metric or 0
		end
	}
}


