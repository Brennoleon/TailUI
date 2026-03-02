-- Example usage for Tail UI Library.
-- In Roblox Studio as ModuleScript, update require path as needed.

local TailUI = require(script.Parent.Parent.src.TailUI)

local ui = TailUI.getSingleton({
	hubName = "MeuHub",
})

local window = ui:tailwindow({
	title = "Meu Hub",
	subtitle = "Tail UI - Safari Architecture",
	searchEnabled = true,
	loading = {
		enabled = true,
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
	title = "Apply Safari Sunrise",
	text = "Apply",
	callback = function()
		ui:applyTheme("safari-sunrise")
	end,
})

themeFolder:addButton({
	title = "Create Custom Theme",
	text = "Create",
	callback = function()
		local customTheme = {
			meta = { name = "MyCustom", author = "User" },
			colors = {
				background = Color3.fromRGB(228, 234, 241),
				surface = Color3.fromRGB(245, 249, 255),
				topbar = Color3.fromRGB(220, 228, 238),
				text = Color3.fromRGB(29, 40, 53),
				textMuted = Color3.fromRGB(90, 107, 128),
				border = Color3.fromRGB(179, 194, 214),
				accent = Color3.fromRGB(52, 120, 245),
				success = Color3.fromRGB(54, 170, 122),
				warning = Color3.fromRGB(242, 179, 64),
				danger = Color3.fromRGB(220, 90, 92),
				searchHighlight = Color3.fromRGB(80, 145, 255),
			},
			rounding = {
				window = 14,
				card = 10,
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
