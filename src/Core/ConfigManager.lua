local DEFAULT_CONFIG = {
	internal = {
		version = "2.1.0",
		searchEnabled = true,
		showLoading = true,
		mobileBreakpoint = 920,
	},
	window = {
		title = "Tail UI",
		subtitle = "Executor UI Framework",
		size = { width = 660, height = 420 },
		minimumSize = { width = 420, height = 300 },
		resizable = true,
		draggable = true,
		forceDarkOnFullscreen = true,
		defaultTransparency = 0.08,
	},
	theme = {
		active = "midnight-pro",
		autoLoadDiskThemes = true,
	},
	performance = {
		maxLogs = 300,
		isolation = true,
	},
	icons = {
		preferred = { "lucide" },
	},
	fonts = {
		default = "ui-sans",
	},
}

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function deepMerge(base, incoming)
	if type(base) ~= "table" then
		return deepCopy(incoming)
	end
	local output = deepCopy(base)
	if type(incoming) ~= "table" then
		return output
	end
	for key, value in pairs(incoming) do
		if type(value) == "table" and type(output[key]) == "table" then
			output[key] = deepMerge(output[key], value)
		else
			output[key] = deepCopy(value)
		end
	end
	return output
end

local function sanitizeHubName(name)
	name = tostring(name or "tail-hub")
	name = name:lower()
	name = name:gsub("[^%w%-_ ]", "")
	name = name:gsub("%s+", "-")
	if name == "" then
		name = "tail-hub"
	end
	return name
end

function ConfigManager.new(fileSystem, logger)
	local self = setmetatable({}, ConfigManager)
	self.fileSystem = fileSystem
	self.logger = logger
	self.defaults = deepCopy(DEFAULT_CONFIG)
	self.paths = nil
	self.hubName = nil
	return self
end

function ConfigManager:getDefaultConfig()
	return deepCopy(self.defaults)
end

function ConfigManager:initialize(hubName, extraDefaults)
	self.hubName = sanitizeHubName(hubName)
	if type(extraDefaults) == "table" then
		self.defaults = deepMerge(self.defaults, extraDefaults)
	end

	local root = self.fileSystem:join("workspace", self.hubName)
	self.paths = {
		root = root,
		bin = self.fileSystem:join(root, "bin"),
		themeRoot = self.fileSystem:join(root, "themes"),
		cache = self.fileSystem:join(root, "cache"),
		logs = self.fileSystem:join(root, "logs"),
		config = self.fileSystem:join(root, "bin", "configurations.config"),
		themeBootstrap = self.fileSystem:join(root, "themes", "initate.lua"),
	}

	self.fileSystem:ensureFolder(self.paths.root)
	self.fileSystem:ensureFolder(self.paths.bin)
	self.fileSystem:ensureFolder(self.paths.themeRoot)
	self.fileSystem:ensureFolder(self.paths.cache)
	self.fileSystem:ensureFolder(self.paths.logs)

	if not self.fileSystem:exists(self.paths.config) then
		self.fileSystem:writeJSON(self.paths.config, self.defaults)
	end

	if not self.fileSystem:exists(self.paths.themeBootstrap) then
		local bootstrap = table.concat({
			"-- Tail UI theme bootstrap",
			"-- Any folder inside ./themes that has a theme.json file will be auto-loaded.",
			"return {",
			"\tversion = '1.0',",
			"\tautoDiscover = true,",
			"}",
			"",
		}, "\n")
		self.fileSystem:write(self.paths.themeBootstrap, bootstrap)
	end

	return self.paths
end

function ConfigManager:getPaths()
	return self.paths
end

function ConfigManager:load()
	local raw = self.fileSystem:readJSON(self.paths.config, {})
	return deepMerge(self.defaults, raw)
end

function ConfigManager:save(config)
	return self.fileSystem:writeJSON(self.paths.config, config)
end

function ConfigManager:getPath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	return self.paths[path]
end

function ConfigManager:listThemeFolders()
	local out = {}
	local listed = self.fileSystem:list(self.paths.themeRoot)
	for _, fullPath in ipairs(listed) do
		local normalized = tostring(fullPath):gsub("\\", "/")
		if self.fileSystem:isFolder(normalized) then
			local name = normalized:match("([^/]+)$")
			if name then
				table.insert(out, {
					name = name,
					path = normalized,
					themeFile = normalized .. "/theme.json",
				})
			end
		end
	end
	return out
end

function ConfigManager:createThemeFolder(name)
	local safeName = sanitizeHubName(name)
	local path = self.fileSystem:join(self.paths.themeRoot, safeName)
	self.fileSystem:ensureFolder(path)
	return path
end

return ConfigManager
