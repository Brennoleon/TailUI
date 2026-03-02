-- TailUI v2 full executor test script.
-- Edit TAILUI_REMOTE fields for your repository before running.

getgenv().TAILUI_REMOTE = {
	user = "Brennoleon",
	repo = "TailUI",
	branch = "main",
	basePath = "src",
	forceReload = true,
	debug = false,
	-- authToken = "ghp_xxx", -- optional for private repo
}

local TailUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Brennoleon/TailUI/main/dist/TailUI.pathloader.lua"))()

local ui = TailUI.getSingleton({
	hubName = "TailUI-FullTest",
})

local runtime = ui:getRuntimeInfo()
print("[TailUI] Executor:", runtime.executor)

ui:createKeybindSet("combat")
ui:createKeybindSet("utility")
ui:activateKeybindSet("combat")

local window = ui:tailwindow({
	title = "Tail UI",
	subtitle = "Release 2 | Full Executor Test",
	searchEnabled = true,
	draggable = true,
	resizable = true,
	forceDarkOnFullscreen = true,
	fullscreenDarkTheme = "midnight-pro",
	transparency = 0.08,
	loading = {
		enabled = true,
		title = "Tail UI v2",
		subtitle = "Loading complete API test...",
		icon = "*",
		detail = "Booting modules",
	},
})

window:setSearchPlaceholder("Search controls, tabs and settings...")
window:setSidebarWidth(190, 150)
window:setTransparency(0.08)
window:setFullscreenDarkTheme("midnight-pro")

window:addTag({
	icon = "theme",
	text = "DARK",
	width = 82,
})

window:addTag({
	icon = "settings",
	text = runtime.executor,
	width = 148,
})

window:runLoadingSequence({
	"Runtime",
	"Theme registry",
	"Window systems",
	"Controls",
	"Ready",
})

local mainTab = window:addTab({
	id = "main",
	title = "Overview",
	icon = "folder",
})

local main = mainTab:addSection({
	title = "Core Controls",
	description = "General test of all primary widgets.",
})

local infoLabel = main:addLabel({
	text = "Tail UI full test active.",
	description = "Use search to find any control quickly.",
})

main:addButton({
	title = "Reload Loading Overlay",
	text = "Run",
	callback = function()
		window:runLoadingSequence({
			"Validating",
			"Applying",
			"Finalizing",
		})
	end,
})

local autofarmToggle = main:addToggle({
	title = "Auto Farm",
	default = false,
	callback = function(state)
		print("[TailUI] Auto Farm:", state)
		infoLabel:SetDescription("Auto Farm = " .. tostring(state))
	end,
})

local speedSlider = main:addSlider({
	title = "Walk Speed",
	min = 16,
	max = 200,
	step = 1,
	default = 24,
	callback = function(value)
		local humanoid = game.Players.LocalPlayer
			and game.Players.LocalPlayer.Character
			and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value
		end
	end,
})

main:addInput({
	title = "Player Name",
	placeholder = "Type name...",
	callback = function(text)
		print("[TailUI] Input:", text)
	end,
})

main:addDropdown({
	title = "Target Team",
	options = { "Alpha", "Bravo", "Charlie", "Delta" },
	default = "Alpha",
	callback = function(option)
		print("[TailUI] Team:", option)
	end,
})

main:addSpacer(4)

main:addKeybind({
	title = "Panic (Global)",
	set = "global",
	key = Enum.KeyCode.End,
	callback = function()
		autofarmToggle:Set(false)
		speedSlider:Set(16)
		print("[TailUI] Panic: reset core toggles")
	end,
})

local combatTab = window:addTab({
	id = "combat",
	title = "Combat",
	icon = "settings",
})

local combat = combatTab:addSection({
	title = "Combat Systems",
	description = "Keybind sets + action controls.",
})

combat:addButton({
	title = "Activate Combat Set",
	text = "Enable",
	callback = function()
		ui:activateKeybindSet("combat")
		print("[TailUI] Active keybind set: combat")
	end,
})

combat:addButton({
	title = "Activate Utility Set",
	text = "Enable",
	callback = function()
		ui:activateKeybindSet("utility")
		print("[TailUI] Active keybind set: utility")
	end,
})

combat:addKeybind({
	title = "Dash",
	set = "combat",
	key = Enum.KeyCode.Q,
	callback = function()
		print("[TailUI] Dash triggered")
	end,
})

