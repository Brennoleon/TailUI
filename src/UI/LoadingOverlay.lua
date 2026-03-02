local TweenService = game:GetService("TweenService")

local LoadingOverlay = {}
LoadingOverlay.__index = LoadingOverlay

local function safeColor(theme, path, fallback)
	local node = theme
	for part in tostring(path):gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return fallback
		end
		node = node[part]
	end
	return node or fallback
end

function LoadingOverlay.new(screenGui, theme, font, options)
	options = options or {}

	local self = setmetatable({}, LoadingOverlay)
	self.screenGui = screenGui
	self.theme = theme or {}
	self.font = font
	self.options = options
	self.progress = 0
	self:_build()
	return self
end

function LoadingOverlay:_build()
	local colors = self.theme.colors or {}
	local overlayColor = safeColor(self.theme, "colors.overlay", Color3.fromRGB(8, 10, 13))
	local surfaceColor = safeColor(self.theme, "colors.surface", Color3.fromRGB(14, 18, 23))
	local accentColor = safeColor(self.theme, "colors.accent", Color3.fromRGB(50, 155, 255))

	self.frame = Instance.new("Frame")
	self.frame.Name = "TailLoadingOverlay"
	self.frame.BackgroundColor3 = overlayColor
	self.frame.BackgroundTransparency = 0.06
	self.frame.Size = UDim2.fromScale(1, 1)
	self.frame.Position = UDim2.fromScale(0, 0)
	self.frame.Visible = false
	self.frame.ZIndex = 1000
	self.frame.Parent = self.screenGui

	local veil = Instance.new("UIGradient")
	veil.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, overlayColor),
		ColorSequenceKeypoint.new(1, surfaceColor),
	})
	veil.Rotation = 30
	veil.Parent = self.frame

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(460, 150)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundColor3 = surfaceColor
	card.BorderSizePixel = 0
	card.ZIndex = 1001
	card.Parent = self.frame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = safeColor(self.theme, "colors.border", Color3.fromRGB(40, 48, 64))
	cardStroke.Transparency = 0.2
	cardStroke.Thickness = 1
	cardStroke.Parent = card

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(32, 32)
	icon.Position = UDim2.fromOffset(18, 16)
	icon.Font = self.font
	icon.TextSize = 24
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.Text = tostring(self.options.icon or "*")
	icon.TextColor3 = safeColor(self.theme, "colors.text", Color3.fromRGB(235, 242, 251))
	icon.ZIndex = 1002
	icon.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -62, 0, 28)
	title.Position = UDim2.fromOffset(56, 16)
	title.Font = self.font
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = tostring(self.options.title or "Initializing Tail UI")
	title.TextColor3 = safeColor(self.theme, "colors.text", Color3.fromRGB(235, 242, 251))
	title.ZIndex = 1002
	title.Parent = card

	self.status = Instance.new("TextLabel")
	self.status.Name = "Status"
	self.status.BackgroundTransparency = 1
	self.status.Size = UDim2.new(1, -62, 0, 20)
	self.status.Position = UDim2.fromOffset(56, 45)
	self.status.Font = self.font
	self.status.TextSize = 13
	self.status.TextXAlignment = Enum.TextXAlignment.Left
	self.status.Text = tostring(self.options.subtitle or "Preparing modules...")
	self.status.TextColor3 = safeColor(self.theme, "colors.textMuted", Color3.fromRGB(140, 152, 172))
	self.status.ZIndex = 1002
	self.status.Parent = card

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -36, 0, 10)
	track.Position = UDim2.fromOffset(18, 92)
	track.BackgroundColor3 = safeColor(self.theme, "colors.topbar", Color3.fromRGB(21, 25, 32))
	track.BorderSizePixel = 0
	track.ZIndex = 1002
	track.Parent = card

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	self.fill = Instance.new("Frame")
	self.fill.Name = "Fill"
	self.fill.Size = UDim2.new(0, 0, 1, 0)
	self.fill.BackgroundColor3 = accentColor
	self.fill.BorderSizePixel = 0
	self.fill.ZIndex = 1003
	self.fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = self.fill

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accentColor),
		ColorSequenceKeypoint.new(1, accentColor:Lerp(Color3.new(1, 1, 1), 0.18)),
	})
	fillGradient.Rotation = 20
	fillGradient.Parent = self.fill

	self.detail = Instance.new("TextLabel")
	self.detail.Name = "Detail"
	self.detail.BackgroundTransparency = 1
	self.detail.Size = UDim2.new(1, -36, 0, 18)
	self.detail.Position = UDim2.fromOffset(18, 110)
	self.detail.Font = self.font
	self.detail.TextSize = 12
	self.detail.TextXAlignment = Enum.TextXAlignment.Left
	self.detail.Text = tostring(self.options.detail or "Loading...")
	self.detail.TextColor3 = safeColor(self.theme, "colors.textMuted", Color3.fromRGB(140, 152, 172))
	self.detail.ZIndex = 1002
	self.detail.Parent = card
end

function LoadingOverlay:show(initialText)
	self.status.Text = initialText or self.status.Text
	self.progress = 0
	self.fill.Size = UDim2.new(0, 0, 1, 0)
	self.frame.Visible = true
end

function LoadingOverlay:setProgress(value, text)
	self.progress = math.clamp(value, 0, 1)
	if text then
		self.detail.Text = text
	end

	TweenService:Create(
		self.fill,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(self.progress, 0, 1, 0) }
	):Play()
end

function LoadingOverlay:step(index, total, text)
	total = math.max(total, 1)
	self:setProgress(index / total, text)
end

function LoadingOverlay:hide()
	if not self.frame.Visible then
		return
	end

	local tween = TweenService:Create(
		self.frame,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Wait()

	self.frame.Visible = false
	self.frame.BackgroundTransparency = 0.06
end

function LoadingOverlay:destroy()
	if self.frame then
		self.frame:Destroy()
	end
end

return LoadingOverlay
