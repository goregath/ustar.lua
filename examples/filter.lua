-- vim: sw=4:expandtab
-- luacheck: std lua54

package.path = "lib/?.lua;lib/?/init.lua;examples/lib/?.lua;" .. package.path

require "lambda"

io.output "/tmp/out.tar"

-- ARCHIVE SOURCES

    glob { "lib/ustar/*.lua",
           "examples/*.lua" }
:    map ( ustar.io.stat )
: filter ( ustar.type.isreg )
:  apply { uid = 0,
           gid = 0,
           uname = "root",
           gname = "root",
           mtime = os.time() }
:   each ( ustar.io.save )

