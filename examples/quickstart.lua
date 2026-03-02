-- Example usage for Tail UI Library.
-- In Roblox Studio as ModuleScript, update require path as needed.

local TailUI = require(script.Parent.Parent.src.TailUI)

local ui = TailUI.getSingleton({
	hubName = "MeuHub",
})

local window = ui:tailwindow({
	title = "Meu Hub",
	subtitle = "Tail UI - Executor Runtime",
	searchEnabled = true,
	forceDarkOnFullscreen = true,
	transparency = 0.08,
	loading = {
		enabled = true,
		title = "Tail UI v2",
		subtitle = "Boot sequence",
		icon = "*",
	},
})

window:addTag({
	icon = "theme",
	text = "BETA",
	width = 90,
})

window:addTag({
	icon = "save",
	text = "AUTO SAVE",
	width = 120,
})

local mainTab = window:addTab({
	id = "main",
	title = "Main",
	icon = "settings",
})

local controls = mainTab:addSection({
	title = "Core Settings",
	description = "All callbacks are isolated with pcall wrappers.",
})

controls:addToggle({
	title = "Auto Farm",
	default = false,
	callback = function(state)
		print("Auto Farm:", state)
	end,
})

controls:addKeybind({
	title = "Panic Key",
	set = "global",
	key = Enum.KeyCode.End,
	callback = function()
		print("Panic pressed")
	end,
})

controls:addSlider({
	title = "Walk Speed",
	min = 16,
	max = 120,
	step = 1,
	default = 25,
	callback = function(value)
		print("Walk Speed:", value)
	end,
})

controls:addDropdown({
	title = "Target Team",
	options = { "Alpha", "Bravo", "Charlie" },
	default = "Alpha",
	callback = function(option)
		print("Target Team:", option)
	end,
})

controls:addInput({
	title = "Webhook URL",
	placeholder = "https://...",
	callback = function(text)
		print("Webhook saved:", text)
	end,
})

controls:addButton({
	title = "Run Action",
	text = "Execute",
	callback = function()
		print("Action executed")
	end,
})

local themesTab = window:addTab({
	id = "themes",
	title = "Themes",
	icon = "theme",
})

local themeFolder = themesTab:addFolder({
	title = "Theme Manager",
	description = "Create and apply dynamic themes at runtime.",
})

themeFolder:addButton({
	title = "Apply Carbon Night",
	text = "Apply",
	callback = function()
		ui:applyTheme("carbon-night")
	end,
})

themeFolder:addButton({
	title = "Create Custom Theme",
	text = "Create",
	callback = function()
		local customTheme = {
			meta = { name = "MyCustom", author = "User" },
			colors = {
				background = Color3.fromRGB(10, 13, 18),
				surface = Color3.fromRGB(16, 19, 25),
				topbar = Color3.fromRGB(8, 10, 14),
				sidebar = Color3.fromRGB(9, 12, 16),
				text = Color3.fromRGB(232, 241, 252),
				textMuted = Color3.fromRGB(132, 147, 171),
				border = Color3.fromRGB(36, 48, 66),
				accent = Color3.fromRGB(42, 161, 255),
				success = Color3.fromRGB(54, 170, 122),
				warning = Color3.fromRGB(242, 179, 64),
				danger = Color3.fromRGB(220, 90, 92),
				searchHighlight = Color3.fromRGB(80, 145, 255),
				overlay = Color3.fromRGB(6, 8, 12),
			},
			rounding = {
				window = 16,
				card = 12,
				pill = 999,
			},
		}

		ui:registerTheme("my-custom", customTheme, { persist = true })
		ui:applyTheme("my-custom")
	end,
})

local storageTab = window:addTab({
	id = "storage",
	title = "Storage",
	icon = "folder",
})

local files = storageTab:addSection({
	title = "Storage API",
	description = "writefile/readfile/makefolder wrappers",
})

files:addButton({
	title = "Save Profile",
	text = "Save",
	callback = function()
		ui:makeFolder(ui:getHubRoot() .. "/profiles")
		ui:writeJSON(ui:getHubRoot() .. "/profiles/default.json", {
			lastTheme = ui:getConfig("theme.active"),
			version = ui:getConfig("internal.version"),
		})
	end,
})

files:addButton({
	title = "Load Profile",
	text = "Load",
	callback = function()
		local data = ui:readJSON(ui:getHubRoot() .. "/profiles/default.json", {})
		print("Profile data:", data)
	end,
})
