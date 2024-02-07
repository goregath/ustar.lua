-- vim: sw=4:noexpandtab

local unistd = require("posix.unistd")
local usrdb = require("posix.pwd")
local grpdb = require("posix.grp")
local stat = require("posix.sys.stat")

local pathutil = require("ustar.util.path")
local R = require("ustar.record")

local M = {}

function M.stat(filename)
	if type(filename) ~= "string" then filename = tostring(filename) end
	local st, msg, errno = stat.lstat(filename)
	if not st then
		return nil, msg, errno
	end
	local usr = usrdb.getpwuid(st.st_uid)
	local grp = grpdb.getgrgid(st.st_gid)
	local type =
		stat.S_ISREG(st.st_mode) ~= 0 and 'reg' or
		stat.S_ISDIR(st.st_mode) ~= 0 and 'dir' or
		stat.S_ISLNK(st.st_mode) ~= 0 and 'sym' or
		stat.S_ISCHR(st.st_mode) ~= 0 and 'chr' or
		stat.S_ISBLK(st.st_mode) ~= 0 and 'blk' or
		stat.S_ISFIFO(st.st_mode) ~= 0 and 'pipe' or
		stat.S_ISSOCK(st.st_mode) ~= 0 and false
	if not type then
		return nil, "socket type not supported"
	end
	local path = pathutil.normalize(filename)
	local h = R.new()
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
	h.name, h.prefix = pathutil.split(path, true)
	h.mode = st.st_mode & 0xfff
	h.typeflag = type
	h.mtime = st.st_mtime
	h.uid = st.st_uid
	h.gid = st.st_gid
	rawset(h, "@src", filename)
	return h
end

return M
