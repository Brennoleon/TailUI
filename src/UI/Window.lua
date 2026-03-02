local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function loadModule(moduleName, fallbackLoader)
	local env = getfenv and getfenv() or _G
	local custom = (env and env.__TAILUI_REQUIRE) or _G.__TAILUI_REQUIRE
	if type(custom) == "function" then
		return custom(moduleName)
	end
	return fallbackLoader()
end

local FuzzySearch = loadModule("UI.FuzzySearch", function()
	return require(script.Parent.FuzzySearch)
end)
local LoadingOverlay = loadModule("UI.LoadingOverlay", function()
	return require(script.Parent.LoadingOverlay)
end)

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local function readGlobal(name)
	local env = getfenv and getfenv() or _G
	if env and env[name] ~= nil then
		return env[name]
	end
	return _G[name]
end

local function pickGuiParent(fallback)
	if typeof(fallback) == "Instance" then
		return fallback
	end

	local gethui = readGlobal("gethui")
	if type(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and typeof(result) == "Instance" then
			return result
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

local function protectExecutorGui(gui, runtime)
	if runtime and type(runtime.protectGui) == "function" then
		local okProtected = runtime:protectGui(gui)
		if okProtected then
			return
		end
	end

	local syn = readGlobal("syn")
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, gui)
		return
	end

	local protectgui = readGlobal("protectgui")
	if type(protectgui) == "function" then
		pcall(protectgui, gui)
	end
end

local function token(theme, path, fallback)
	local current = theme
	for part in tostring(path):gmatch("[^%.]+") do
		if type(current) ~= "table" then
			return fallback
		end
		current = current[part]
	end
	if current == nil then
		return fallback
	end
	return current
end

local function corner(target, radius)
	local object = Instance.new("UICorner")
	object.CornerRadius = UDim.new(0, radius)
	object.Parent = target
	return object
end

local function stroke(target, color, transparency)
	local object = Instance.new("UIStroke")
	object.Thickness = 1
	object.Color = color
	object.Transparency = transparency or 0
	object.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	object.Parent = target
	return object
end

local function clearNonLayoutChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function flatten(values)
	local out = {}
	for _, value in ipairs(values) do
		table.insert(out, tostring(value))
	end
	return out
end

local function setTreeZIndex(root, zIndex)
	if not root then
		return
	end
	if root:IsA("GuiObject") then
		root.ZIndex = zIndex
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("GuiObject") then
			child.ZIndex = zIndex
		end
	end
end

function Window.new(context, options)
	options = options or {}

	local self = setmetatable({}, Window)
	self.context = context
	self.options = options
	self.logger = context.logger
	self.safeCall = context.safeCall
	self.themeManager = context.themeManager
	self.iconRegistry = context.iconRegistry
	self.fontRegistry = context.fontRegistry
	self.keybindManager = context.keybindManager
	self.runtime = context.runtime
	self.config = context.config

	self.connections = {}
	self.themeBindings = {}
	self.tabs = {}
	self.searchEntries = {}
	self.tagIndex = 0
	self.destroyed = false
	self.minimized = false
	self.maximized = false

	self.themeName = options.theme or self.config.theme.active
	self.theme = self.themeManager:get(self.themeName) or self.themeManager:getActiveTheme() or {}
	self.font = self.fontRegistry:resolve(options.font or self.config.fonts.default, "ui-sans")
	self.boldFont = self.fontRegistry:resolve("ui-sans-semibold", "ui-sans")

	if options.searchEnabled == nil then
		self.searchEnabled = self.config.internal.searchEnabled
	else
		self.searchEnabled = options.searchEnabled
	end

	self.topbarHeight = options.topbarHeight or 40
	self.sidebarWidth = options.sidebarWidth or 184
	self.mobileSidebarWidth = options.mobileSidebarWidth or 142
	self.fullscreenDarkTheme = options.fullscreenDarkTheme or "midnight-pro"
	if options.forceDarkOnFullscreen == nil then
		self.forceDarkOnFullscreen = self.config.window.forceDarkOnFullscreen ~= false
	else
		self.forceDarkOnFullscreen = options.forceDarkOnFullscreen == true
	end
	self.themeBeforeFullscreen = nil
	self.uiTransparency = tonumber(options.transparency or self.config.window.defaultTransparency or 0.06) or 0.06

	self:_build()
	self:_watchTheme()
	self:_applyTheme(self.theme)
	self:_applyResponsive()
	self:setSearchEnabled(self.searchEnabled)
	self:setTransparency(self.uiTransparency)

	return self
end

function Window:_connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.connections, connection)
	return connection
end

function Window:_safe(scope, callback, onFailure)
	if type(callback) ~= "function" then
		return function() end
	end

	if self.safeCall then
		return self.safeCall:wrap(scope, callback, onFailure)
	end

	return function(...)
		local ok, err = pcall(callback, ...)
		if not ok then
			if onFailure then
				onFailure(err)
			end
			warn(("[TailUI] callback fail in %s: %s"):format(scope, tostring(err)))
		end
	end
end

function Window:_bindTheme(instance, propertyName, path, fallback)
	table.insert(self.themeBindings, {
		instance = instance,
		property = propertyName,
		path = path,
		fallback = fallback,
	})

	local value = token(self.theme, path, fallback)
	if value ~= nil then
		instance[propertyName] = value
	end
end

function Window:_applyTheme(theme)
	self.theme = theme or self.theme
	for _, item in ipairs(self.themeBindings) do
		if item.instance and item.instance.Parent then
			local value = token(self.theme, item.path, item.fallback)
			if value ~= nil then
				item.instance[item.property] = value
			end
		end
	end

	if self.activeTab then
		self:_activateTab(self.activeTab)
	end

	if self.uiTransparency then
		self:setTransparency(self.uiTransparency)
	end
end

function Window:_watchTheme()
	self.themeConnection = self.themeManager:onChanged(function(name, theme)
		self.themeName = name
		self:_applyTheme(theme)
	end)
end

