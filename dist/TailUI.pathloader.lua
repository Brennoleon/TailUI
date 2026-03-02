-- Tail UI path-based loader for executors.
-- This file loads modules from your GitHub raw paths (src/*) instead of using one giant monolithic bundle.
--
-- Configure before use:
-- getgenv().TAILUI_REMOTE = {
--     user = "SEU_USUARIO",
--     repo = "SEU_REPO",
--     branch = "main",
--     basePath = "src"
-- }

local function readGlobal(name)
	local env = getfenv and getfenv() or _G
	if env and env[name] ~= nil then
		return env[name]
	end
	return _G[name]
end

local function getRemoteConfig()
	local getgenvFn = readGlobal("getgenv")
	local root = _G
	if type(getgenvFn) == "function" then
		local ok, genv = pcall(getgenvFn)
		if ok and type(genv) == "table" then
			root = genv
		end
	end

	local configured = root.TAILUI_REMOTE
	if type(configured) ~= "table" then
		configured = {}
	end

	return {
		user = configured.user or "SEU_USUARIO",
		repo = configured.repo or "SEU_REPO",
		branch = configured.branch or "main",
		basePath = configured.basePath or "src",
	}
end

local config = getRemoteConfig()

local modules = {
	["Core.Logger"] = "Core/Logger.lua",
	["Core.SafeCall"] = "Core/SafeCall.lua",
	["Core.FileSystem"] = "Core/FileSystem.lua",
	["Core.ConfigManager"] = "Core/ConfigManager.lua",
	["Theme.BuiltinThemes"] = "Theme/BuiltinThemes.lua",
	["Theme.ThemeManager"] = "Theme/ThemeManager.lua",
	["Assets.IconRegistry"] = "Assets/IconRegistry.lua",
	["Assets.FontRegistry"] = "Assets/FontRegistry.lua",
	["UI.FuzzySearch"] = "UI/FuzzySearch.lua",
	["UI.LoadingOverlay"] = "UI/LoadingOverlay.lua",
	["UI.Window"] = "UI/Window.lua",
	["TailUI"] = "TailUI.lua",
}

local cache = {}

local function buildUrl(relativePath)
	return ("https://raw.githubusercontent.com/%s/%s/%s/%s/%s"):format(
		tostring(config.user),
		tostring(config.repo),
		tostring(config.branch),
		tostring(config.basePath),
		tostring(relativePath)
	)
end

local function tailRequire(moduleName)
	local cached = cache[moduleName]
	if cached ~= nil then
		return cached
	end

	local relative = modules[moduleName]
	if not relative then
		error("[TailUI Loader] module not mapped: " .. tostring(moduleName), 2)
	end

	local url = buildUrl(relative)
	local source = game:HttpGet(url)
	local chunk, compileErr = loadstring(source, "@tailui/" .. tostring(moduleName))
	if not chunk then
		error("[TailUI Loader] failed to compile " .. tostring(moduleName) .. ": " .. tostring(compileErr), 2)
	end

	local value = chunk()
	cache[moduleName] = value
	return value
end

local oldRequire = _G.__TAILUI_REQUIRE
_G.__TAILUI_REQUIRE = tailRequire

local ok, result = pcall(function()
	return tailRequire("TailUI")
end)

if oldRequire == nil then
	_G.__TAILUI_REQUIRE = nil
else
	_G.__TAILUI_REQUIRE = oldRequire
end

if not ok then
	error(result, 0)
end

return result
