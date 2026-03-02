local HttpService = game:GetService("HttpService")

local FileSystem = {}
FileSystem.__index = FileSystem

local function readGlobal(name)
	local env = nil
	if getfenv then
		env = getfenv()
	end
	if env and env[name] ~= nil then
		return env[name]
	end
	return _G[name]
end

local function normalizePath(path)
	path = tostring(path or "")
	path = path:gsub("\\", "/")
	path = path:gsub("/+", "/")
	return path
end

function FileSystem.new(logger)
	local self = setmetatable({}, FileSystem)
	self.logger = logger
	return self
end

function FileSystem:supportsIO()
	return type(readGlobal("readfile")) == "function"
		and type(readGlobal("writefile")) == "function"
		and type(readGlobal("makefolder")) == "function"
end

function FileSystem:join(...)
	local items = table.pack(...)
	local out = {}
	for i = 1, items.n do
		local token = tostring(items[i])
		if token ~= "" then
			table.insert(out, token)
		end
	end
	return normalizePath(table.concat(out, "/"))
end

function FileSystem:exists(path)
	path = normalizePath(path)
	local isfile = readGlobal("isfile")
	local isfolder = readGlobal("isfolder")

	if type(isfile) == "function" then
		local okFile, fileExists = pcall(isfile, path)
		if okFile and fileExists then
			return true
		end
	end

	if type(isfolder) == "function" then
		local okFolder, folderExists = pcall(isfolder, path)
		if okFolder and folderExists then
			return true
		end
	end

	return false
end

function FileSystem:isFolder(path)
	local isfolder = readGlobal("isfolder")
	path = normalizePath(path)
	if type(isfolder) ~= "function" then
		return false
	end
	local ok, result = pcall(isfolder, path)
	return ok and result == true
end

function FileSystem:ensureFolder(path)
	path = normalizePath(path)
	local makefolder = readGlobal("makefolder")
	local isfolder = readGlobal("isfolder")

	if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
		if self.logger then
			self.logger:warn("makefolder/isfolder not available in this executor", { path = path })
		end
		return false
	end

	local current = ""
	for segment in path:gmatch("[^/]+") do
		current = current == "" and segment or (current .. "/" .. segment)
		local okCheck, exists = pcall(isfolder, current)
		if not okCheck or not exists then
			local okCreate, createErr = pcall(makefolder, current)
			if not okCreate then
				if self.logger then
					self.logger:error("failed to create folder", { path = current, error = tostring(createErr) })
				end
				return false
			end
		end
	end

	return true
end

function FileSystem:read(path, defaultValue)
	path = normalizePath(path)
	local readfile = readGlobal("readfile")
	local isfile = readGlobal("isfile")

	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return defaultValue
	end

	local okExists, exists = pcall(isfile, path)
	if not okExists or not exists then
		return defaultValue
	end

	local okRead, data = pcall(readfile, path)
	if okRead then
		return data
	end

	if self.logger then
		self.logger:error("failed to read file", { path = path, error = tostring(data) })
	end
	return defaultValue
end

function FileSystem:write(path, content)
	path = normalizePath(path)
	content = tostring(content or "")
	local writefile = readGlobal("writefile")
	if type(writefile) ~= "function" then
		if self.logger then
			self.logger:warn("writefile not available", { path = path })
		end
		return false
	end

	local folder = path:match("^(.*)/[^/]+$")
	if folder and folder ~= "" then
		self:ensureFolder(folder)
	end

	local okWrite, writeErr = pcall(writefile, path, content)
	if okWrite then
		return true
	end

	if self.logger then
		self.logger:error("failed to write file", { path = path, error = tostring(writeErr) })
	end
	return false
end

function FileSystem:list(path)
	path = normalizePath(path)
	local listfiles = readGlobal("listfiles")
	if type(listfiles) ~= "function" then
		return {}
	end

	local ok, items = pcall(listfiles, path)
	if not ok or type(items) ~= "table" then
		return {}
	end
	return items
end

function FileSystem:readJSON(path, defaultValue)
	local raw = self:read(path, nil)
	if raw == nil then
		return defaultValue
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok then
		return decoded
	end

	if self.logger then
		self.logger:warn("json decode failed", { path = path, error = tostring(decoded) })
	end
	return defaultValue
end

function FileSystem:writeJSON(path, data)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not ok then
		if self.logger then
			self.logger:error("json encode failed", { path = path, error = tostring(encoded) })
		end
		return false
	end
	return self:write(path, encoded)
end

return FileSystem
