
local type       = type
local pairs      = pairs
local ipairs     = ipairs
local tostring   = tostring
local find       = string.find

local _M = {}
--- Try to load a module.
-- Will not throw an error if the module was not found, but will throw an error if the
-- loading failed for another reason (eg: syntax error).
-- @param module_name Path of the module to load (ex: kong.plugins.keyauth.api).
-- @return success A boolean indicating wether the module was found.
-- @return module The retrieved module, or the error in case of a failure
function _M.load_module_if_exists(module_name)
  local status, res = pcall(require, module_name)
  if status then
    return true, res
  -- Here we match any character because if a module has a dash '-' in its name, we would need to escape it.
  elseif type(res) == "string" and find(res, "module '" .. module_name .. "' not found", nil, true) then
    return false, res
  else
    error(res)
  end
end

--- packs a set of arguments in a table.
-- Explicitly sets field `n` to the number of arguments, so it is `nil` safe
_M.pack = function(...) return {n = select("#", ...), ...} end

--- unpacks a table to a list of arguments.
-- Explicitly honors the `n` field if given in the table, so it is `nil` safe
_M.unpack = function(t, i, j) return unpack(t, i or 1, j or t.n or #t) end

return _M
