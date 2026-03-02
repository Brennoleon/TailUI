local DEFAULT_FONTS = {
	["ui-sans"] = Enum.Font.Gotham,
	["ui-sans-semibold"] = Enum.Font.GothamSemibold,
	["ui-mono"] = Enum.Font.Code,
	["ui-serif"] = Enum.Font.SourceSans,
	["ui-display"] = Enum.Font.SourceSansBold,
}

local FontRegistry = {}
FontRegistry.__index = FontRegistry

function FontRegistry.new(logger)
	local self = setmetatable({}, FontRegistry)
	self.logger = logger
	self.maxExternalFonts = 5
	self.externalCount = 0
	self.fonts = {}
	for name, font in pairs(DEFAULT_FONTS) do
		self.fonts[name] = font
	end
	return self
end

function FontRegistry:register(name, fontEnum)
	name = tostring(name or "")
	if name == "" then
		return false, "font name cannot be empty"
	end

	if self.fonts[name] == nil and self.externalCount >= self.maxExternalFonts then
		return false, "max external fonts reached (5)"
	end

	if typeof(fontEnum) ~= "EnumItem" or fontEnum.EnumType ~= Enum.Font then
		return false, "font must be Enum.Font"
	end

	if self.fonts[name] == nil then
		self.externalCount = self.externalCount + 1
	end
	self.fonts[name] = fontEnum
	return true
end

function FontRegistry:resolve(name, fallback)
	local font = self.fonts[name]
	if font then
		return font
	end
	if fallback and self.fonts[fallback] then
		return self.fonts[fallback]
	end
	return self.fonts["ui-sans"]
end

function FontRegistry:list()
	local out = {}
	for name in pairs(self.fonts) do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

return FontRegistry
