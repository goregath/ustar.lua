-- @Author: Oliver Zimmer
-- @Date:   2023-07-28 15:31:29
-- @Last Modified by:   Oliver Zimmer
-- @Last Modified time: 2023-07-30 12:37:10
-- vim: sw=4:noexpandtab

local M = {}

local T <const> = {
	['-'] = 0, ['reg'] = 0,
	['h'] = 1, ['lnk'] = 1,
	['l'] = 2, ['sym'] = 2,
	['c'] = 3, ['chr'] = 3,
	['b'] = 4, ['blk'] = 4,
	['d'] = 5, ['dir'] = 5,
	['p'] = 6, ['pipe'] = 6,
}

local function pass(s) return s and tostring(s) or nil end
local function oct2dec(s) return tonumber(s:match("^%d+") or "0", 8) end
local function dec2oct(i) return string.format("%o", tonumber(i) or 0) end
local function sym2oct(s) return T[s] or dec2oct(s) end

local S <const> = "!1=c99xc7xc7xc7xc11xc11xc8c1c99xc5xc2c31xc31xc7xc7xc154xxxxxxxxxxxxx"
local F <const> = {
	name     = { i=01, s=pass,    g=pass    }, --   0 100
	mode     = { i=02, s=dec2oct, g=oct2dec }, -- 100 8
	uid      = { i=03, s=dec2oct, g=oct2dec }, -- 108 8
	gid      = { i=04, s=dec2oct, g=oct2dec }, -- 116 8
	size     = { i=05, s=dec2oct, g=oct2dec }, -- 124 12
	mtime    = { i=06, s=dec2oct, g=oct2dec }, -- 136 12
	chksum   = { i=07,            g=oct2dec }, -- 148 8
	typeflag = { i=08, s=sym2oct, g=oct2dec }, -- 156 1
	linkname = { i=09, s=pass,    g=pass    }, -- 157 100
	magic    = { i=10,            g=pass    }, -- 257 6
	version  = { i=11,            g=oct2dec }, -- 263 2
	uname    = { i=12, s=pass,    g=pass    }, -- 265 32
	gname    = { i=13, s=pass,    g=pass    }, -- 297 32
	devmajor = { i=14, s=dec2oct, g=oct2dec }, -- 329 8
	devminor = { i=15, s=dec2oct, g=oct2dec }, -- 337 8
	prefix   = { i=16, s=pass,    g=pass    }, -- 345 155
}

local function tostring(self)
	local chk = 0
	-- c45 *alculate checksum
	rawset(self, 7, string.rep("\x20", 8))
	local blk = string.pack(S, table.unpack(self))
	for c in blk:gmatch("[^\0]") do chk = chk + c:byte() end
	rawset(self, 7, string.format("%o", chk))
	-- final header fields to block conversion
	return string.pack(S, table.unpack(self))
end

local function set(self, opts)
	for o, v in pairs(opts) do
		if F[o] and F[o].s then
			self[o] = v
		end
	end
	return self
end

local function setraw(self, opts)
	for o, v in pairs(opts) do
		if F[o] then
			rawset(self, F[o].i, v)
		end
	end
	return self
end

local function setpath(self, path, plain)
	if type(path) ~= "string" then path = tostring(path) end
	if not plain then
		path = path:gsub("^/*(.-)/*$", "%1")
	end
	local n = path:len()
	for p in path:reverse():gmatch("()/") do
		local i = n - p
		if i < 155 then
			self.prefix = path:sub(1, i)
			self.name = path:sub(i + 2)
			return self
		end
	end
	self.prefix = nil
	self.name = path
	return self
end

local function write(self, handle)
	if not handle then handle = io.stdout end
	local header = tostring(self)
	handle:write(header)
end

local mt = {
	__index = function(t, k)
		if type(k) == "number" then return rawget(t, k) or "" end
		local f = F[k]
		if f then
			local r = t[f.i]
			return f.g(r)
		end
	end,
	__newindex = function(t, k, v)
		local f = assert(F[k], "unknown field")
		local c = assert(f.s, "readonly field")
		local r = c(v)
		rawset(t, f.i, r)
	end,
	__pairs = function(t)
		local iter = pairs(F)
		return function(_, k)
			k = iter(F, k)
			if k ~= nil then
				return k, t[k]
			end
		end, t, nil
	end,
	__tostring = tostring,
	__len = function() return 16 end,
}

function M.new(opts)
	local h = setmetatable({
		rawset = setraw,
		set = set,
		setpath = setpath,
		tostring = tostring,
		write = write,
		[10] = "ustar",
		[11] = "00",
	}, mt)
	if opts then
		set(h, opts)
	end
	return h
end

function M.stat(filename)
	if type(filename) ~= "string" then filename = tostring(filename) end
	local unistd = require("posix.unistd")
	local usrdb = require("posix.pwd")
	local grpdb = require("posix.grp")
	local stat = require("posix.sys.stat")
	local st, msg, errno = stat.lstat(filename)
	if not st then
		return nil, msg, errno
	end
	local usr = usrdb.getpwuid(st.st_uid)
	local grp = grpdb.getgrgid(st.st_gid)
	local type =
		stat.S_ISREG(st.st_mode)  ~= 0 and 'reg' or
		stat.S_ISDIR(st.st_mode)  ~= 0 and 'dir' or
		stat.S_ISLNK(st.st_mode)  ~= 0 and 'sym' or
		stat.S_ISCHR(st.st_mode)  ~= 0 and 'chr' or
		stat.S_ISBLK(st.st_mode)  ~= 0 and 'blk' or
		stat.S_ISFIFO(st.st_mode) ~= 0 and 'pipe' or
		stat.S_ISSOCK(st.st_mode) ~= 0 and false
	if not type then
		return nil, "socket type not supported"
	end
	local h = M.new()
	local path = filename:gsub("^/*(.-)/*$", "%1")
	if path == "" then
		path = "."
	end
	if type == "reg" then
		h.size = st.st_size
	elseif type == "dir" then
		path = string.format("%s/", path)
	elseif type == "sym" then
		h.linkname = unistd.readlink(filename)
	elseif type == "chr" or type == "blk" then
		h.devmajor = st.st_dev >> 8 & 0xff
		h.devminor = st.st_dev & 0xff
	end
	if usr then
		h.uname = usr.pw_name
	end
	if grp then
		h.gname = grp.gr_name
	end
	setpath(h, path, true)
	h.mode = st.st_mode & 0xfff
	h.typeflag = type
	h.mtime = st.st_mtime
	h.uid = st.st_uid
	h.gid = st.st_gid
	return h
end

return M
