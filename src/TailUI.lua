local function loadModule(moduleName, fallbackLoader)
	local env = getfenv and getfenv() or _G
	local custom = (env and env.__TAILUI_REQUIRE) or _G.__TAILUI_REQUIRE
	if type(custom) == "function" then
		return custom(moduleName)
	end
	return fallbackLoader()
end

local Logger = loadModule("Core.Logger", function()
	return require(script.Core.Logger)
end)
local SafeCall = loadModule("Core.SafeCall", function()
	return require(script.Core.SafeCall)
end)
local FileSystem = loadModule("Core.FileSystem", function()
	return require(script.Core.FileSystem)
end)
local ConfigManager = loadModule("Core.ConfigManager", function()
	return require(script.Core.ConfigManager)
end)

local ThemeManager = loadModule("Theme.ThemeManager", function()
	return require(script.Theme.ThemeManager)
end)
local BuiltinThemes = loadModule("Theme.BuiltinThemes", function()
	return require(script.Theme.BuiltinThemes)
end)

local IconRegistry = loadModule("Assets.IconRegistry", function()
	return require(script.Assets.IconRegistry)
end)
local FontRegistry = loadModule("Assets.FontRegistry", function()
	return require(script.Assets.FontRegistry)
end)

local KeybindManager = loadModule("Input.KeybindManager", function()
	return require(script.Input.KeybindManager)
end)

local Runtime = loadModule("Executor.Runtime", function()
	return require(script.Executor.Runtime)
end)

local Window = loadModule("UI.Window", function()
	return require(script.UI.Window)
end)

local TailUI = {}
TailUI.__index = TailUI
TailUI.VERSION = "2.1.0"

local singleton = nil

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in pairs(value) do
		out[key] = deepCopy(child)
	end
	return out
end

