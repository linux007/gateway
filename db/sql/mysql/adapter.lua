
local error = error
local ipairs = ipairs
local pairs = pairs
local require = require
local log = require 'gateway.tools.log'

-- settings
local timeout_subsequent_ops = 1000 -- 1 sec
local max_idle_timeout = 10000 -- 10 sec
local max_packet_size = 1024 * 1024  -- 1m
local charset = utf8mb4

local Mysql = {}
Mysql.default_database = 'mysql'

local function mysql_connect(options)
	-- load mysql
	local mysql = require 'resty.mysql'

	-- create sql object
	local db, err = mysql:new()
	if not db then  error("failed to instantiate mysql: " .. err) end

	db:set_timeout(timeout_subsequent_ops)

	 local db_options = {
        host = options.host,
        port = options.port,
        database = options.database,
        user = options.user,
        password = options.password,
        max_packet_size = max_packet_size
    }
    local ok, err, errno, sqlstate = db:connect(db_options)
    if not ok then  error("failed to connect: " .. err .. ": " .. errcode .. " " .. sqlstate) end

    log.info("connected to mysql.")
    db:query("SET NAMES utf8")
    return db
end

local function mysql_keepalive(db, options)
	-- put it into the connection pool
	local ok, err = db:set_keepalive(max_idle_timeout, options.pool)
	if not ok then error("failed to set mysql keepalive: " .. err) end
end

-- quote
function Mysql.quote(str)
	return ngx.quote_sql_str(str)
end

-- execute query on db
local function db_execute(options, db, sql)
    local res, err, errno, sqlstate = db:query(sql)
    if not res then error("bad mysql result: " .. err .. ": " .. errno .. " " .. sqlstate) end
    return res
end

-- execute a query
function Mysql.execute(options, sql)
    -- get db object
    local db = mysql_connect(options)
    -- execute query
    local res = db_execute(options, db, sql)
    -- keepalive
    mysql_keepalive(db, options)
    -- return
    return res
end

--- Execute a query and return the last ID
function Mysql.execute_and_return_last_id(options, sql, id_col)
    -- get db object
    local db = mysql_connect(options)
    -- execute query
    db_execute(options, db, sql)
    -- get last id
    local id_col = id_col
    local res = db_execute(options, db, "SELECT LAST_INSERT_ID() AS " .. id_col .. ";")
    -- keepalive
    mysql_keepalive(db, options)
    return tonumber(res[1][id_col])
end

return Mysql
