-- vim: sw=4:expandtab
-- luacheck: std lua54

package.path = "lib/?.lua;lib/?/init.lua;" .. package.path

local posix = require "posix"
local ustar = require "ustar"

local libglob = posix.glob

--- Stateless generator function that enumerates the contents of a directory.
local function glob(pattern)
    local function enumerate()
        local dir = libglob.glob(pattern, libglob.GLOB_MARK)
        if not dir then return end
        for _, name in ipairs(dir) do
            coroutine.yield(name)
            if name:match("/$") then
                pattern = string.format("%s*", name)
                enumerate()
            end
        end
    end
    return coroutine.wrap(enumerate)
end

for pathname in glob(arg[1]) do
    local obj = ustar.io.stat(pathname)
    pcall(ustar.io.save, obj)
end
