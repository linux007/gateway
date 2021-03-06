local _LEVELS = {
   stderr = 0,
   emerg = 1,
   verbose = 2,  -- alert
   crit = 3,
   error = 4,
   warn = 5,
   notice = 6,
   info = 7,
   debug  = 8,
   quiet = 9
}

local ngx_log = ngx.log

local r_levels = {}
for k, v in pairs(_LEVELS) do
  r_levels[v] = k
end

local log_lvl = _LEVELS.crit
local old_lvl

local _M = {
  levels = _LEVELS
}

function _M.set_lvl(lvl)
  if r_levels[lvl] then
    log_lvl = lvl
  end
end

function _M.disable()
  if not old_lvl then
    old_lvl = log_lvl
    log_lvl = _LEVELS.quiet
  end
end

function _M.enable()
  log_lvl = old_lvl or log_lvl
  old_lvl = nil
end

local function log(lvl, ...)
  local format
  local args = {...}
  if lvl >= log_lvl then
    format = table.remove(args, 1)
    if type(format) ~= "string" then
      error("expected argument #1 or #2 to be a string", 3)
    end

    local msg = string.format(format, unpack(args))
    -- if log_lvl < _LEVELS.info or lvl == _LEVELS.error then
    --   msg = string.format("%s [%s] %s", os.date("%Y/%m/%d %H:%M:%S"), r_levels[lvl], msg)
    -- end

    ngx.log(lvl, msg)
  end
end

return setmetatable(_M, {
  __call = function(_, ...)
    return log(_LEVELS.info, ...)
  end,
  __index = function(t, key)
    if _LEVELS[key] then
      return function(...)
        log(_LEVELS[key], ...)
      end
    end
    return rawget(t, key)
  end
})
