local ThemeManager = {}
ThemeManager.__index = ThemeManager

local function cloneDeep(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in pairs(value) do
		out[key] = cloneDeep(child)
	end
	return out
end

local function mergeDeep(base, incoming)
	if type(base) ~= "table" then
		return cloneDeep(incoming)
	end
	local out = cloneDeep(base)
	if type(incoming) ~= "table" then
		return out
	end
	for key, value in pairs(incoming) do
		if type(value) == "table" and type(out[key]) == "table" then
			out[key] = mergeDeep(out[key], value)
		else
			out[key] = cloneDeep(value)
		end
	end
	return out
end

local function encodeForDisk(value)
	if typeof(value) == "Color3" then
		return {
			__tail_color3 = true,
			r = value.R,
			g = value.G,
			b = value.B,
		}
	end

	if type(value) ~= "table" then
		return value
	end

	local out = {}
	for key, child in pairs(value) do
		out[key] = encodeForDisk(child)
	end
	return out
end

local function decodeFromDisk(value)
	if type(value) ~= "table" then
		return value
	end

	if value.__tail_color3 == true then
		local r = value.r or 0
		local g = value.g or 0
		local b = value.b or 0
		if r > 1 or g > 1 or b > 1 then
			r = math.clamp(r / 255, 0, 1)
			g = math.clamp(g / 255, 0, 1)
			b = math.clamp(b / 255, 0, 1)
		end
		return Color3.new(r, g, b)
	end

	local out = {}
	for key, child in pairs(value) do
		out[key] = decodeFromDisk(child)
	end
	return out
end

function ThemeManager.new(fileSystem, logger, configManager)
	local self = setmetatable({}, ThemeManager)
	self.fileSystem = fileSystem
	self.logger = logger
	self.configManager = configManager
	self.themes = {}
	self.activeName = nil
	self.listeners = {}
	self.nextListenerId = 0
	return self
end

function ThemeManager:register(name, themeData, source)
	if type(name) ~= "string" or name == "" then
		return false, "invalid theme name"
	end
	if type(themeData) ~= "table" then
		return false, "theme must be a table"
	end

	self.themes[name] = {
		data = cloneDeep(themeData),
		source = source or "runtime",
	}
	return true
end

function ThemeManager:registerBuiltins(builtins)
	if type(builtins) ~= "table" then
		return
	end
	for name, theme in pairs(builtins) do
		self:register(name, theme, "builtin")
	end
end

function ThemeManager:createDiskTheme(name, data)
	local themeFolder = self.configManager:createThemeFolder(name)
	local themeFile = self.fileSystem:join(themeFolder, "theme.json")
	return self.fileSystem:writeJSON(themeFile, encodeForDisk(data))
end

function ThemeManager:loadDiskThemes()
	local items = self.configManager:listThemeFolders()
	for _, folder in ipairs(items) do
		local payload = self.fileSystem:readJSON(folder.themeFile, nil)
		if type(payload) == "table" then
			local ok, err = self:register(folder.name, decodeFromDisk(payload), "disk")
			if not ok and self.logger then
				self.logger:warn("failed to register disk theme", {
					theme = folder.name,
					error = err,
				})
			end
		end
	end
end

function ThemeManager:get(name)
	local item = self.themes[name]
	if not item then
		return nil
	end
	return cloneDeep(item.data)
end

function ThemeManager:getActiveName()
	return self.activeName
end

function ThemeManager:getActiveTheme()
	if not self.activeName then
		return nil
	end
	return self:get(self.activeName)
end

function ThemeManager:apply(name, overrides)
	local target = self.themes[name]
	if not target then
		return false, ("theme '%s' not found"):format(tostring(name))
	end

	local theme = target.data
	if type(overrides) == "table" then
		theme = mergeDeep(theme, overrides)
	end

	self.activeName = name
	for _, listener in pairs(self.listeners) do
		pcall(listener, name, cloneDeep(theme))
	end
	return true
end

function ThemeManager:onChanged(callback)
	self.nextListenerId = self.nextListenerId + 1
	local id = self.nextListenerId
	self.listeners[id] = callback
	return {
		Disconnect = function()
			self.listeners[id] = nil
		end,
	}
end

function ThemeManager:list()
	local out = {}
	for name, item in pairs(self.themes) do
		table.insert(out, {
			name = name,
			source = item.source,
		})
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

return ThemeManager
