local DEFAULT_LUCIDE = {
	search = "S",
	settings = "G",
	close = "X",
	minimize = "-",
	maximize = "+",
	tag = "#",
	folder = "F",
	save = "SV",
	theme = "T",
	loading = "~",
	warning = "!",
	success = "OK",
	error = "X",
	home = "H",
	combat = "C",
	debug = "D",
}

local DEFAULT_MACOS = {
	search = "S",
	settings = "SG",
	close = "X",
	minimize = "-",
	maximize = "+",
	tag = "TG",
	folder = "FD",
	save = "SD",
	theme = "TH",
	loading = "..",
	warning = "!",
	success = "OK",
	error = "X",
	home = "HM",
	combat = "CB",
	debug = "DB",
}

local ICON_COLOR_PATH = {
	search = "colors.textMuted",
	settings = "colors.accent",
	close = "colors.danger",
	minimize = "colors.warning",
	maximize = "colors.success",
	tag = "colors.textMuted",
	folder = "colors.accent",
	save = "colors.success",
	theme = "colors.warning",
	loading = "colors.accent",
	warning = "colors.warning",
	success = "colors.success",
	error = "colors.danger",
	home = "colors.accent",
	combat = "colors.danger",
	debug = "colors.warning",
}

local IconRegistry = {}
IconRegistry.__index = IconRegistry

local function token(theme, path)
	local current = theme
	for part in tostring(path):gmatch("[^%.]+") do
		if type(current) ~= "table" then
			return nil
		end
		current = current[part]
	end
	return current
end

function IconRegistry.new(logger)
	local self = setmetatable({}, IconRegistry)
	self.logger = logger
	self.maxExternalLibraries = 5
	self.externalCount = 0
	self.preferredLibraries = { "macos", "lucide" }
	self.libraries = {
		lucide = DEFAULT_LUCIDE,
		macos = DEFAULT_MACOS,
	}
	return self
end

function IconRegistry:setPreferredLibraries(libraries)
	if type(libraries) ~= "table" then
		return
	end
	self.preferredLibraries = libraries
end

function IconRegistry:registerLibrary(name, provider)
	name = tostring(name or "")
	if name == "" or name == "lucide" or name == "macos" then
		return false, "library name is invalid or reserved"
	end
	if self.libraries[name] == nil and self.externalCount >= self.maxExternalLibraries then
		return false, "max icon libraries reached (5 external + builtins)"
	end
	if type(provider) ~= "table" and type(provider) ~= "function" then
		return false, "icon provider must be table or function"
	end

	if self.libraries[name] == nil then
		self.externalCount = self.externalCount + 1
	end
	self.libraries[name] = provider
	return true
end

local function resolveFromProvider(provider, iconName)
	if type(provider) == "table" then
		return provider[iconName]
	end
	if type(provider) == "function" then
		return provider(iconName)
	end
	return nil
end

function IconRegistry:resolve(iconName, options)
	options = options or {}
	local libraries = options.libraries or self.preferredLibraries

	for _, libName in ipairs(libraries) do
		local provider = self.libraries[libName]
		local icon = resolveFromProvider(provider, iconName)
		if icon ~= nil then
			return icon
		end
	end

	local fallbackProvider = self.libraries.macos or self.libraries.lucide
	local fallback = resolveFromProvider(fallbackProvider, iconName)
	if fallback ~= nil then
		return fallback
	end

	return options.fallback or "*"
end

function IconRegistry:resolveColor(iconName, theme, fallback)
	local path = ICON_COLOR_PATH[tostring(iconName or "")]
	if not path then
		return fallback
	end
	return token(theme, path) or fallback
end

function IconRegistry:listLibraries()
	local out = {}
	for name in pairs(self.libraries) do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

return IconRegistry
