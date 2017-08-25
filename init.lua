local singletons =  require 'gateway.singletons'
local utils = require 'gateway.tools.utils'
local cjson = require 'cjson'
local db = nil


local function load_plugins(config)
	local sorted_plugins, config_plugins = {}, {}

	if type(config.plugins) == "string" then
		config_plugins[#config_plugins+1] = config.plugins
	else
		config_plugins = config.plugins
	end


	for _, plugin in ipairs(config_plugins) do
		local ok, handler = utils.load_module_if_exists("gateway.plugins." .. plugin .. ".handler")

		if not ok then
			ngx.log(ngx.WARN, plugin .. " plugin not installed\n" .. handler)
			return nil, plugin .. " plugin not installed\n" .. handler
		end
		sorted_plugins[#sorted_plugins+1] = {
			name = plugin,
			handler = handler()
		}
	end

	-- sort plugins by order of execution
	table.sort(sorted_plugins, function(a, b)
	local priority_a = a.handler.PRIORITY or 0
	local priority_b = b.handler.PRIORITY or 0
	return priority_a > priority_b
	end)

	return sorted_plugins
end

local GateWay = {}

function GateWay.init()
	local conf_loader = require 'gateway.conf_loader'
	local conf_path = "/etc/gateway.conf"

	local pl_pretty = require 'pl.pretty'
	local SqlDatabase = require 'gateway.db.sql'

	local config = conf_loader:load()

	local db_options = {
		adapter = 'mysql',
        host = "127.0.0.1",
        port = 3306,
        database = "test",
        user = "root",
        password = "123456",
        pool = 5
	}

	db = SqlDatabase.new(db_options)


	-- local res = Mysql:execute('select * from crontab')

	local cjson = require 'cjson'

	singletons.loaded_plugins = load_plugins(config)
	singletons.dao = Mysql
	singletons.configuration = config

end

function GateWay.init_worker()
	print(type(singletons.loaded_plugins))
end

function GateWay.rewrite()

end

function GateWay.access()
	for _, plugin in pairs(singletons.loaded_plugins) do
		plugin.handler:access()
	end
end

function GateWay.content()
	-- local res = db:execute('select * from crontab')
	-- ngx.say(cjson.encode(res))
end

function GateWay.header_filter()

end


function GateWay.body_filter()

end

function GateWay.log()

end


return GateWay