function Window:_build()
	local parent = pickGuiParent(self.options.parent)
	local windowConfig = self.config.window
	local size = self.options.size or windowConfig.size
	local minimum = self.options.minimumSize or windowConfig.minimumSize

	self.baseSize = Vector2.new(size.width, size.height)
	self.minimumSize = Vector2.new(minimum.width, minimum.height)

	self.screenGui = Instance.new("ScreenGui")
	self.screenGui.Name = "TailUI_ScreenGui"
	self.screenGui.ResetOnSpawn = false
	self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.screenGui.IgnoreGuiInset = true
	self.screenGui.Parent = parent
	protectExecutorGui(self.screenGui, self.runtime)

	local showLoading = self.config.internal.showLoading ~= false
	if self.options.loading and self.options.loading.enabled == false then
		showLoading = false
	end
	if showLoading then
		self.loadingOverlay = LoadingOverlay.new(self.screenGui, self.theme, self.boldFont, self.options.loading)
		self.loadingOverlay:show("Initializing Tail UI...")
		self.loadingOverlay:step(1, 5, "Creating window")
	end

	self.main = Instance.new("Frame")
	self.main.Name = "Main"
	self.main.AnchorPoint = Vector2.new(0.5, 0.5)
	self.main.Position = UDim2.fromScale(0.5, 0.5)
	self.main.Size = UDim2.fromOffset(self.baseSize.X, self.baseSize.Y)
	self.main.ClipsDescendants = true
	self.main.BorderSizePixel = 0
	self.main.Parent = self.screenGui
	corner(self.main, token(self.theme, "rounding.window", 18))
	stroke(self.main, token(self.theme, "colors.border", Color3.fromRGB(170, 176, 188)), 0.15)
	self:_bindTheme(self.main, "BackgroundColor3", "colors.background", Color3.fromRGB(250, 251, 253))

	self.openButton = Instance.new("TextButton")
	self.openButton.Name = "TopMenuOpenButton"
	self.openButton.Size = UDim2.fromOffset(140, 32)
	self.openButton.Position = UDim2.fromOffset(14, 14)
	self.openButton.Font = self.boldFont
	self.openButton.TextSize = 13
	self.openButton.Text = self.iconRegistry:resolve("maximize") .. "  Open"
	self.openButton.BorderSizePixel = 0
	self.openButton.Visible = false
	self.openButton.Parent = self.screenGui
	corner(self.openButton, 12)
	stroke(self.openButton, token(self.theme, "colors.border", Color3.fromRGB(170, 176, 188)), 0.2)
	self:_bindTheme(self.openButton, "BackgroundColor3", "colors.topbar", Color3.fromRGB(230, 235, 240))
	self:_bindTheme(self.openButton, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	if self.loadingOverlay then
		self.loadingOverlay:step(2, 5, "Building topbar")
	end

	self:_buildTopbar()
	self:_buildBody()
	self:_buildErrorLabel()
	self:_bindResizeAndDrag()

	if self.loadingOverlay then
		self.loadingOverlay:step(3, 5, "Binding responsive mode")
	end

	self:_bindViewport()

	if self.loadingOverlay then
		self.loadingOverlay:step(4, 5, "Preparing default tab")
	end

	local home = self:addTab({ id = "home", title = "Home", icon = "folder" })
	home:addLabel({
		text = "Tail UI v2 ready.",
		description = "Dark executor UI loaded. Add tabs, controls, keybinds and themes.",
	})

	if self.loadingOverlay then
		self.loadingOverlay:step(5, 5, "Ready")
		task.wait(0.1)
		self.loadingOverlay:hide()
	end
end

function Window:_buildTopbar()
	self.topbar = Instance.new("Frame")
	self.topbar.Name = "Topbar"
	self.topbar.Size = UDim2.new(1, 0, 0, self.topbarHeight)
	self.topbar.BorderSizePixel = 0
	self.topbar.Parent = self.main
	self:_bindTheme(self.topbar, "BackgroundColor3", "colors.topbar", Color3.fromRGB(230, 235, 240))

	local topbarBorder = Instance.new("Frame")
	topbarBorder.Name = "BottomBorder"
	topbarBorder.Size = UDim2.new(1, 0, 0, 1)
	topbarBorder.Position = UDim2.new(0, 0, 1, -1)
	topbarBorder.BorderSizePixel = 0
	topbarBorder.Parent = self.topbar
	self:_bindTheme(topbarBorder, "BackgroundColor3", "colors.border", Color3.fromRGB(43, 49, 63))

	local circles = Instance.new("Frame")
	circles.Name = "SafariCircles"
	circles.Size = UDim2.fromOffset(82, 16)
	circles.Position = UDim2.fromOffset(12, math.floor((self.topbarHeight - 16) * 0.5))
	circles.BackgroundTransparency = 1
	circles.Parent = self.topbar

	local circlesLayout = Instance.new("UIListLayout")
	circlesLayout.FillDirection = Enum.FillDirection.Horizontal
	circlesLayout.Padding = UDim.new(0, 8)
	circlesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	circlesLayout.Parent = circles

	local function circle(name, color, callback)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(12, 12)
		button.Text = ""
		button.BorderSizePixel = 0
		button.BackgroundColor3 = color
		button.Parent = circles
		corner(button, 99)
		self:_connect(button.MouseButton1Click, self:_safe("topbar." .. name, callback))
	end

	circle("Close", token(self.theme, "colors.danger", Color3.fromRGB(236, 90, 95)), function()
		self:destroy()
	end)
	circle("Minimize", token(self.theme, "colors.warning", Color3.fromRGB(246, 192, 70)), function()
		self:setMinimized(true)
	end)
	circle("Maximize", token(self.theme, "colors.success", Color3.fromRGB(84, 193, 134)), function()
		self:toggleMaximized()
	end)

	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.BackgroundTransparency = 1
	titleBox.Size = UDim2.new(1, -288, 1, 0)
	titleBox.Position = UDim2.fromOffset(108, 0)
	titleBox.Parent = self.topbar

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Position = UDim2.fromOffset(0, 3)
	title.Font = self.boldFont
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = self.options.title or self.config.window.title
	title.Parent = titleBox
	self:_bindTheme(title, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, 0, 0, 14)
	subtitle.Position = UDim2.fromOffset(0, 22)
	subtitle.Font = self.font
	subtitle.TextSize = 11
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = self.options.subtitle or self.config.window.subtitle
	subtitle.Parent = titleBox
	self:_bindTheme(subtitle, "TextColor3", "colors.textMuted", Color3.fromRGB(84, 94, 106))

	self.tagsHost = Instance.new("Frame")
	self.tagsHost.Name = "TagsHost"
	self.tagsHost.BackgroundTransparency = 1
	self.tagsHost.AnchorPoint = Vector2.new(1, 0)
	self.tagsHost.Position = UDim2.new(1, -12, 0, 0)
	self.tagsHost.Size = UDim2.new(0, 196, 1, 0)
	self.tagsHost.Parent = self.topbar

	local tagsLayout = Instance.new("UIListLayout")
	tagsLayout.FillDirection = Enum.FillDirection.Horizontal
	tagsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tagsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tagsLayout.Padding = UDim.new(0, 6)
	tagsLayout.Parent = self.tagsHost

	self:_connect(self.openButton.MouseButton1Click, function()
		self:setMinimized(false)
	end)
end
function Window:_buildBody()
	self.body = Instance.new("Frame")
	self.body.Name = "Body"
	self.body.Size = UDim2.new(1, 0, 1, -self.topbarHeight)
	self.body.Position = UDim2.fromOffset(0, self.topbarHeight)
	self.body.BorderSizePixel = 0
	self.body.BackgroundTransparency = 1
	self.body.Parent = self.main

	self.sidebar = Instance.new("Frame")
	self.sidebar.Name = "Sidebar"
	self.sidebar.Size = UDim2.new(0, self.sidebarWidth, 1, 0)
	self.sidebar.BorderSizePixel = 0
	self.sidebar.Parent = self.body
	self:_bindTheme(self.sidebar, "BackgroundColor3", "colors.sidebar", Color3.fromRGB(12, 14, 18))
	corner(self.sidebar, 14)

	self.sidebarPane = Instance.new("Frame")
	self.sidebarPane.Name = "SidebarPane"
	self.sidebarPane.Size = UDim2.new(1, -10, 1, -10)
	self.sidebarPane.Position = UDim2.fromOffset(5, 5)
	self.sidebarPane.BorderSizePixel = 0
	self.sidebarPane.Parent = self.sidebar
	corner(self.sidebarPane, 12)
	stroke(self.sidebarPane, token(self.theme, "colors.border", Color3.fromRGB(172, 182, 196)), 0.28)
	self:_bindTheme(self.sidebarPane, "BackgroundColor3", "colors.surface", Color3.fromRGB(248, 250, 255))

	self.searchHost = Instance.new("Frame")
	self.searchHost.Name = "SearchHost"
	self.searchHost.Size = UDim2.new(1, -12, 0, 32)
	self.searchHost.Position = UDim2.fromOffset(6, 6)
	self.searchHost.BorderSizePixel = 0
	self.searchHost.Parent = self.sidebarPane
	corner(self.searchHost, 10)
	stroke(self.searchHost, token(self.theme, "colors.border", Color3.fromRGB(172, 182, 196)), 0.28)
	self:_bindTheme(self.searchHost, "BackgroundColor3", "colors.background", Color3.fromRGB(241, 246, 252))
	setTreeZIndex(self.searchHost, 20)

	local searchIcon = Instance.new("TextLabel")
	searchIcon.Name = "Icon"
	searchIcon.BackgroundTransparency = 1
	searchIcon.Size = UDim2.fromOffset(20, 20)
	searchIcon.Position = UDim2.fromOffset(8, 5)
	searchIcon.Font = self.font
	searchIcon.TextSize = 14
	searchIcon.Text = self.iconRegistry:resolve("search")
	searchIcon.Parent = self.searchHost
	self:_bindTheme(searchIcon, "TextColor3", "colors.textMuted", Color3.fromRGB(94, 106, 126))
	searchIcon.ZIndex = 21

	self.searchInput = Instance.new("TextBox")
	self.searchInput.Name = "Input"
	self.searchInput.BackgroundTransparency = 1
	self.searchInput.Size = UDim2.new(1, -34, 1, 0)
	self.searchInput.Position = UDim2.fromOffset(30, 0)
	self.searchInput.Font = self.font
	self.searchInput.TextSize = 13
	self.searchInput.TextXAlignment = Enum.TextXAlignment.Left
	self.searchInput.ClearTextOnFocus = false
	self.searchInput.PlaceholderText = "Search..."
	self.searchInput.Parent = self.searchHost
	self:_bindTheme(self.searchInput, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))
	self:_bindTheme(self.searchInput, "PlaceholderColor3", "colors.textMuted", Color3.fromRGB(94, 106, 126))
	self.searchInput.ZIndex = 21

	self.tabsList = Instance.new("ScrollingFrame")
	self.tabsList.Name = "TabsList"
	self.tabsList.Size = UDim2.new(1, -12, 1, -50)
	self.tabsList.Position = UDim2.fromOffset(6, 44)
	self.tabsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.tabsList.CanvasSize = UDim2.new()
	self.tabsList.ScrollBarThickness = 2
	self.tabsList.BackgroundTransparency = 1
	self.tabsList.BorderSizePixel = 0
	self.tabsList.Parent = self.sidebarPane
	self.tabsList.ZIndex = 10

	local tabsPadding = Instance.new("UIPadding")
	tabsPadding.PaddingBottom = UDim.new(0, 6)
	tabsPadding.Parent = self.tabsList

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.Padding = UDim.new(0, 5)
	tabsLayout.Parent = self.tabsList

	self.content = Instance.new("Frame")
	self.content.Name = "Content"
	self.content.Size = UDim2.new(1, -self.sidebarWidth, 1, 0)
	self.content.Position = UDim2.fromOffset(self.sidebarWidth, 0)
	self.content.BackgroundTransparency = 1
	self.content.BorderSizePixel = 0
	self.content.Parent = self.body

	self.contentPanel = Instance.new("Frame")
	self.contentPanel.Name = "ContentPanel"
	self.contentPanel.Size = UDim2.new(1, -10, 1, -10)
	self.contentPanel.Position = UDim2.fromOffset(5, 5)
	self.contentPanel.BorderSizePixel = 0
	self.contentPanel.Parent = self.content
	corner(self.contentPanel, 14)
	stroke(self.contentPanel, token(self.theme, "colors.border", Color3.fromRGB(43, 49, 63)), 0.24)
	self:_bindTheme(self.contentPanel, "BackgroundColor3", "colors.surface", Color3.fromRGB(17, 20, 26))

	self.searchResults = Instance.new("ScrollingFrame")
	self.searchResults.Name = "SearchResults"
	self.searchResults.Size = UDim2.new(0, self.sidebarWidth - 16, 0, 192)
	self.searchResults.Position = UDim2.fromOffset(8, self.topbarHeight + 36)
	self.searchResults.Visible = false
	self.searchResults.ScrollBarThickness = 2
	self.searchResults.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.searchResults.CanvasSize = UDim2.new()
	self.searchResults.BorderSizePixel = 0
	self.searchResults.Parent = self.screenGui
	corner(self.searchResults, 12)
	stroke(self.searchResults, token(self.theme, "colors.border", Color3.fromRGB(172, 182, 196)), 0.18)
	self:_bindTheme(self.searchResults, "BackgroundColor3", "colors.surface", Color3.fromRGB(248, 250, 255))
	self.searchResults.ZIndex = 60

	local resultPadding = Instance.new("UIPadding")
	resultPadding.PaddingTop = UDim.new(0, 4)
	resultPadding.PaddingBottom = UDim.new(0, 4)
	resultPadding.PaddingLeft = UDim.new(0, 4)
	resultPadding.PaddingRight = UDim.new(0, 4)
	resultPadding.Parent = self.searchResults

	local resultLayout = Instance.new("UIListLayout")
	resultLayout.Padding = UDim.new(0, 4)
	resultLayout.Parent = self.searchResults

	self.pagesHost = Instance.new("Frame")
	self.pagesHost.Name = "PagesHost"
	self.pagesHost.Size = UDim2.new(1, -10, 1, -10)
	self.pagesHost.Position = UDim2.fromOffset(5, 5)
	self.pagesHost.BackgroundTransparency = 1
	self.pagesHost.BorderSizePixel = 0
	self.pagesHost.Parent = self.contentPanel

	self:_connect(self.searchInput:GetPropertyChangedSignal("Text"), function()
		self:_refreshSearch()
	end)

	self:_connect(UserInputService.InputBegan, function(input)
		if not self.searchResults.Visible then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local pos = input.Position
		local function contains(gui)
			local p = gui.AbsolutePosition
			local s = gui.AbsoluteSize
			return pos.X >= p.X and pos.X <= (p.X + s.X) and pos.Y >= p.Y and pos.Y <= (p.Y + s.Y)
		end

		if contains(self.searchHost) or contains(self.searchResults) then
			return
		end

		self.searchResults.Visible = false
	end)

	self:_updateSearchOverlayPosition()
