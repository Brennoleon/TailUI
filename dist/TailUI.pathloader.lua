<<<<<<< HEAD
getgenv().TAILUI_REMOTE = {
	user = "Brennoleon",
	repo = "TailUI",
	branch = "main",
	basePath = "src"
}
=======
-- Tail UI Path Loader (Release 2)
-- Focused on modern Roblox executors.
--
-- Usage:
-- getgenv().TAILUI_REMOTE = {
--     user = "Brennoleon",
--     repo = "TailUI",
--     branch = "main",
--     basePath = "src",
--     forceReload = false,
--     debug = false
-- }
-- local TailUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Brennoleon/TailUI/main/dist/TailUI.pathloader.lua"))()
>>>>>>> e8e5cd2 (feat: release 2 executor-first pathloader, ui redesign, keybind/runtime api, docs)

local function readGlobal(name)
	local env = getfenv and getfenv() or _G
	if env and env[name] ~= nil then
		return env[name]
	end
	return _G[name]
end

local function getRootEnv()
	local root = _G
	local getgenvFn = readGlobal("getgenv")
	if type(getgenvFn) == "function" then
		local ok, genv = pcall(getgenvFn)
		if ok and type(genv) == "table" then
			root = genv
		end
	end
	return root
end

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

local function readConfig()
	local root = getRootEnv()
	local configured = root.TAILUI_REMOTE
	if type(configured) ~= "table" then
		configured = {}
	end

	return {
		user = configured.user or "Brennoleon",
		repo = configured.repo or "TailUI",
		branch = configured.branch or "main",
		basePath = configured.basePath or "src",
		rawBaseUrl = configured.rawBaseUrl,
		authToken = configured.authToken,
		cacheModules = configured.cacheModules ~= false,
		forceReload = configured.forceReload == true,
		debug = configured.debug == true,
		modules = deepCopy(configured.modules or {}),
	}
end

local function mergeMaps(base, incoming)
	local out = deepCopy(base)
	for key, value in pairs(incoming or {}) do
		out[key] = value
	end
	return out
end

local DEFAULT_MODULES = {
	["Core.Logger"] = "Core/Logger.lua",
	["Core.SafeCall"] = "Core/SafeCall.lua",
	["Core.FileSystem"] = "Core/FileSystem.lua",
	["Core.ConfigManager"] = "Core/ConfigManager.lua",
	["Theme.BuiltinThemes"] = "Theme/BuiltinThemes.lua",
	["Theme.ThemeManager"] = "Theme/ThemeManager.lua",
	["Assets.IconRegistry"] = "Assets/IconRegistry.lua",
	["Assets.FontRegistry"] = "Assets/FontRegistry.lua",
	["Executor.Runtime"] = "Executor/Runtime.lua",
	["Input.KeybindManager"] = "Input/KeybindManager.lua",
	["UI.FuzzySearch"] = "UI/FuzzySearch.lua",
	["UI.LoadingOverlay"] = "UI/LoadingOverlay.lua",
	["UI.Window"] = "UI/Window.lua",
	["TailUI"] = "TailUI.lua",
}

local CONFIG = readConfig()
local MODULES = mergeMaps(DEFAULT_MODULES, CONFIG.modules)

local function buildUrl(relativePath)
	if type(CONFIG.rawBaseUrl) == "string" and CONFIG.rawBaseUrl ~= "" then
		local trimmed = CONFIG.rawBaseUrl:gsub("/+$", "")
		return trimmed .. "/" .. tostring(relativePath)
	end

	return ("https://raw.githubusercontent.com/%s/%s/%s/%s/%s"):format(
		tostring(CONFIG.user),
		tostring(CONFIG.repo),
		tostring(CONFIG.branch),
		tostring(CONFIG.basePath),
		tostring(relativePath)
	)
end

local function httpGetRaw(url)
	local okHttp, body = pcall(function()
		return game:HttpGet(url)
	end)
	if okHttp and type(body) == "string" and body ~= "" then
		return body
	end

	local requestFn = readGlobal("request")
		or readGlobal("http_request")
		or readGlobal("syn") and readGlobal("syn").request

	if type(requestFn) ~= "function" then
		error("[TailUI Loader] HttpGet failed and no request function available for fallback.", 2)
	end

	local headers = {}
	if type(CONFIG.authToken) == "string" and CONFIG.authToken ~= "" then
		headers.Authorization = "token " .. CONFIG.authToken
	end

	local response = requestFn({
		Url = url,
		Method = "GET",
		Headers = headers,
	})

	if type(response) == "table" then
		local status = response.StatusCode or response.Status
		local responseBody = response.Body
		if tonumber(status) and tonumber(status) >= 200 and tonumber(status) < 300 and type(responseBody) == "string" then
			return responseBody
		end
		error("[TailUI Loader] request fallback failed (" .. tostring(status) .. "): " .. tostring(url), 2)
	end

	error("[TailUI Loader] invalid response from request fallback.", 2)
end

local ROOT = getRootEnv()
ROOT.__TAILUI_MODULE_CACHE = ROOT.__TAILUI_MODULE_CACHE or {}
local CACHE = ROOT.__TAILUI_MODULE_CACHE

if CONFIG.forceReload then
	for key in pairs(CACHE) do
		CACHE[key] = nil
	end
end

local LOCAL_CACHE = {}

local function resolveCache(moduleName)
	if CONFIG.cacheModules then
		return CACHE[moduleName]
	end
	return LOCAL_CACHE[moduleName]
end

local function writeCache(moduleName, value)
	if CONFIG.cacheModules then
		CACHE[moduleName] = value
	else
		LOCAL_CACHE[moduleName] = value
	end
end

local function debugPrint(...)
	if CONFIG.debug then
		print("[TailUI Loader]", ...)
	end
end

local function tailRequire(moduleName)
	local cached = resolveCache(moduleName)
	if cached ~= nil then
		return cached
	end

	local relative = MODULES[moduleName]
	if not relative then
		error("[TailUI Loader] module not mapped: " .. tostring(moduleName), 2)
	end

	local url = buildUrl(relative)
	debugPrint("fetch", moduleName, url)

	local source = httpGetRaw(url)
	local chunk, compileErr = loadstring(source, "@tailui/" .. tostring(moduleName))
	if not chunk then
		error("[TailUI Loader] failed to compile " .. tostring(moduleName) .. ": " .. tostring(compileErr), 2)
	end

	local value = chunk()
	writeCache(moduleName, value)
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

if type(result) == "table" then
	result.__loader = {
		type = "pathloader",
		release = "2.0.0",
		branch = CONFIG.branch,
		basePath = CONFIG.basePath,
		moduleCount = 0,
	}
	local count = 0
	for _ in pairs(MODULES) do
		count = count + 1
	end
	result.__loader.moduleCount = count
end

return result