local function splitPath(path)
	local parts = {}
	for part in tostring(path):gmatch("[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

local function getNested(tableRef, path)
	local current = tableRef
	for _, key in ipairs(splitPath(path)) do
		if type(current) ~= "table" then
			return nil
		end
		current = current[key]
	end
	return current
end

local function setNested(tableRef, path, value)
	local parts = splitPath(path)
	local current = tableRef
	for index, key in ipairs(parts) do
		if index == #parts then
			current[key] = value
			return
		end
		if type(current[key]) ~= "table" then
			current[key] = {}
		end
		current = current[key]
	end
end

local function defaultHubName()
	return "tail-hub"
end

function TailUI.new(options)
	options = options or {}

	local self = setmetatable({}, TailUI)
	self.options = options
	self.hubName = options.hubName or options.hub or defaultHubName()
	self.windows = {}

	self.logger = Logger.new({
		prefix = "[TailUI]",
		maxEntries = options.maxLogs or 300,
	})

	self.fileSystem = FileSystem.new(self.logger)
	self.configManager = ConfigManager.new(self.fileSystem, self.logger)
	self.paths = self.configManager:initialize(self.hubName, options.defaults)
	self.config = self.configManager:load()

	self.iconRegistry = IconRegistry.new(self.logger)
	self.fontRegistry = FontRegistry.new(self.logger)
	self.keybindManager = KeybindManager.new(self.logger)
	self.runtime = Runtime.new(self.logger)
	self.themeManager = ThemeManager.new(self.fileSystem, self.logger, self.configManager)

	self.themeManager:registerBuiltins(BuiltinThemes)
	if self.config.theme.autoLoadDiskThemes ~= false then
		self.themeManager:loadDiskThemes()
	end

	local appliedTheme = self.config.theme.active or "midnight-pro"
	local okTheme, themeErr = self.themeManager:apply(appliedTheme)
	if not okTheme then
		self.logger:warn("failed to apply configured theme, using fallback", {
			theme = appliedTheme,
			error = themeErr,
		})
		self.themeManager:apply("midnight-pro")
	end

	self.iconRegistry:setPreferredLibraries(self.config.icons.preferred or { "lucide" })

	self.safeCall = SafeCall.new(self.logger, function(scope, err)
		for _, window in ipairs(self.windows) do
			pcall(function()
				window:reportError(scope, err)
			end)
		end
	end)

	return self
end

function TailUI:_buildWindowContext()
	return {
		logger = self.logger,
		safeCall = self.safeCall,
		themeManager = self.themeManager,
		iconRegistry = self.iconRegistry,
		fontRegistry = self.fontRegistry,
		keybindManager = self.keybindManager,
		runtime = self.runtime,
		config = self.config,
	}
end

function TailUI:createWindow(options)
	local window = Window.new(self:_buildWindowContext(), options or {})
	local owner = self
	local originalDestroy = window.destroy
	window.destroy = function(win, ...)
		originalDestroy(win, ...)
		for index = #owner.windows, 1, -1 do
			if owner.windows[index] == win then
				table.remove(owner.windows, index)
				break
			end
		end
	end
	window.Destroy = window.destroy
	table.insert(self.windows, window)
	return window
end

function TailUI:registerTheme(name, themeData, opts)
	opts = opts or {}
	local ok, err = self.themeManager:register(name, themeData, opts.source or "runtime")
	if not ok then
		return false, err
	end

	if opts.persist == true then
		self.themeManager:createDiskTheme(name, themeData)
	end
	return true
end

function TailUI:applyTheme(name, overrides)
	local ok, err = self.themeManager:apply(name, overrides)
	if ok then
		self.config.theme.active = name
		self:saveConfig()
	end
	return ok, err
end

function TailUI:listThemes(detailed)
	local list = self.themeManager:list()
	if detailed == true then
		return list
	end
	local names = {}
	for _, item in ipairs(list) do
		table.insert(names, item.name)
	end
	return names
end

function TailUI:listThemesDetailed()
	return self.themeManager:list()
end

function TailUI:createThemeFolder(name)
	return self.configManager:createThemeFolder(name)
end

function TailUI:registerIconLibrary(name, provider)
	return self.iconRegistry:registerLibrary(name, provider)
end

function TailUI:listIconLibraries()
	return self.iconRegistry:listLibraries()
end

function TailUI:setPreferredIconLibraries(libraries)
	self.iconRegistry:setPreferredLibraries(libraries)
	self.config.icons.preferred = deepCopy(libraries)
	self:saveConfig()
end

function TailUI:registerFont(name, fontEnum)
	return self.fontRegistry:register(name, fontEnum)
end

function TailUI:listFonts()
	return self.fontRegistry:list()
end

function TailUI:createKeybindSet(name)
	return self.keybindManager:registerSet(name)
end

function TailUI:activateKeybindSet(name)
	return self.keybindManager:setActiveSet(name)
end

function TailUI:getActiveKeybindSet()
	return self.keybindManager:getActiveSet()
end

function TailUI:listKeybindSets()
	return self.keybindManager:listSets()
end

function TailUI:bindKeybind(setName, options)
	return self.keybindManager:bind(setName, options)
end

function TailUI:getRuntimeInfo()
	return self.runtime:report()
end

function TailUI:getVersion()
	return TailUI.VERSION
end

function TailUI:getConfig(path)
	if not path then
		return deepCopy(self.config)
	end
	return deepCopy(getNested(self.config, path))
end

function TailUI:setConfig(path, value, shouldSave)
	setNested(self.config, path, value)
	if shouldSave ~= false then
		self:saveConfig()
	end
end

function TailUI:saveConfig()
	return self.configManager:save(self.config)
end

function TailUI:reloadConfig()
	self.config = self.configManager:load()
	return self.config
end

function TailUI:getPaths()
	return self.configManager:getPaths()
end

function TailUI:getStorageAPI()
	return {
		supportsIO = function()
			return self.fileSystem:supportsIO()
		end,
		ensureFolder = function(_, path)
			return self.fileSystem:ensureFolder(path)
		end,
		read = function(_, path, defaultValue)
			return self.fileSystem:read(path, defaultValue)
		end,
		write = function(_, path, content)
			return self.fileSystem:write(path, content)
		end,
		readJSON = function(_, path, defaultValue)
			return self.fileSystem:readJSON(path, defaultValue)
		end,
		writeJSON = function(_, path, data)
			return self.fileSystem:writeJSON(path, data)
		end,
		paths = deepCopy(self.paths),
	}
end

function TailUI:makeFolder(path)
	return self.fileSystem:ensureFolder(path)
end

function TailUI:writeFile(path, content)
	return self.fileSystem:write(path, content)
end

function TailUI:readFile(path, defaultValue)
	return self.fileSystem:read(path, defaultValue)
end

function TailUI:readJSON(path, defaultValue)
	return self.fileSystem:readJSON(path, defaultValue)
end

function TailUI:writeJSON(path, data)
	return self.fileSystem:writeJSON(path, data)
end

function TailUI:getHubRoot()
	return self.paths.root
end

function TailUI:getLogs()
	return self.logger:getEntries()
end

function TailUI:shutdown()
	for _, window in ipairs(self.windows) do
		pcall(function()
			window:destroy()
		end)
	end
	self.windows = {}
	if self.keybindManager then
		self.keybindManager:destroy()
	end
end

function TailUI.tailwindow(selfOrOptions, maybeOptions)
	if getmetatable(selfOrOptions) == TailUI then
		local instance = selfOrOptions
		return instance:createWindow(maybeOptions or {})
	end

	local options = selfOrOptions or {}
	if not singleton then
		local bootstrap = deepCopy(options.bootstrap or {})
		if options.hubName and bootstrap.hubName == nil then
			bootstrap.hubName = options.hubName
		end
		singleton = TailUI.new(bootstrap)
	end

	return singleton:createWindow(options)
end

function TailUI.getSingleton(options)
	if not singleton then
		singleton = TailUI.new(options or {})
	end
	return singleton
end

function TailUI.resetSingleton()
	if singleton then
		singleton:shutdown()
	end
	singleton = nil
end

TailUI.CreateWindow = TailUI.createWindow
TailUI.RegisterTheme = TailUI.registerTheme
TailUI.ApplyTheme = TailUI.applyTheme
TailUI.ListThemes = TailUI.listThemes
TailUI.ListThemesDetailed = TailUI.listThemesDetailed
TailUI.RegisterIconLibrary = TailUI.registerIconLibrary
TailUI.RegisterFont = TailUI.registerFont
TailUI.GetConfig = TailUI.getConfig
TailUI.SetConfig = TailUI.setConfig
TailUI.GetStorageAPI = TailUI.getStorageAPI
TailUI.MakeFolder = TailUI.makeFolder
TailUI.WriteFile = TailUI.writeFile
TailUI.ReadFile = TailUI.readFile
TailUI.ReadJSON = TailUI.readJSON
TailUI.WriteJSON = TailUI.writeJSON
TailUI.CreateKeybindSet = TailUI.createKeybindSet
TailUI.ActivateKeybindSet = TailUI.activateKeybindSet
TailUI.GetActiveKeybindSet = TailUI.getActiveKeybindSet
TailUI.ListKeybindSets = TailUI.listKeybindSets
TailUI.BindKeybind = TailUI.bindKeybind
TailUI.GetRuntimeInfo = TailUI.getRuntimeInfo
TailUI.GetVersion = TailUI.getVersion

return TailUI