end

function Window:_updateSearchOverlayPosition()
	if not self.searchResults or not self.searchHost then
		return
	end
	local absolute = self.searchHost.AbsolutePosition
	self.searchResults.Position = UDim2.fromOffset(absolute.X, absolute.Y + self.searchHost.AbsoluteSize.Y + 4)
	self.searchResults.Size = UDim2.fromOffset(self.searchHost.AbsoluteSize.X, 192)
end

function Window:_buildErrorLabel()
	self.errorLabel = Instance.new("TextLabel")
	self.errorLabel.Name = "ErrorLabel"
	self.errorLabel.Size = UDim2.new(1, -16, 0, 44)
	self.errorLabel.Position = UDim2.new(0, 8, 1, -52)
	self.errorLabel.Visible = false
	self.errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.errorLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.errorLabel.TextWrapped = true
	self.errorLabel.Font = self.font
	self.errorLabel.TextSize = 12
	self.errorLabel.BorderSizePixel = 0
	self.errorLabel.Parent = self.contentPanel
	corner(self.errorLabel, 9)
	self.errorLabel.ZIndex = 30
	self:_bindTheme(self.errorLabel, "TextColor3", "colors.danger", Color3.fromRGB(231, 95, 95))
	self:_bindTheme(self.errorLabel, "BackgroundColor3", "colors.background", Color3.fromRGB(246, 238, 238))
end

