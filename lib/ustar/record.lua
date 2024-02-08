-- vim: sw=4:noexpandtab

local P = require("ustar.util.path")

local M = {}
local mt = {}

local function pass(s) return s and tostring(s):match("^.+$") or nil end
local function oct2dec(s) return tonumber(s:match("^%d+") or "0", 8) end
local function dec2oct(i) return string.format("%o", tonumber(i) or "0") end

local S <const> = "!1=c99xc7xc7xc7xc11xc11xc8c1c99xc5xc2c31xc31xc7xc7xc154xxxxxxxxxxxxx"
local F <const> = {
	name     = { i=01, s=pass,    g=pass    }, --   0 100
	mode     = { i=02, s=dec2oct, g=oct2dec }, -- 100 8
	uid      = { i=03, s=dec2oct, g=oct2dec }, -- 108 8
	gid      = { i=04, s=dec2oct, g=oct2dec }, -- 116 8
	size     = { i=05, s=dec2oct, g=oct2dec }, -- 124 12
	mtime    = { i=06, s=dec2oct, g=oct2dec }, -- 136 12
	chksum   = { i=07,            g=oct2dec }, -- 148 8
	typeflag = { i=08, s=dec2oct, g=oct2dec }, -- 156 1
	linkname = { i=09, s=pass,    g=pass    }, -- 157 100
	magic    = { i=10,            g=pass    }, -- 257 6
	version  = { i=11,            g=oct2dec }, -- 263 2
	uname    = { i=12, s=pass,    g=pass    }, -- 265 32
	gname    = { i=13, s=pass,    g=pass    }, -- 297 32
	devmajor = { i=14, s=dec2oct, g=oct2dec }, -- 329 8
	devminor = { i=15, s=dec2oct, g=oct2dec }, -- 337 8
	prefix   = { i=16, s=pass,    g=pass    }, -- 345 155
}

function mt.__tostring(t)
	return string.format("record: %q", t:getpath())
end

function mt.__index(t, k)
	if type(k) == "number" then return rawget(t, k) or "" end
	local f = F[k]
	if f then
		local r = t[f.i]
		return f.g(r)
	end
end

function mt.__newindex(t, k, v)
	local f = assert(F[k], "unknown field")
	local c = assert(f.s, "readonly field")
	if v ~= nil then
		local r = c(v)
		rawset(t, f.i, r)
	else
		rawset(t, f.i, nil)
	end
end

function mt.__pairs(t)
	local iter = pairs(F)
	return function(_, k)
		k = iter(F, k)
		if k ~= nil then
			return k, t[k]
		end
	end, t, nil
end

function mt.__len()
	return 16
end

local function set(self, opts)
	if not opts then return end
	for o, v in pairs(opts) do
		if F[o] and F[o].s then
			self[o] = v
		end
	end
	return self
end

local function setraw(self, opts)
	if not opts then return end
	for o, v in pairs(opts) do
		if F[o] then
			rawset(self, F[o].i, v)
		end
	end
	return self
end

local function setpath(self, path)
	self.name, self.prefix = P.split(path, true)
end

local function getpath(self)
	if self.prefix then
		return string.format("%s/%s", self.prefix, self.name or "")
	end
	return self.name
end

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

function M.write(self, from, to)
	if not from and self["@src"] then from = assert(io.open(self["@src"])) end
	if not to then to = io.output() end
	local n = self.size + 512
	local p = 0
	local blk = self:tostring()
	while blk do
		to:write(blk)
		p = p + #blk
		if p == n then break end
		blk = assert(from:read(math.min(4096, n - p)), "unexpected eof")
	end
	if n % 512 ~= 0 then
		local pad = 512 - p % 512
		to:write(string.rep("\0", pad))
	end
end

function M.new(opts)
	local h = setmetatable({
		getpath = getpath,
		rawset = setraw,
		set = set,
		setpath = setpath,
		tostring = tostring,
		write = M.write,
		[10] = "ustar",
		[11] = "00",
	}, mt)
	set(h, opts)
	return h
end

return M
