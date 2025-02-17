local function LoadFile(path, env)
    local fastio = require "fastio"
    local data = fastio.readall_v(path, path)
    local func, err = fastio.loadlua(data, path, env)
    if not func then
        error(err)
    end
    return func
end

local function LoadDbg(expr)
    local env = setmetatable({}, {__index = _G})
    function env.dofile(path)
        return LoadFile(path, env)()
    end
    assert(load(expr, "=(expr)", "t", env))()
end

local i = 1
while true do
    if arg[i] == '-e' then
        i = i + 1
        assert(arg[i], "'-e' needs argument")
        LoadDbg(arg[i])
    elseif arg[i] == nil then
        break
    end
    i = i + 1
end

__ANT_RUNTIME__ = true

local platform = require "bee.platform"
local fs = require "bee.filesystem"

local function app_path(name)
	if platform.os == "windows" then
		return fs.path(os.getenv "LOCALAPPDATA") / name
	elseif platform.os == "linux" then
		return fs.path(os.getenv "XDG_DATA_HOME" or (os.getenv "HOME" .. "/.local/share")) / name
	elseif platform.os == "macos" then
		return fs.path(os.getenv "HOME" .. "/Library/Caches") / name
	else
		error "unknown os"
	end
end

local sandbox_path = (function ()
	if platform.os == "ios" then
		local ios = require "ios"
		return fs.path(ios.directory(ios.NSDocumentDirectory))
	elseif platform.os == "android" then
		local android = require "android"
		return fs.path(android.directory(android.ExternalDataPath))
	else
		return app_path "ant" / "sandbox"
	end
end)()

local bundle_path = (function ()
	if platform.os == "ios" then
		local ios = require "ios"
		return fs.path(ios.bundle())
	elseif platform.os == "android" then
		local android = require "android"
		return fs.path(android.directory(android.InternalDataPath))
	else
		return app_path "ant" / "bundle"
	end
end)()

local config = {
	vfs = { slot = "" }
}

local needcleanup

if platform.os == "ios" then
	local ios = require "ios"
	local clean_up_next_time = ios.setting "clean_up_next_time"
	if clean_up_next_time == true then
		ios.setting("clean_up_next_time", false)
		needcleanup = true
	end
	config.vfs.slot = ios.setting "root_slot" or ""
	local server_type = ios.setting "server_type"
	if server_type == nil or server_type == "usb" then
		config.nettype = "listen"
		config.address = "127.0.0.1"
		config.port = 2018
	elseif server_type == "tcp" then
		config.nettype = "connect"
		local server_address = ios.setting "server_address"
		local ip, port = server_address:match "^([^:]+):(%d+)"
		if ip and port then
			config.address = ip
			config.port = port
		else
			config.address = "127.0.0.1"
			config.port = "2018"
		end
	elseif server_type == "none" then
	end
elseif platform.os == "android" then
	-- usb
	config.nettype = "listen"
	config.address = "127.0.0.1"
	config.port = 2018
else
	local datalist = require "datalist"
	local f <close> = io.open((sandbox_path / "boot.settings"):string(), "rb")
	if f then
		local setting = datalist.parse(f:read "a")
		config.nettype = setting.nettype
		config.address = setting.address
		config.port = setting.port
	else
		config.nettype = "connect"
		config.address = "127.0.0.1"
		config.port = "2018"
	end
end

config.vfs.bundlepath = bundle_path:string():gsub("/?$", "/")
config.vfs.localpath = (sandbox_path / "vfs"):string():gsub("/?$", "/")
fs.create_directories(sandbox_path)
fs.current_path(sandbox_path)
if needcleanup then
	fs.remove_all(config.vfs.localpath)
end
fs.create_directories(config.vfs.localpath)

local boot = require "ltask.bootstrap"
local vfs = require "vfs"
local thread = require "bee.thread"
local socket = require "bee.socket"

thread.newchannel "IOreq"

local s, c = socket.pair()
local io_req = thread.channel "IOreq"

io_req:push {
    config = config,
    fd = s:detach(),
}

vfs.iothread = boot.preinit [[
-- IO thread
assert(loadfile "/engine/firmware/io.lua")()
]]

vfs.initfunc("/engine/firmware/init_thread.lua", {
	fd = c:detach(),
	editor = __ANT_EDITOR__,
})

dofile "/main.lua"