combat:addKeybind({
	title = "Parry",
	set = "combat",
	key = Enum.KeyCode.F,
	callback = function()
		print("[TailUI] Parry triggered")
	end,
})

local utilityFolder = combatTab:addFolder({
	title = "Utility Folder",
	description = "Collapsible controls for utility actions.",
})

utilityFolder:addToggle({
	title = "ESP",
	default = false,
	callback = function(state)
		print("[TailUI] ESP:", state)
	end,
})

utilityFolder:addKeybind({
	title = "Toggle UI",
	set = "utility",
	key = Enum.KeyCode.RightShift,
	callback = function()
		window:setMinimized(not window.minimized)
	end,
})

local themesTab = window:addTab({
	id = "themes",
	title = "Themes",
	icon = "theme",
})

local builtins = themesTab:addSection({
	title = "Dark Themes",
	description = "Built-in and dynamic themes.",
})

builtins:addDropdown({
	title = "Builtin Theme",
	options = ui:listThemes(),
	default = ui:getConfig("theme.active"),
	callback = function(themeName)
		ui:applyTheme(themeName)
	end,
})

builtins:addButton({
	title = "Create Runtime Theme",
	text = "Create",
	callback = function()
		ui:registerTheme("r2-custom", {
			meta = {
				name = "R2 Custom",
				author = "TailUI",
				dark = true,
			},
			colors = {
				background = Color3.fromRGB(8, 11, 16),
				surface = Color3.fromRGB(14, 18, 24),
				topbar = Color3.fromRGB(8, 10, 14),
				sidebar = Color3.fromRGB(10, 13, 18),
				text = Color3.fromRGB(234, 240, 250),
				textMuted = Color3.fromRGB(132, 146, 170),
				border = Color3.fromRGB(33, 45, 62),
				accent = Color3.fromRGB(35, 157, 255),
				success = Color3.fromRGB(74, 204, 147),
				warning = Color3.fromRGB(243, 184, 76),
				danger = Color3.fromRGB(233, 102, 112),
				searchHighlight = Color3.fromRGB(76, 172, 255),
				overlay = Color3.fromRGB(5, 7, 10),
			},
			rounding = {
				window = 18,
				card = 14,
				pill = 999,
			},
		}, { persist = true })

		ui:applyTheme("r2-custom")
	end,
})

local storageTab = window:addTab({
	id = "storage",
	title = "Storage",
	icon = "save",
})

local storage = storageTab:addSection({
	title = "FileSystem API",
	description = "readfile/writefile/makefolder wrappers.",
})

storage:addButton({
	title = "Save Profile",
	text = "Save",
	callback = function()
		local root = ui:getHubRoot()
		ui:makeFolder(root .. "/profiles")
		ui:writeJSON(root .. "/profiles/default.json", {
			version = ui:getVersion(),
			theme = ui:getConfig("theme.active"),
			activeSet = ui:getActiveKeybindSet(),
		})
		print("[TailUI] Profile saved")
	end,
})

storage:addButton({
	title = "Load Profile",
	text = "Load",
	callback = function()
		local root = ui:getHubRoot()
		local data = ui:readJSON(root .. "/profiles/default.json", {})
		print("[TailUI] Loaded profile:", data)
		if data.theme then
			ui:applyTheme(data.theme)
		end
		if data.activeSet then
			ui:activateKeybindSet(data.activeSet)
		end
	end,
})

local debugTab = window:addTab({
	id = "debug",
	title = "Debug",
	icon = "warning",
})

local debugSection = debugTab:addSection({
	title = "Runtime / API",
	description = "Diagnostics and metadata.",
})

debugSection:addButton({
	title = "Print Runtime Info",
	text = "Print",
	callback = function()
		local info = ui:getRuntimeInfo()
		print("[TailUI] Runtime:", info.executor)
		for capability, supported in pairs(info.capabilities) do
			print("[TailUI] capability", capability, supported)
		end
	end,
})

debugSection:addButton({
	title = "Print Config Path",
	text = "Print",
	callback = function()
		local paths = ui:getPaths()
		print("[TailUI] Root:", paths.root)
		print("[TailUI] Config:", paths.config)
	end,
})

debugSection:addButton({
	title = "Simulate Error Isolation",
	text = "Throw",
	callback = function()
		error("Intentional error test for isolation.")
	end,
})

print("[TailUI] Full test script loaded.")

return {
	ui = ui,
	window = window,
}
