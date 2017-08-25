local BasePlugin = require "gateway.plugins.base_plugin"
local redis = require "resty.redis"
local resty_lock = require "resty.lock"
-- local singletons = require "gateway.singletons"

local ngx_req = ngx.req
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

local CachingHandler = BasePlugin:extend()

CachingHandler.PRIORITY = 1

local function get_cache_key()
	return  "cache_key"
end

function CachingHandler:new()
  CachingHandler.super.new(self, "caching")
end

function CachingHandler:rewrite()
	CachingHandler.super.rewrite(self)
end

function CachingHandler:access()
	-- CachingHandler.super.access(self)
	-- -- local conf = singletons.configuration
	local conf = {
		redis_timeout = 10000,
		redis_host = "127.0.0.1",
		redis_port = 6379,

	}
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

	local method = ngx_req.get_method()
	local cache_key = get_cache_key()

	-- local result = red:get(cache_key)
	-- ngx.say(result)
	-- ngx.say("hello world")
	
	if method == "GET" then
		 -- step 1:
		print("step 1");
		local res, err = red:get(cache_key)
		if err then
		    ngx_log(ngx_ERR, "failed to get dog: ", err)
		    return nil, err
		end
		if res ~= ngx.null then
		   ngx.say("result: ", res)
		   return
		end

		-- cache miss!
		-- step 2:
		print("step 2");
		local lock, err = resty_lock:new("cache_lock")
		if not lock then
		    return ngx_log(ngx_ERR, "failed to create lock: " .. err)
		end

		local elapsed, err = lock:lock(cache_key)
		if not elapsed then
		    return ngx_log(ngx_ERR, "failed to acquire the lock: " .. err)
		end

		-- lock successfully acquired!

		-- step 3:
		print("step 3");
		-- someone might have already put the value into the cache
		-- so we check it here again:
		val, err = red:get(cache_key)
		if val ~= ngx.null then
		    local ok, err = lock:unlock()
		    if not ok then
		        ngx_log(ngx_ERR, "failed to unlock: " .. err)
		        return nil, err
		    end

		    ngx.say("result: ", val)
		    return
		end

		print("step 4")

		--- step 4:
		local val = ngx.location.capture("/subrequest_fastcgi" .. ngx.var.uri, { method = ngx.HTTP_GET, args = ngx_req.get_uri_args()})
		if not val then
		    local ok, err = lock:unlock()
		    if not ok then
		        ngx_log(ngx_ERR, "failed to unlock: " .. err)
		        return nil, err
		    end

		    -- FIXME: we should handle the backend miss more carefully
		    -- here, like inserting a stub value into the cache.

		    ngx.say("no value found")
		    return
		end

		-- update the shm cache with the newly fetched value
		local ok, err = red:set(cache_key, val.body)
		if not ok then
		    local ok, err = lock:unlock()
		    if not ok then
		        ngx_log(ngx_ERR, "failed to unlock: " .. err)
		        return nil, err
		    end

		    ngx_log(ngx_ERR, "failed to update shm cache: " .. err)
		    return nil, err
		end

		local ok, err = lock:unlock()
		if not ok then
		    return ngx_log(ngx_ERR, "failed to unlock: " .. err)
		end

		local ok, err = red:set_keepalive(1000, 200)
		if not ok then
		    ngx_log(ngx_ERR, "failed to set keepalive: " .. err)
		    return
		end

		-- print(val.body)
		ngx.say("result: ", val.body)
		return 

	end


end
return CachingHandler