function Window:_bindResizeAndDrag()
	local dragEnabled = self.options.draggable
	if dragEnabled == nil then
		dragEnabled = self.config.window.draggable
	end

	local resizeEnabled = self.options.resizable
	if resizeEnabled == nil then
		resizeEnabled = self.config.window.resizable
	end

	if dragEnabled then
		local dragging = false
		local dragStart = Vector2.zero
		local startPos = self.main.Position

		self:_connect(self.topbar.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = self.main.Position
			end
		end)

		self:_connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		self:_connect(UserInputService.InputChanged, function(input)
			if not dragging or self.maximized then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local delta = input.Position - dragStart
			self.main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
			self:_updateSearchOverlayPosition()
		end)
	end

	local openDragging = false
	local openDragStart = Vector2.zero
	local openStartPos = self.openButton.Position

	self:_connect(self.openButton.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			openDragging = true
			openDragStart = input.Position
			openStartPos = self.openButton.Position
		end
	end)

	self:_connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			openDragging = false
		end
	end)

	self:_connect(UserInputService.InputChanged, function(input)
		if not openDragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - openDragStart
		self.openButton.Position = UDim2.new(
			openStartPos.X.Scale,
			openStartPos.X.Offset + delta.X,
			openStartPos.Y.Scale,
			openStartPos.Y.Offset + delta.Y
		)
	end)

	if resizeEnabled then
		self.resizeHandle = Instance.new("Frame")
		self.resizeHandle.Name = "ResizeHandle"
		self.resizeHandle.AnchorPoint = Vector2.new(1, 1)
		self.resizeHandle.Size = UDim2.fromOffset(17, 17)
		self.resizeHandle.Position = UDim2.new(1, -4, 1, -4)
		self.resizeHandle.BorderSizePixel = 0
		self.resizeHandle.Parent = self.main
		corner(self.resizeHandle, 10)
		self:_bindTheme(self.resizeHandle, "BackgroundColor3", "colors.topbar", Color3.fromRGB(230, 235, 240))

		local resizing = false
		local startMouse = Vector2.zero
		local startSize = Vector2.zero

		self:_connect(self.resizeHandle.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				startMouse = input.Position
				startSize = self.main.AbsoluteSize
			end
		end)

		self:_connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
			end
		end)

		self:_connect(UserInputService.InputChanged, function(input)
			if not resizing or self.maximized then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local delta = input.Position - startMouse
			local width = math.max(self.minimumSize.X, startSize.X + delta.X)
			local height = math.max(self.minimumSize.Y, startSize.Y + delta.Y)
			self.baseSize = Vector2.new(width, height)
			self.main.Size = UDim2.fromOffset(width, height)
			self:_updateSearchOverlayPosition()
		end)
	end
end

function Window:_bindViewport()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	self:_connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
		self:_applyResponsive()
	end)
end

function Window:_applyResponsive()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local breakpoint = self.config.internal.mobileBreakpoint or 840
	local mobile = viewport.X <= breakpoint

	if self.maximized then
		self.main.AnchorPoint = Vector2.zero
		self.main.Position = UDim2.new(0, 8, 0, 8)
		self.main.Size = UDim2.new(1, -16, 1, -16)
		self.sidebar.Size = UDim2.new(0, self.sidebarWidth, 1, 0)
		self.content.Position = UDim2.fromOffset(self.sidebarWidth, 0)
		self.content.Size = UDim2.new(1, -self.sidebarWidth, 1, 0)
		self:_updateSearchOverlayPosition()
		return
	end

	if mobile then
		self.main.AnchorPoint = Vector2.zero
		self.main.Position = UDim2.new(0, 8, 0, 8)
		self.main.Size = UDim2.new(1, -16, 1, -16)
		self.sidebar.Size = UDim2.new(0, self.mobileSidebarWidth, 1, 0)
		self.content.Position = UDim2.fromOffset(self.mobileSidebarWidth, 0)
		self.content.Size = UDim2.new(1, -self.mobileSidebarWidth, 1, 0)
	else
		self.main.AnchorPoint = Vector2.new(0.5, 0.5)
		self.main.Position = UDim2.fromScale(0.5, 0.5)
		self.main.Size = UDim2.fromOffset(self.baseSize.X, self.baseSize.Y)
		self.sidebar.Size = UDim2.new(0, self.sidebarWidth, 1, 0)
		self.content.Position = UDim2.fromOffset(self.sidebarWidth, 0)
		self.content.Size = UDim2.new(1, -self.sidebarWidth, 1, 0)
	end

	self:_updateSearchOverlayPosition()
end

function Window:setMinimized(minimized)
	self.minimized = minimized == true
	self.main.Visible = not self.minimized
	self.openButton.Visible = self.minimized
	if self.minimized then
		self.searchResults.Visible = false
	else
		self:_updateSearchOverlayPosition()
	end
end

function Window:toggleMaximized()
	self.maximized = not self.maximized

	if self.forceDarkOnFullscreen then
		if self.maximized then
			local activeName = self.themeManager:getActiveName()
			if activeName ~= self.fullscreenDarkTheme then
				self.themeBeforeFullscreen = activeName
				self:applyTheme(self.fullscreenDarkTheme)
			end
		elseif self.themeBeforeFullscreen then
			self:applyTheme(self.themeBeforeFullscreen)
			self.themeBeforeFullscreen = nil
		end
	end

	self:_applyResponsive()
end

function Window:setSearchEnabled(enabled)
	self.searchEnabled = enabled == true
	self.searchHost.Visible = self.searchEnabled

	if self.searchEnabled then
		self.tabsList.Size = UDim2.new(1, -12, 1, -50)
		self.tabsList.Position = UDim2.fromOffset(6, 44)
	else
		self.tabsList.Size = UDim2.new(1, -12, 1, -12)
		self.tabsList.Position = UDim2.fromOffset(6, 6)
		self.searchResults.Visible = false
		self.searchInput.Text = ""
	end

	self:_updateSearchOverlayPosition()
end

function Window:setFullscreenDarkTheme(themeName)
	self.fullscreenDarkTheme = tostring(themeName or "midnight-pro")
end

function Window:setTransparency(value)
	local amount = tonumber(value) or 0
	amount = math.clamp(amount, 0, 0.88)
	self.uiTransparency = amount

	local function apply(instance, base)
		if instance then
			instance.BackgroundTransparency = math.clamp((base or 0) + amount, 0, 0.97)
		end
	end

	apply(self.main, 0)
	apply(self.topbar, 0)
	apply(self.sidebar, 0)
	apply(self.sidebarPane, 0)
	apply(self.searchHost, 0)
	apply(self.searchResults, 0)
	apply(self.contentPanel, 0)
end

function Window:setOpacity(value)
	self:setTransparency(value)
end

function Window:setSearchPlaceholder(text)
	if self.searchInput then
		self.searchInput.PlaceholderText = tostring(text or "Search...")
	end
end

function Window:setSidebarWidth(width, mobileWidth)
	local nextWidth = tonumber(width)
	if nextWidth then
		self.sidebarWidth = math.clamp(nextWidth, 140, 320)
	end
	local nextMobile = tonumber(mobileWidth)
	if nextMobile then
		self.mobileSidebarWidth = math.clamp(nextMobile, 120, 260)
	end
	self:_applyResponsive()
end

function Window:reportError(scope, message)
	local text = tostring(message)
	if #text > 260 then
		text = text:sub(1, 257) .. "..."
	end
	self.errorLabel.Text = ("[TailUI Error] %s\n%s"):format(tostring(scope), text)
	self.errorLabel.Visible = true

	local ticket = os.clock()
	self.errorTicket = ticket
	task.delay(10, function()
		if self.destroyed then
			return
		end
		if self.errorTicket == ticket then
			self.errorLabel.Visible = false
		end
	end)
end

