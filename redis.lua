local redis = require "resty.redis"
local resty_lock = require "resty.lock"

local ngx_req = ngx.req
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

local red = redis:new()

red:set_timeout(1000) -- 1 sec
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

cache_key = "cache_key"
 -- step 1:
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
local val = ngx.location.capture("/subrequest_fastcgi", { method = ngx.HTTP_GET, args = ngx_req.get_uri_args()})
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

local ok, err = red:set_keepalive(10000, 100)
if not ok then
    ngx_log(ngx_ERR, "failed to set keepalive: " .. err)
    return
end

ngx.say("result: ", val.body)
