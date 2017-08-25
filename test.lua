local system_constants = require "lua_system_constants"
local O_CREAT = system_constants.O_CREAT()
local O_WRONLY = system_constants.O_WRONLY()
local O_APPEND = system_constants.O_APPEND()
local S_IRUSR = system_constants.S_IRUSR()
local S_IWUSR = system_constants.S_IWUSR()
local S_IRGRP = system_constants.S_IRGRP()
local S_IROTH = system_constants.S_IROTH()
local oflags = bit.bor(O_WRONLY, O_CREAT, O_APPEND)
local mode = bit.bor(S_IRUSR, S_IWUSR, S_IRGRP, S_IROTH)
local ffi = require "ffi"
ffi.cdef[[
 int open(const char * filename, int flags, int mode);
 int write(int fd, const void * ptr, int numbytes);
 int close(int fd);
 char *strerror(int errnum);
]]
local file_descriptors = {}
local fd = file_descriptors["/tmp/access.log"]
--if fd and conf.reopen then
--    ffi.C.close(fd)
--    file_descriptors["/tmp/access.log"] = nil
--    fd = nil
--end

local _M = {}

function _M.log()
    if not fd then
     fd = ffi.C.open("/tmp/access.log", oflags, mode)
     if fd < 0 then
         local errno = ffi.errno()
         ngx.log(ngx.ERR, "[file-log] failed to open the file: ", ffi.string(ffi.C.strerror(errno)))
     else
         file_descriptors["/tmp/access.log"] = fd
     end
    end

    local msg = "test\n"

    ffi.C.write(fd, msg, #msg)

end

return _M
