-- vim: sw=4:noexpandtab

package.path = "lib/?.lua;lib/?/init.lua;" .. package.path

posix = require("posix")
ustar = require("ustar")

local function globassert(status, pattern)
	local libglob = posix.glob
	if status == libglob.GLOB_NOMATCH then
		error(string.format("glob: %s: pattern does not match", pattern), 0)
	elseif status == libglob.GLOB_ABORTED then
		error(string.format("glob: %s: cannot open or read directory", pattern), 0)
	elseif status == libglob.GLOB_NOSPACE then
		error(string.format("glob: %s: out of memory", pattern), 0)
	end
	return true
end

local function iter_mutator(self, conf, ...)
	if type(conf) == "function" then
		local args = { ... }
		return self:map(function(H)
			conf(H, table.unpack(args))
			return H
		end)
	else
		return self:map(function(H)
			iter(conf):each(function(k, v) H[k] = v end)
			return H
		end)
	end
end

function glob(...)
	local libglob = posix.glob
	return
	  zip ( iter(...), duplicate(libglob.GLOB_ERR) ) -- [globstr, GLOB_ERR]
	: map ( libglob.glob ) -- [tbl, errno]
	: map ( function(t, i) return t and t or i end ) -- [tbl or errno]
	: zip ( iter(...) ) -- [(tbl or errno), globstr]
	: filter ( globassert ) -- [tbl] or error()
	: reduce ( function(a, e) return chain(a, e) end, {} ) -- [path]
end

local exports = require "fun"
local methods = getmetatable(exports.wrap()).__index

methods.apply = iter_mutator

exports()
