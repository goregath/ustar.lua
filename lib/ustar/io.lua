-- vim: sw=4:noexpandtab

local unistd = require("posix.unistd")
local usrdb = require("posix.pwd")
local grpdb = require("posix.grp")
local stat = require("posix.sys.stat")

local P = require("ustar.util.path")
local T = require("ustar.util.type")
local R = require("ustar.record")

local M = {}

function M.stat(filename)
	if type(filename) ~= "string" then filename = tostring(filename) end
	local st, msg, errno = stat.lstat(filename)
	if not st then
		return nil, msg, errno
	end
	local path = P.normalize(filename)
	local usr = usrdb.getpwuid(st.st_uid)
	local grp = grpdb.getgrgid(st.st_gid)
	local h = R.new()
	if stat.S_ISREG(st.st_mode) ~= 0 then
		h.size = st.st_size
		h.typeflag = T.REG
	elseif stat.S_ISDIR(st.st_mode) ~= 0 then
		path = string.format("%s/", path)
		h.typeflag = T.DIR
	elseif stat.S_ISLNK(st.st_mode) ~= 0 then
		h.linkname = unistd.readlink(filename)
		h.typeflag = T.SYM
	elseif stat.S_ISCHR(st.st_mode) ~= 0 then
		h.devmajor = st.st_dev >> 8 & 0xff
		h.devminor = st.st_dev & 0xff
		h.typeflag = T.CHR
	elseif stat.S_ISBLK(st.st_mode) ~= 0 then
		h.devmajor = st.st_dev >> 8 & 0xff
		h.devminor = st.st_dev & 0xff
		h.typeflag = T.BLK
	elseif stat.S_ISFIFO(st.st_mode) ~= 0 then
		h.typeflag = T.FIFO
	else
		return nil, "socket type not supported"
	end
	if usr then
		h.uname = usr.pw_name
	end
	if grp then
		h.gname = grp.gr_name
	end
	h.name, h.prefix = P.split(path, true)
	h.mode = st.st_mode & 0xfff
	h.mtime = st.st_mtime
	h.uid = st.st_uid
	h.gid = st.st_gid
	rawset(h, "@src", filename)
	return h
end

function M.save(self, from, to)
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

return M
