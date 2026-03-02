-- Static API style requested by user:
-- Window.tailwindow({ title = \"...\" })

local Window = require(script.Parent.Parent.src.TailUI)

local uiWindow = Window.tailwindow({
	hubName = "StaticHub",
	title = "Static API Hub",
	subtitle = "Window.tailwindow style",
	searchEnabled = true,
	forceDarkOnFullscreen = true,
})

local tab = uiWindow:addTab({
	title = "Main",
	icon = "settings",
})

local section = tab:addSection({
	title = "Static API Example",
	description = "This uses TailUI singleton behind the scenes.",
})

section:addLabel({
	text = "Window.tailwindow(...) is active.",
	description = "You can keep using the same window API.",
})
