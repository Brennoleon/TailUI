local DEFAULT_LUCIDE = {
	search = "🔎",
	settings = "⚙",
	close = "●",
	minimize = "◌",
	maximize = "◍",
	tag = "🏷",
	folder = "📁",
	save = "💾",
	theme = "🎨",
	loading = "⌛",
	warning = "⚠",
	success = "✓",
	error = "✕",
}

local IconRegistry = {}
IconRegistry.__index = IconRegistry

function IconRegistry.new(logger)
	local self = setmetatable({}, IconRegistry)
	self.logger = logger
	self.maxExternalLibraries = 5
	self.externalCount = 0
	self.preferredLibraries = { "lucide" }
	self.libraries = {
		lucide = DEFAULT_LUCIDE,
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
	if name == "" or name == "lucide" then
		return false, "library name is invalid or reserved"
	end
	if self.libraries[name] == nil and self.externalCount >= self.maxExternalLibraries then
		return false, "max icon libraries reached (5 external + lucide)"
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

	local fallbackProvider = self.libraries.lucide
	local fallback = resolveFromProvider(fallbackProvider, iconName)
	if fallback ~= nil then
		return fallback
	end

	return options.fallback or "•"
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