function Window:_registerSearch(entry)
	entry.id = entry.id or tostring(#self.searchEntries + 1)
	table.insert(self.searchEntries, entry)
end

function Window:_renderSearchResults(results)
	clearNonLayoutChildren(self.searchResults)
	for _, row in ipairs(results) do
		local entry = row.entry
		local button = Instance.new("TextButton")
		button.Name = "SearchResult"
		button.Size = UDim2.new(1, 0, 0, 31)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextSize = 13
		button.Font = self.font
		button.AutoButtonColor = true
		button.BorderSizePixel = 0
		button.Text = ("  %s %s [%s]"):format(
			self.iconRegistry:resolve(entry.icon or "search"),
			entry.title or "Item",
			entry.kind or "item"
		)
		button.Parent = self.searchResults
		corner(button, 9)
		button.ZIndex = 61
		self:_bindTheme(button, "BackgroundColor3", "colors.background", Color3.fromRGB(241, 246, 252))
		self:_bindTheme(button, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

		self:_connect(button.MouseButton1Click, function()
			if entry.onSelect then
				self:_safe("search.select." .. tostring(entry.id), entry.onSelect)()
			end
			self.searchInput.Text = ""
			self.searchResults.Visible = false
		end)
	end
end

function Window:_refreshSearch()
	if not self.searchEnabled then
		self.searchResults.Visible = false
		return
	end

	local query = self.searchInput.Text
	if query == "" then
		self.searchResults.Visible = false
		return
	end

	local results = FuzzySearch.search(query, self.searchEntries, 15)
	self:_updateSearchOverlayPosition()
	self:_renderSearchResults(results)
	self.searchResults.Visible = #results > 0
end

function Window:_focus(frame)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	local original = frame.BackgroundColor3
	local accent = token(self.theme, "colors.searchHighlight", Color3.fromRGB(95, 154, 255))
	local tweenIn = TweenService:Create(frame, TweenInfo.new(0.12), { BackgroundColor3 = accent })
	local tweenOut = TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundColor3 = original })
	tweenIn:Play()
	tweenIn.Completed:Wait()
	tweenOut:Play()
end

