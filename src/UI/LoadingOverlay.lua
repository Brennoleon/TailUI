local TweenService = game:GetService("TweenService")

local LoadingOverlay = {}
LoadingOverlay.__index = LoadingOverlay

function LoadingOverlay.new(screenGui, theme, font)
	local self = setmetatable({}, LoadingOverlay)
	self.screenGui = screenGui
	self.theme = theme
	self.font = font
	self.progress = 0
	self:_build()
	return self
end

function LoadingOverlay:_build()
	local colors = self.theme.colors
	self.frame = Instance.new("Frame")
	self.frame.Name = "TailLoadingOverlay"
	self.frame.BackgroundColor3 = colors.background
	self.frame.BackgroundTransparency = 0.06
	self.frame.Size = UDim2.fromScale(1, 1)
	self.frame.Position = UDim2.fromScale(0, 0)
	self.frame.Visible = false
	self.frame.ZIndex = 1000
	self.frame.Parent = self.screenGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(0.7, 0, 0, 42)
	title.Position = UDim2.fromScale(0.15, 0.38)
	title.Font = self.font
	title.TextScaled = true
	title.TextColor3 = colors.text
	title.Text = "Loading Tail UI"
	title.ZIndex = 1001
	title.Parent = self.frame

	self.status = Instance.new("TextLabel")
	self.status.Name = "Status"
	self.status.BackgroundTransparency = 1
	self.status.Size = UDim2.new(0.7, 0, 0, 28)
	self.status.Position = UDim2.fromScale(0.15, 0.46)
	self.status.Font = self.font
	self.status.TextSize = 16
	self.status.TextColor3 = colors.textMuted
	self.status.Text = "Initializing..."
	self.status.ZIndex = 1001
	self.status.Parent = self.frame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(0.42, 0, 0, 12)
	track.Position = UDim2.fromScale(0.29, 0.53)
	track.BackgroundColor3 = colors.topbar
	track.BorderSizePixel = 0
	track.ZIndex = 1001
	track.Parent = self.frame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	self.fill = Instance.new("Frame")
	self.fill.Name = "Fill"
	self.fill.Size = UDim2.new(0, 0, 1, 0)
	self.fill.BackgroundColor3 = colors.accent
	self.fill.BorderSizePixel = 0
	self.fill.ZIndex = 1002
	self.fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = self.fill
end

function LoadingOverlay:show(initialText)
	self.status.Text = initialText or "Starting..."
	self.progress = 0
	self.fill.Size = UDim2.new(0, 0, 1, 0)
	self.frame.Visible = true
end

function LoadingOverlay:setProgress(value, text)
	self.progress = math.clamp(value, 0, 1)
	if text then
		self.status.Text = text
	end

	TweenService:Create(
		self.fill,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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
