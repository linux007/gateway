local log = require 'gateway.tools.log'

local pl_stringio = require "pl.stringio"
local pl_config = require 'pl.config'
local pl_file = require 'pl.file'
local pl_path = require 'pl.path'

local DEFAULT_PATHS = {
  "/etc/gateway.conf"
}

local _M = {}

local mt = { __index = _M }

function _M.new(self)
    return setmetatable({}, mt)
end

function _M.load(self, path)
	local from_file_conf = {}

	if path and not pl_path.exists(path) then
		return nil, "no file at: " .. path 
	elseif not path then
		--todo
		for _, default_path in ipairs(DEFAULT_PATHS) do
			if pl_path.exists(default_path) then
				path = default_path
				break
			end
			log.verbose("no config file found at %s", default_path)
		end
	end

	if not path then
		log.verbose("no config file, skipping loading")
	else
		local f, err = pl_file.read(path)
		if not f then
			return nil, err
		end
		log.verbose("reading config file at %s", path)

		local s = pl_stringio.open(f)

		from_file_conf, err = pl_config.read(s, {
      		-- list_delim = "_blank_" -- mandatory but we want to ignore it
		})
		s:close()

		if not from_file_conf then
			return nil, err
		end
	end

	return from_file_conf

	-- return setmetatable(from_file_conf, nil) -- remove Map mt
end


return _M