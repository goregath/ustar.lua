-- vim: sw=4:noexpandtab
-- luacheck: std lua54

-- io.output "/tmp/out.tar"

glob {
	"*",
	"*.md",
}
:   uniq ()
:    map ( ustar.io.stat )
: filter ( ustar.type.isreg )
:  apply { uid = 0 }
:  apply { gid = 0 }
:  apply { uname = "root" }
:  apply { gname = "root" }
:  apply { mtime = os.time() }
:   each ( ustar.io.save )

