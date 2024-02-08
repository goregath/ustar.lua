-- luacheck: std lua54

-- luacheck: globals chain
-- luacheck: globals duplicate
-- luacheck: globals iter
-- luacheck: globals zip
-- luacheck: globals posix
-- luacheck: globals ustar

package.path = "lib/?.lua;lib/?/init.lua;" .. package.path

posix = require("posix")
ustar = require("ustar")

print(require"inspect"(posix))
print(require"inspect"(ustar))

do

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
            iter(conf):each(function(k,v) H[k] = v end)
            return H
        end)
    end
end

-- luacheck: globals glob
function glob(...)
    local libglob = posix.glob
	return
      zip({ ... }, duplicate(libglob.GLOB_ERR)) -- [globstr, GLOB_ERR]
	: map (libglob.glob) -- [tbl, errno]
    : map (function(t,i) return t and t or i end) -- [tbl or errno]
    : zip ({...}) -- [(tbl or errno), globstr]
	: filter (globassert) -- [tbl] or error()
	: reduce (function(a,e) return chain(a,e) end, {}) -- [path]
end

do
    local exports = require "fun"
    local methods = getmetatable(exports.wrap()).__index
    methods.apply = iter_mutator
    exports()
end

end

--------------------------------------------------------------------------------

-- io.output "/tmp/out.tar"


-- glob ( "*", "lib/ustar/*.lua" )
chain (
    glob( "*" )
    ,   { "README.md" }
)
:    map ( ustar.io.stat )
: filter ( ustar.util.type.isreg )
:  apply { uid = 0, gid = 0}
:  apply { uname = "root", gname = "root" }
:  apply { mtime = os.time() }
:   each ( ustar.io.save )