function Window:addTag(tagOptions)
	tagOptions = tagOptions or {}
	self.tagIndex = self.tagIndex + 1

	local frame = Instance.new("Frame")
	frame.Name = "Tag_" .. tostring(self.tagIndex)
	frame.Size = UDim2.new(0, tagOptions.width or 120, 0, 24)
	frame.BorderSizePixel = 0
	frame.Parent = self.tagsHost
	corner(frame, 999)
	stroke(frame, token(self.theme, "colors.border", Color3.fromRGB(170, 176, 188)), 0.35)
	self:_bindTheme(frame, "BackgroundColor3", "colors.surface", Color3.fromRGB(250, 251, 253))

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(18, 18)
	icon.Position = UDim2.fromOffset(8, 3)
	icon.Font = self.font
	icon.TextSize = 14
	icon.Text = self.iconRegistry:resolve(tagOptions.icon or "tag")
	icon.Parent = frame
	self:_bindTheme(icon, "TextColor3", "colors.textMuted", Color3.fromRGB(94, 106, 126))

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -26, 1, 0)
	label.Position = UDim2.fromOffset(24, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = self.font
	label.TextSize = 12
	label.Text = tostring(tagOptions.text or "Tag")
	label.Parent = frame
	self:_bindTheme(label, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	self:_registerSearch({
		id = "tag:" .. tostring(self.tagIndex),
		title = tagOptions.text or "Tag",
		kind = "tag",
		icon = tagOptions.icon or "tag",
		keywords = { "tag", tostring(tagOptions.text or "") },
		onSelect = function()
			self:_focus(frame)
		end,
	})

	local api = {}
	function api:SetText(value)
		label.Text = tostring(value)
	end
	function api:SetIcon(iconName)
		icon.Text = self.iconRegistry:resolve(iconName)
	end
	function api:Destroy()
		frame:Destroy()
	end
	return api
end

function Window:addTab(tabOptions)
	tabOptions = tabOptions or {}
	if type(tabOptions) == "string" then
		tabOptions = { title = tabOptions }
	end

	local id = tabOptions.id or ("tab_" .. tostring(#self.tabs + 1))
	local title = tabOptions.title or ("Tab " .. tostring(#self.tabs + 1))
	local iconName = tabOptions.icon or "folder"

	local button = Instance.new("TextButton")
	button.Name = "TabButton_" .. id
	button.Size = UDim2.new(1, 0, 0, 29)
	button.BorderSizePixel = 0
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Font = self.font
	button.TextSize = 13
	button.Text = ("  %s  %s"):format(self.iconRegistry:resolve(iconName), title)
	button.Parent = self.tabsList
	corner(button, 10)
	self:_bindTheme(button, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))
	self:_bindTheme(button, "BackgroundColor3", "colors.surface", Color3.fromRGB(250, 251, 253))

	local page = Instance.new("ScrollingFrame")
	page.Name = "Page_" .. id
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Visible = false
	page.Parent = self.pagesHost

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 2)
	padding.PaddingRight = UDim.new(0, 2)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = page

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = page

	local tab = setmetatable({
		window = self,
		id = id,
		title = title,
		icon = iconName,
		button = button,
		page = page,
		sections = {},
	}, Tab)

	table.insert(self.tabs, tab)

	self:_connect(button.MouseButton1Click, function()
		self:_activateTab(tab)
	end)

	self:_registerSearch({
		id = "tab:" .. id,
		title = title,
		kind = "tab",
		icon = iconName,
		keywords = { "tab", title, id },
		onSelect = function()
			self:_activateTab(tab)
			self:_focus(button)
		end,
	})

	if not self.activeTab then
		self:_activateTab(tab)
	end

	return tab
end

function Window:_activateTab(tab)
	self.activeTab = tab
	for _, node in ipairs(self.tabs) do
		local active = node == tab
		node.page.Visible = active
		node.button.BackgroundColor3 = active
			and token(self.theme, "colors.accent", Color3.fromRGB(84, 148, 255))
			or token(self.theme, "colors.surface", Color3.fromRGB(250, 251, 253))
		node.button.TextColor3 = active
			and Color3.fromRGB(255, 255, 255)
			or token(self.theme, "colors.text", Color3.fromRGB(22, 22, 24))
	end
end

function Window:applyTheme(name, overrides)
	local ok, err = self.themeManager:apply(name, overrides)
	if not ok then
		self:reportError("theme.apply", err)
	end
	return ok, err
end

function Window:createKeybindSet(name)
	if not self.keybindManager then
		return false, "keybind manager unavailable"
	end
	return self.keybindManager:registerSet(name)
end

function Window:activateKeybindSet(name)
	if not self.keybindManager then
		return false, "keybind manager unavailable"
	end
	return self.keybindManager:setActiveSet(name)
end

function Window:bindKeybind(setName, options)
	if not self.keybindManager then
		return nil, "keybind manager unavailable"
	end
	return self.keybindManager:bind(setName, options)
end

function Window:runLoadingSequence(steps)
	steps = steps or {}
	if not self.loadingOverlay then
		self.loadingOverlay = LoadingOverlay.new(self.screenGui, self.theme, self.boldFont, self.options.loading)
	end

	self.loadingOverlay:show("Processing...")
	local total = math.max(#steps, 1)
	if #steps == 0 then
		self.loadingOverlay:step(1, 1, "Done")
	else
		for index, label in ipairs(steps) do
			self.loadingOverlay:step(index, total, tostring(label))
			task.wait(0.06)
		end
	end
	self.loadingOverlay:hide()
end

function Window:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

	for _, connection in ipairs(self.connections) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end

	if self.themeConnection and self.themeConnection.Disconnect then
		self.themeConnection:Disconnect()
	end

	if self.loadingOverlay then
		self.loadingOverlay:destroy()
	end

	if self.screenGui then
		self.screenGui:Destroy()
	end
end
function Tab:addSection(sectionOptions)
	sectionOptions = sectionOptions or {}
	local title = sectionOptions.title or "Section"
	local description = sectionOptions.description or ""

	local frame = Instance.new("Frame")
	frame.Name = "Section_" .. title:gsub("%s+", "")
	frame.Size = UDim2.new(1, -6, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BorderSizePixel = 0
	frame.Parent = self.page
	corner(frame, token(self.window.theme, "rounding.card", 14))
	stroke(frame, token(self.window.theme, "colors.border", Color3.fromRGB(176, 185, 198)), 0.2)
	self.window:_bindTheme(frame, "BackgroundColor3", "colors.surface", Color3.fromRGB(248, 250, 255))

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 9)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 20)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Font = self.window.boldFont
	header.TextSize = 16
	header.Text = title
	header.Parent = frame
	self.window:_bindTheme(header, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.BackgroundTransparency = 1
	desc.Size = UDim2.new(1, 0, 0, description ~= "" and 16 or 0)
	desc.Position = UDim2.fromOffset(0, 20)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Font = self.window.font
	desc.TextSize = 12
	desc.Text = description
	desc.Parent = frame
	self.window:_bindTheme(desc, "TextColor3", "colors.textMuted", Color3.fromRGB(84, 94, 106))

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 0)
	content.Position = UDim2.fromOffset(0, description ~= "" and 42 or 28)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = content

	local section = setmetatable({
		title = title,
		frame = frame,
		content = content,
		window = self.window,
		tab = self,
	}, Section)

	table.insert(self.sections, section)

	self.window:_registerSearch({
		id = "section:" .. self.id .. ":" .. title,
		title = title,
		kind = "section",
		keywords = { "section", title, self.title, description },
		onSelect = function()
			self.window:_activateTab(self)
			self.window:_focus(frame)
		end,
	})

	return section
end

function Tab:addFolder(folderOptions)
	folderOptions = folderOptions or {}
	local section = self:addSection({
		title = folderOptions.title or "Folder",
		description = folderOptions.description or "Collapsible settings group",
	})

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "CollapseButton"
	toggleButton.Size = UDim2.new(0, 26, 0, 22)
	toggleButton.Position = UDim2.new(1, -30, 0, 0)
	toggleButton.Text = "v"
	toggleButton.Font = self.window.boldFont
	toggleButton.TextSize = 14
	toggleButton.BackgroundTransparency = 1
	toggleButton.Parent = section.frame.Header

	local opened = true
	local function sync()
		section.content.Visible = opened
		toggleButton.Text = opened and "v" or ">"
	end
	sync()

	self.window:_connect(toggleButton.MouseButton1Click, function()
		opened = not opened
		sync()
	end)

	return section
end

function Tab:addLabel(options)
	local section = self:addSection({ title = "Info", description = "" })
	return section:addLabel(options)
end

function Section:_registerControl(kind, title, keywords, frame, onSelect)
	self.window:_registerSearch({
		id = ("%s:%s:%s"):format(kind, self.tab.id, title),
		title = title,
		kind = kind,
		keywords = keywords,
		onSelect = function()
			self.window:_activateTab(self.tab)
			if onSelect then
				onSelect()
			else
				self.window:_focus(frame)
			end
		end,
	})
end

function Section:addSpacer(height)
	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.Size = UDim2.new(1, 0, 0, height or 8)
	spacer.BackgroundTransparency = 1
	spacer.Parent = self.content
	return spacer
end

function Section:addLabel(labelOptions)
	labelOptions = labelOptions or {}

	local frame = Instance.new("Frame")
	frame.Name = "LabelControl"
	frame.Size = UDim2.new(1, 0, 0, 38)
	frame.BackgroundTransparency = 1
	frame.Parent = self.content

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 18)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = self.window.boldFont
	title.TextSize = 14
	title.Text = tostring(labelOptions.text or "Label")
	title.Parent = frame
	self.window:_bindTheme(title, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.Size = UDim2.new(1, 0, 0, 18)
	desc.Position = UDim2.fromOffset(0, 18)
	desc.BackgroundTransparency = 1
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Font = self.window.font
	desc.TextSize = 12
	desc.Text = tostring(labelOptions.description or "")
	desc.Parent = frame
	self.window:_bindTheme(desc, "TextColor3", "colors.textMuted", Color3.fromRGB(84, 94, 106))

	self:_registerControl("label", title.Text, { "label", title.Text, desc.Text }, frame)

	return {
		SetText = function(_, value)
			title.Text = tostring(value)
		end,
		SetDescription = function(_, value)
			desc.Text = tostring(value)
		end,
	}
end

function Section:addButton(buttonOptions)
	buttonOptions = buttonOptions or {}

	local frame = Instance.new("Frame")
	frame.Name = "ButtonControl"
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundTransparency = 1
	frame.Parent = self.content

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(0.58, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = self.window.font
	label.TextSize = 14
	label.Text = tostring(buttonOptions.title or "Button")
	label.Parent = frame
	self.window:_bindTheme(label, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.Size = UDim2.new(0.4, 0, 1, 0)
	button.Position = UDim2.new(0.6, 0, 0, 0)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Text = tostring(buttonOptions.text or "Run")
	button.Font = self.window.boldFont
	button.TextSize = 13
	button.Parent = frame
	corner(button, 10)
	self.window:_bindTheme(button, "TextColor3", "colors.surface", Color3.fromRGB(255, 255, 255))
	self.window:_bindTheme(button, "BackgroundColor3", "colors.accent", Color3.fromRGB(84, 148, 255))

	local enabled = true
	local callback = buttonOptions.callback

	local function setEnabled(flag)
		enabled = flag
		button.AutoButtonColor = flag
		button.Active = flag
		button.BackgroundTransparency = flag and 0 or 0.45
	end

	self.window:_connect(button.MouseButton1Click, function()
		if not enabled then
			return
		end
		local wrapped = self.window:_safe(
			"button:" .. tostring(label.Text),
			function()
				if callback then
					callback()
				end
			end,
			function(err)
				setEnabled(false)
				self.window:reportError("button:" .. label.Text, err)
			end
		)
		wrapped()
	end)

	self:_registerControl("button", label.Text, { "button", label.Text, button.Text }, frame)

	return {
		SetCallback = function(_, fn)
			callback = fn
		end,
		SetEnabled = function(_, flag)
			setEnabled(flag == true)
		end,
		SetText = function(_, text)
			button.Text = tostring(text)
		end,
	}
end

function Section:addToggle(toggleOptions)
	toggleOptions = toggleOptions or {}

	local frame = Instance.new("Frame")
	frame.Name = "ToggleControl"
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.BackgroundTransparency = 1
	frame.Parent = self.content

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(1, -70, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = self.window.font
	label.TextSize = 14
	label.Text = tostring(toggleOptions.title or "Toggle")
	label.Parent = frame
	self.window:_bindTheme(label, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local switch = Instance.new("TextButton")
	switch.Name = "Switch"
	switch.Size = UDim2.fromOffset(54, 24)
	switch.Position = UDim2.new(1, -54, 0.5, -12)
	switch.Text = ""
	switch.BorderSizePixel = 0
	switch.Parent = frame
	corner(switch, 999)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	corner(knob, 999)
	self.window:_bindTheme(knob, "BackgroundColor3", "colors.surface", Color3.fromRGB(255, 255, 255))

	local state = toggleOptions.default == true
	local enabled = true
	local callback = toggleOptions.callback

	local function render()
		switch.BackgroundColor3 = state
			and token(self.window.theme, "colors.accent", Color3.fromRGB(84, 148, 255))
			or token(self.window.theme, "colors.topbar", Color3.fromRGB(221, 230, 242))
		local x = state and (switch.AbsoluteSize.X - 22) or 2
		knob.Position = UDim2.fromOffset(x, 2)
	end
	
	local function setState(nextState, trigger)
		state = nextState == true
		render()
		if trigger then
			local wrapped = self.window:_safe(
				"toggle:" .. tostring(label.Text),
				function()
					if callback then
						callback(state)
					end
				end,
				function(err)
					enabled = false
					self.window:reportError("toggle:" .. label.Text, err)
				end
			)
			wrapped()
		end
	end

	setState(state, false)

	self.window:_connect(switch.MouseButton1Click, function()
		if not enabled then
			return
		end
		setState(not state, true)
	end)

	self:_registerControl("toggle", label.Text, { "toggle", label.Text }, frame)

	return {
		Get = function()
			return state
		end,
		Set = function(_, value)
			if enabled then
				setState(value == true, true)
			end
		end,
		SetCallback = function(_, fn)
			callback = fn
		end,
		SetEnabled = function(_, flag)
			enabled = flag == true
			switch.Active = enabled
			switch.AutoButtonColor = enabled
			switch.BackgroundTransparency = enabled and 0 or 0.45
		end,
	}
end

function Section:addInput(inputOptions)
	inputOptions = inputOptions or {}

	local frame = Instance.new("Frame")
	frame.Name = "InputControl"
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundTransparency = 1
	frame.Parent = self.content

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(0.36, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = self.window.font
	label.TextSize = 14
	label.Text = tostring(inputOptions.title or "Input")
	label.Parent = frame
	self.window:_bindTheme(label, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.Size = UDim2.new(0.62, 0, 1, 0)
	box.Position = UDim2.new(0.38, 0, 0, 0)
	box.ClearTextOnFocus = false
	box.Font = self.window.font
	box.TextSize = 13
	box.Text = tostring(inputOptions.default or "")
	box.PlaceholderText = tostring(inputOptions.placeholder or "Type here...")
	box.BorderSizePixel = 0
	box.Parent = frame
	corner(box, 10)
	self.window:_bindTheme(box, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))
	self.window:_bindTheme(box, "PlaceholderColor3", "colors.textMuted", Color3.fromRGB(84, 94, 106))
	self.window:_bindTheme(box, "BackgroundColor3", "colors.background", Color3.fromRGB(241, 246, 252))

	local callback = inputOptions.callback
	local enabled = true

	self.window:_connect(box.FocusLost, function(enterPressed)
		if not enabled then
			return
		end
		local wrapped = self.window:_safe(
			"input:" .. tostring(label.Text),
			function()
				if callback then
					callback(box.Text, enterPressed)
				end
			end,
			function(err)
				enabled = false
				box.Active = false
				self.window:reportError("input:" .. label.Text, err)
			end
		)
		wrapped()
	end)

	self:_registerControl("input", label.Text, { "input", label.Text, box.PlaceholderText }, frame)

	return {
		Get = function()
			return box.Text
		end,
		Set = function(_, value)
			box.Text = tostring(value)
		end,
		SetCallback = function(_, fn)
			callback = fn
		end,
		SetEnabled = function(_, flag)
			enabled = flag == true
			box.Active = enabled
			box.BackgroundTransparency = enabled and 0 or 0.45
		end,
	}
end
function Section:addSlider(sliderOptions)
	sliderOptions = sliderOptions or {}
	local minValue = sliderOptions.min or 0
	local maxValue = sliderOptions.max or 100
	local step = sliderOptions.step or 1
	local callback = sliderOptions.callback
	local enabled = true
	local currentValue = sliderOptions.default or minValue

	local frame = Instance.new("Frame")
	frame.Name = "SliderControl"
	frame.Size = UDim2.new(1, 0, 0, 52)
	frame.BackgroundTransparency = 1
	frame.Parent = self.content

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(0.7, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = self.window.font
	label.TextSize = 14
	label.Text = tostring(sliderOptions.title or "Slider")
	label.Parent = frame
	self.window:_bindTheme(label, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0.3, 0, 0, 16)
	valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Font = self.window.font
	valueLabel.TextSize = 13
	valueLabel.Parent = frame
	self.window:_bindTheme(valueLabel, "TextColor3", "colors.textMuted", Color3.fromRGB(84, 94, 106))

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.fromOffset(0, 28)
	track.BorderSizePixel = 0
	track.Parent = frame
	corner(track, 999)
	self.window:_bindTheme(track, "BackgroundColor3", "colors.topbar", Color3.fromRGB(221, 230, 242))

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 999)
	self.window:_bindTheme(fill, "BackgroundColor3", "colors.accent", Color3.fromRGB(84, 148, 255))

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(14, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 999)
	self.window:_bindTheme(knob, "BackgroundColor3", "colors.surface", Color3.fromRGB(255, 255, 255))
	stroke(knob, token(self.window.theme, "colors.border", Color3.fromRGB(176, 185, 198)), 0.2)

	local dragging = false

	local function roundStep(value)
		local snapped = math.floor((value - minValue) / step + 0.5) * step + minValue
		return math.clamp(snapped, minValue, maxValue)
	end

	local function setValue(value, trigger)
		currentValue = roundStep(value)
		local alpha = (currentValue - minValue) / math.max(0.0001, (maxValue - minValue))
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = tostring(currentValue)

		if trigger then
			local wrapped = self.window:_safe(
				"slider:" .. tostring(label.Text),
				function()
					if callback then
						callback(currentValue)
					end
				end,
				function(err)
					enabled = false
					self.window:reportError("slider:" .. label.Text, err)
				end
			)
			wrapped()
		end
	end

	setValue(currentValue, false)

	self.window:_connect(track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and enabled then
			dragging = true
		end
	end)

	self.window:_connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	self.window:_connect(UserInputService.InputChanged, function(input)
		if not dragging or not enabled then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		local relative = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
		local value = minValue + math.clamp(relative, 0, 1) * (maxValue - minValue)
		setValue(value, true)
	end)

	self:_registerControl("slider", label.Text, { "slider", label.Text, tostring(minValue), tostring(maxValue) }, frame)

	return {
		Get = function()
			return currentValue
		end,
		Set = function(_, value)
			if enabled then
				setValue(value, true)
			end
		end,
		SetCallback = function(_, fn)
			callback = fn
		end,
		SetEnabled = function(_, flag)
			enabled = flag == true
			track.BackgroundTransparency = enabled and 0 or 0.45
		end,
	}
end

function Section:addKeybind(keybindOptions)
	keybindOptions = keybindOptions or {}
	local titleText = tostring(keybindOptions.title or "Keybind")
	local setName = tostring(keybindOptions.set or keybindOptions.setName or "global"):lower()
	local callback = keybindOptions.callback
	local keyChanged = keybindOptions.onChanged
	local enabled = keybindOptions.enabled ~= false

	local frame = Instance.new("Frame")
	frame.Name = "KeybindControl"
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundTransparency = 1
	frame.Parent = self.content

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(0.54, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = self.window.font
	label.TextSize = 14
	label.Text = titleText
	label.Parent = frame
	self.window:_bindTheme(label, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local setLabel = Instance.new("TextLabel")
	setLabel.Name = "Set"
	setLabel.Size = UDim2.new(0.15, 0, 1, 0)
	setLabel.Position = UDim2.new(0.54, 0, 0, 0)
	setLabel.BackgroundTransparency = 1
	setLabel.TextXAlignment = Enum.TextXAlignment.Right
	setLabel.Font = self.window.font
	setLabel.TextSize = 12
	setLabel.Text = ("[%s]"):format(setName)
	setLabel.Parent = frame
	self.window:_bindTheme(setLabel, "TextColor3", "colors.textMuted", Color3.fromRGB(84, 94, 106))

	local button = Instance.new("TextButton")
	button.Name = "Key"
	button.Size = UDim2.new(0.28, 0, 1, 0)
	button.Position = UDim2.new(0.72, 0, 0, 0)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = self.window.boldFont
	button.TextSize = 12
	button.Parent = frame
	corner(button, 10)
	self.window:_bindTheme(button, "BackgroundColor3", "colors.background", Color3.fromRGB(241, 246, 252))
	self.window:_bindTheme(button, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local okSet, errSet = self.window:createKeybindSet(setName)
	if not okSet then
		self.window:reportError("keybind.set", errSet or "failed to create keybind set")
	end

	local bindHandle, bindErr = self.window:bindKeybind(setName, {
		id = keybindOptions.id or (self.tab.id .. "." .. titleText),
		title = titleText,
		key = keybindOptions.key or keybindOptions.defaultKey or Enum.KeyCode.Unknown,
		callback = function(keyCode, input, activeSet)
			if callback then
				callback(keyCode, input, activeSet)
			end
		end,
		enabled = enabled,
	})

	if not bindHandle then
		self.window:reportError("keybind.bind", bindErr or "failed to bind key")
		button.Text = "ERROR"
		return {}
	end

	local function syncButtonText()
		button.Text = bindHandle:GetKeyName()
	end
	syncButtonText()

	local capturing = false

	self.window:_connect(button.MouseButton1Click, function()
		if not enabled then
			return
		end

		capturing = true
		button.Text = "PRESS KEY"
		button.AutoButtonColor = false

		self.window.keybindManager:captureNextKey(function(keyCode)
			capturing = false
			button.AutoButtonColor = enabled

			if keyCode == Enum.KeyCode.Escape then
				syncButtonText()
				return
			end

			local ok, err = bindHandle:SetKey(keyCode)
			if not ok then
				self.window:reportError("keybind.capture", err or "invalid key")
				syncButtonText()
				return
			end

			syncButtonText()
			if keyChanged then
				pcall(keyChanged, keyCode, setName)
			end
		end)
	end)

	self:_registerControl("keybind", titleText, { "keybind", titleText, setName, bindHandle:GetKeyName() }, frame)

	return {
		SetKey = function(_, key)
			local ok, err = bindHandle:SetKey(key)
			if ok then
				syncButtonText()
			end
			return ok, err
		end,
		GetKey = function()
			return bindHandle:GetKeyCode()
		end,
		GetKeyName = function()
			return bindHandle:GetKeyName()
		end,
		SetEnabled = function(_, flag)
			enabled = flag == true
			bindHandle:SetEnabled(enabled)
			button.AutoButtonColor = enabled and not capturing
			button.BackgroundTransparency = enabled and 0 or 0.45
		end,
		SetCallback = function(_, fn)
			callback = fn
		end,
		Unbind = function()
			bindHandle:Unbind()
			button.Text = "UNBOUND"
			enabled = false
			button.AutoButtonColor = false
		end,
	}
end

function Section:addDropdown(dropdownOptions)
	dropdownOptions = dropdownOptions or {}
	local options = dropdownOptions.options or {}
	local callback = dropdownOptions.callback
	local enabled = true
	local opened = false
	local selected = dropdownOptions.default or options[1]

	local frame = Instance.new("Frame")
	frame.Name = "DropdownControl"
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundTransparency = 1
	frame.Parent = self.content

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(0.36, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = self.window.font
	label.TextSize = 14
	label.Text = tostring(dropdownOptions.title or "Dropdown")
	label.Parent = frame
	self.window:_bindTheme(label, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))

	local button = Instance.new("TextButton")
	button.Name = "Selector"
	button.Size = UDim2.new(0.62, 0, 1, 0)
	button.Position = UDim2.new(0.38, 0, 0, 0)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Font = self.window.font
	button.TextSize = 13
	button.Text = "  " .. tostring(selected or "Select")
	button.Parent = frame
	corner(button, 10)
	self.window:_bindTheme(button, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))
	self.window:_bindTheme(button, "BackgroundColor3", "colors.background", Color3.fromRGB(241, 246, 252))

	local pop = Instance.new("Frame")
	pop.Name = "Options"
	pop.Size = UDim2.new(0.62, 0, 0, 0)
	pop.Position = UDim2.new(0.38, 0, 1, 4)
	pop.Visible = false
	pop.BorderSizePixel = 0
	pop.Parent = frame
	corner(pop, 10)
	stroke(pop, token(self.window.theme, "colors.border", Color3.fromRGB(176, 185, 198)), 0.2)
	self.window:_bindTheme(pop, "BackgroundColor3", "colors.surface", Color3.fromRGB(248, 250, 255))

	local popLayout = Instance.new("UIListLayout")
	popLayout.Padding = UDim.new(0, 2)
	popLayout.Parent = pop

	local function closeDropdown()
		opened = false
		pop.Visible = false
		pop.Size = UDim2.new(0.62, 0, 0, 0)
		frame.Size = UDim2.new(1, 0, 0, 34)
	end

	local function openDropdown()
		opened = true
		pop.Visible = true
		pop.Size = UDim2.new(0.62, 0, 0, math.max(1, #options) * 28 + 2)
		frame.Size = UDim2.new(1, 0, 0, 34 + math.max(1, #options) * 28 + 6)
	end

	local function choose(option)
		selected = option
		button.Text = "  " .. tostring(option)
		local wrapped = self.window:_safe(
			"dropdown:" .. tostring(label.Text),
			function()
				if callback then
					callback(option)
				end
			end,
			function(err)
				enabled = false
				self.window:reportError("dropdown:" .. label.Text, err)
			end
		)
		wrapped()
	end

	local function rebuildOptions()
		for _, child in ipairs(pop:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for _, option in ipairs(options) do
			local opt = Instance.new("TextButton")
			opt.Name = "Option_" .. tostring(option)
			opt.Size = UDim2.new(1, -6, 0, 26)
			opt.Position = UDim2.fromOffset(3, 0)
			opt.BorderSizePixel = 0
			opt.AutoButtonColor = true
			opt.Font = self.window.font
			opt.TextSize = 13
			opt.Text = tostring(option)
			opt.Parent = pop
			corner(opt, 6)
			self.window:_bindTheme(opt, "TextColor3", "colors.text", Color3.fromRGB(22, 22, 24))
			self.window:_bindTheme(opt, "BackgroundColor3", "colors.background", Color3.fromRGB(241, 246, 252))

			self.window:_connect(opt.MouseButton1Click, function()
				if not enabled then
					return
				end
				choose(option)
				closeDropdown()
			end)
		end
	end

	rebuildOptions()

	self.window:_connect(button.MouseButton1Click, function()
		if not enabled then
			return
		end
		if opened then
			closeDropdown()
		else
			openDropdown()
		end
	end)

	self:_registerControl("dropdown", label.Text, flatten({ "dropdown", label.Text, table.unpack(options) }), frame)

	return {
		Get = function()
			return selected
		end,
		Set = function(_, option)
			if enabled then
				choose(option)
			end
		end,
		SetOptions = function(_, newOptions)
			options = newOptions or {}
			closeDropdown()
			rebuildOptions()
		end,
		SetCallback = function(_, fn)
			callback = fn
		end,
		SetEnabled = function(_, flag)
			enabled = flag == true
			button.Active = enabled
			button.AutoButtonColor = enabled
			button.BackgroundTransparency = enabled and 0 or 0.45
			if not enabled then
				closeDropdown()
			end
		end,
	}
end

Window.AddTag = Window.addTag
Window.AddTab = Window.addTab
Window.SetSearchEnabled = Window.setSearchEnabled
Window.ApplyTheme = Window.applyTheme
Window.SetTransparency = Window.setTransparency
Window.SetOpacity = Window.setOpacity
Window.SetFullscreenDarkTheme = Window.setFullscreenDarkTheme
Window.SetSearchPlaceholder = Window.setSearchPlaceholder
Window.SetSidebarWidth = Window.setSidebarWidth
Window.CreateKeybindSet = Window.createKeybindSet
Window.ActivateKeybindSet = Window.activateKeybindSet
Window.BindKeybind = Window.bindKeybind
Window.RunLoadingSequence = Window.runLoadingSequence
Window.Destroy = Window.destroy

Tab.AddSection = Tab.addSection
Tab.AddFolder = Tab.addFolder
Tab.AddLabel = Tab.addLabel

Section.AddSpacer = Section.addSpacer
Section.AddLabel = Section.addLabel
Section.AddButton = Section.addButton
Section.AddToggle = Section.addToggle
Section.AddInput = Section.addInput
Section.AddSlider = Section.addSlider
Section.AddKeybind = Section.addKeybind
Section.AddDropdown = Section.addDropdown

return Window
