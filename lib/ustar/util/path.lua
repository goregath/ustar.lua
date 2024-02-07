-- vim: sw=4:noexpandtab

-- Trim leading and trailing slash from path.
local function trim(path)
	if type(path) ~= "string" then path = tostring(path) end
	return path:gsub("^/*(.-)/*$", "%1")
end

--- Balance path between prefix and name components.
--  @return name
--  @return prefix
local function split(path, plain)
	if type(path) ~= "string" then path = tostring(path) end
	if not plain then
		path = trim(path)
	end
	local n = path:len()
	-- find the longest possible path prefix
	for p in path:reverse():gmatch("()/") do
		local i = n - p
		if i < 155 then -- sizeof prefix field
			return path:sub(i + 2), path:sub(1, i)
		end
	end
	return path, nil
end

-- TODO remove leading ../ or ../../ from member names
local function normalize(path)
	path = trim(path)
	if path == "" then
		path = "."
	end
	return path
end

return {
	normalize = normalize,
	split = split,
	trim = trim,
}
