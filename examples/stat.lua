-- vim: sw=4:expandtab
-- luacheck: std lua54

package.path = "lib/?.lua;lib/?/init.lua;" .. package.path

local posix = require "posix"
local ustar = require "ustar"

local function dir(dirname, callback)
    for name in posix.dirent.files(dirname) do
        if name ~= "." and name ~= ".." then
            local file = dirname and string.format("%s/%s", dirname, name) or name
            local obj = assert(ustar.io.stat(file))
            if callback(obj) ~= false then
                if obj:isdir() then
                    dir(file, callback)
                end
            end
        end
    end
end

local function find(pathname)
    return coroutine.wrap(function()
        dir(pathname, function(fileobj)
            local name = posix.basename(fileobj:getpath())
            if name:match("^%.") then
                return false
            end
            coroutine.yield(fileobj)
        end)
    end)
end

for fileobj in find() do
    fileobj:save()
end
