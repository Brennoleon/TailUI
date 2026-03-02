local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- here is main file <3
local function readGlobal(name)
	local env = getfenv and getfenv() or _G
	if env and env[name] ~= nil then
		return env[name]
	end
	return _G[name]
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
	local configured = _G.TAILUI_REMOTE
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
		showBootLoader = configured.showBootLoader ~= false,
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

local function pickGuiParent()
	local gethui = readGlobal("gethui")
	if type(gethui) == "function" then
		local ok, parent = pcall(gethui)
		if ok and typeof(parent) == "Instance" then
			return parent
		end
	end

	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
	end

	return CoreGui
end

local function createBootLoader()
	if CONFIG.showBootLoader == false then
		return nil
	end

	local ok, result = pcall(function()
		local parent = pickGuiParent()

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "TailUI_BootLoader"
		screenGui.ResetOnSpawn = false
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = parent

		local backdrop = Instance.new("Frame")
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.BackgroundColor3 = Color3.fromRGB(7, 9, 13)
		backdrop.BorderSizePixel = 0
		backdrop.Parent = screenGui
		backdrop.ZIndex = 2000

		local panel = Instance.new("Frame")
		panel.Size = UDim2.fromOffset(420, 108)
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.BorderSizePixel = 0
		panel.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
		panel.Parent = backdrop
		panel.ZIndex = 2001

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = panel

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(35, 45, 60)
		stroke.Transparency = 0.1
		stroke.Parent = panel

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(18, 14)
		title.Size = UDim2.new(1, -36, 0, 20)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Font = Enum.Font.GothamSemibold
		title.TextSize = 15
		title.TextColor3 = Color3.fromRGB(234, 240, 248)
		title.Text = "Tail UI"
		title.Parent = panel
		title.ZIndex = 2002

		local status = Instance.new("TextLabel")
		status.BackgroundTransparency = 1
		status.Position = UDim2.fromOffset(18, 36)
		status.Size = UDim2.new(1, -36, 0, 18)
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.Font = Enum.Font.Gotham
		status.TextSize = 12
		status.TextColor3 = Color3.fromRGB(148, 160, 179)
		status.Text = "Bootstrapping modules..."
		status.Parent = panel
		status.ZIndex = 2002

		local progress = Instance.new("Frame")
		progress.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
		progress.BorderSizePixel = 0
		progress.Position = UDim2.fromOffset(18, 68)
		progress.Size = UDim2.new(1, -36, 0, 8)
		progress.Parent = panel
		progress.ZIndex = 2002

		local progressCorner = Instance.new("UICorner")
		progressCorner.CornerRadius = UDim.new(1, 0)
		progressCorner.Parent = progress

		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.fromRGB(43, 150, 255)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.Parent = progress
		fill.ZIndex = 2003

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.Position = UDim2.fromOffset(18, 82)
		hint.Size = UDim2.new(1, -36, 0, 16)
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.Font = Enum.Font.Gotham
		hint.TextSize = 11
		hint.TextColor3 = Color3.fromRGB(112, 125, 146)
		hint.Text = "Executor mode"
		hint.Parent = panel
		hint.ZIndex = 2002

		local animTime = 0
		local animConnection = RunService.Heartbeat:Connect(function(dt)
			animTime = animTime + dt
			local pulse = 0.1 + math.abs(math.sin(animTime * 1.8)) * 0.18
			stroke.Transparency = pulse
		end)

		local api = {}

		function api:update(progressValue, message, detail)
			if message then
				status.Text = tostring(message)
			end
			if detail then
				hint.Text = tostring(detail)
			end
			local amount = math.clamp(tonumber(progressValue) or 0, 0, 1)
			fill.Size = UDim2.new(amount, 0, 1, 0)
		end

		function api:destroy()
			if animConnection then
				animConnection:Disconnect()
				animConnection = nil
			end
			if screenGui then
				screenGui:Destroy()
			end
		end

		return api
	end)

	if ok then
		return result
	end
	return nil
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
		or readGlobal("Request")
		or (type(readGlobal("syn")) == "table" and readGlobal("syn").request)

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

_G.__TAILUI_MODULE_CACHE = _G.__TAILUI_MODULE_CACHE or {}
local CACHE = _G.__TAILUI_MODULE_CACHE

if CONFIG.forceReload then
	for key in pairs(CACHE) do
		CACHE[key] = nil
	end
end

local LOCAL_CACHE = {}
local BOOT = createBootLoader()
local MODULE_TOTAL = 0
for _ in pairs(MODULES) do
	MODULE_TOTAL = MODULE_TOTAL + 1
end
local moduleProgress = 0

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

local function updateBoot(moduleName)
	if not BOOT then
		return
	end
	local ratio = moduleProgress / math.max(MODULE_TOTAL, 1)
	BOOT:update(ratio, "Loading " .. tostring(moduleName), "Module " .. tostring(moduleProgress) .. "/" .. tostring(MODULE_TOTAL))
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
	updateBoot(moduleName)

	local source = httpGetRaw(url)
	local chunk, compileErr = loadstring(source, "@tailui/" .. tostring(moduleName))
	if not chunk then
		error("[TailUI Loader] failed to compile " .. tostring(moduleName) .. ": " .. tostring(compileErr), 2)
	end

	local value = chunk()
	writeCache(moduleName, value)
	moduleProgress = moduleProgress + 1
	updateBoot(moduleName)
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

if BOOT then
	if ok then
		BOOT:update(1, "Tail UI ready", "Boot complete")
		task.delay(0.15, function()
			BOOT:destroy()
		end)
	else
		BOOT:update(1, "Tail UI failed", "Check executor console")
		task.delay(0.45, function()
			BOOT:destroy()
		end)
	end
end

if not ok then
	error(result, 0)
end

if type(result) == "table" then
	result.__loader = {
		type = "pathloader",
		release = "2.1.0",
		branch = CONFIG.branch,
		basePath = CONFIG.basePath,
		moduleCount = MODULE_TOTAL,
	}
end

return result
