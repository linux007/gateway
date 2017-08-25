
local pairs = pairs
local require = require
local setmetatable = setmetatable
local tconcat = table.concat
local log = require 'gateway.tools.log'

local tappend  = function(t, v) t[#t+1] = v end

local SqlDatabase = {}
SqlDatabase.__index = SqlDatabase


function SqlDatabase.new(options)
	local required_options = {
		adapter = true,
		host = true,
		port = true,
		database = true,
		user = true,
		password = true,
		pool = true
	}

	for k, _ in pairs(options) do required_options[k] = nil end
	local missing_options = {}
	for k, _ in pairs(required_options) do tappend(missing_options, k) end

	if #missing_options > 0 then
		log.error("missing required database options: %s", tconcat(missing_options, ', '))
		ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
	end

	-- init adapter  注意括号
	local adapter = require('gateway.db.sql.' .. options.adapter .. '.adapter')

	-- init instance
	local instance = {
		options = options,
		adapter = adapter
	}

	setmetatable(instance, SqlDatabase)

	return instance
end

function SqlDatabase:execute(sql)
	return self.adapter.execute(self.options, sql)
end

function SqlDatabase:execute_and_return_last_id(sql)
	return self.adapter.execute_and_return_last_id(self.options, sql)
end

return SqlDatabase