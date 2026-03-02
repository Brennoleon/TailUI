local UserInputService = game:GetService("UserInputService")

local KeybindManager = {}
KeybindManager.__index = KeybindManager

local function normalizeKeyCode(key)
	if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
		return key
	end

	if type(key) == "string" and key ~= "" then
		local value = Enum.KeyCode[key]
		if value then
			return value
		end
	end

	return nil
end

local function normalizeActionId(id, fallbackIndex)
	if type(id) == "string" and id ~= "" then
		return id
	end
	return "action_" .. tostring(fallbackIndex)
end

function KeybindManager.new(logger)
	local self = setmetatable({}, KeybindManager)
	self.logger = logger
	self.sets = {}
	self.setOrder = {}
	self.activeSet = "global"
	self.index = 0
	self.captureConnection = nil

	self:registerSet("global")

	self.inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		self:_onInput(input)
	end)

	return self
end

function KeybindManager:_onInput(input)
	if not input then
		return
	end

	local inputKey = input.KeyCode
	if inputKey == Enum.KeyCode.Unknown then
		return
	end

	local function fireSet(setName)
		local set = self.sets[setName]
		if not set then
			return false
		end

		for _, action in ipairs(set.actions) do
			if action.enabled ~= false and action.keyCode == inputKey then
				local ok, err = pcall(function()
					action.callback(inputKey, input, setName)
				end)
				if not ok and self.logger then
					self.logger:error("keybind callback failed", {
						set = setName,
						action = action.id,
						error = tostring(err),
					})
				end
				return true
			end
		end

		return false
	end

	if self.activeSet and self.activeSet ~= "global" then
		if fireSet(self.activeSet) then
			return
		end
	end

	fireSet("global")
end

function KeybindManager:registerSet(name)
	name = tostring(name or ""):lower()
	if name == "" then
		return false, "keybind set name cannot be empty"
	end

	if self.sets[name] then
		return true, self.sets[name]
	end

	local entry = {
		name = name,
		actions = {},
	}
	self.sets[name] = entry
	table.insert(self.setOrder, name)
	return true, entry
end

function KeybindManager:getSet(name)
	return self.sets[tostring(name or ""):lower()]
end

function KeybindManager:listSets()
	local out = {}
	for _, name in ipairs(self.setOrder) do
		table.insert(out, name)
	end
	return out
end

function KeybindManager:setActiveSet(name)
	name = tostring(name or ""):lower()
	if name == "" then
		return false, "active set cannot be empty"
	end
	if not self.sets[name] then
		return false, ("keybind set '%s' does not exist"):format(name)
	end
	self.activeSet = name
	return true
end

function KeybindManager:getActiveSet()
	return self.activeSet
end

function KeybindManager:bind(setName, actionOptions)
	actionOptions = actionOptions or {}
	setName = tostring(setName or "global"):lower()

	local okSet = self:registerSet(setName)
	if not okSet then
		return nil, "failed to register keybind set"
	end

	local set = self.sets[setName]
	self.index = self.index + 1

	local action = {
		id = normalizeActionId(actionOptions.id, self.index),
		title = tostring(actionOptions.title or "Keybind"),
		description = tostring(actionOptions.description or ""),
		keyCode = normalizeKeyCode(actionOptions.key or actionOptions.keyCode) or Enum.KeyCode.Unknown,
		callback = actionOptions.callback or function() end,
		enabled = actionOptions.enabled ~= false,
	}

	table.insert(set.actions, action)

	local manager = self
	local handle = {}

	function handle:GetId()
		return action.id
	end

	function handle:GetSet()
		return setName
	end

	function handle:GetKeyCode()
		return action.keyCode
	end

	function handle:GetKeyName()
		if action.keyCode and action.keyCode ~= Enum.KeyCode.Unknown then
			return action.keyCode.Name
		end
		return "Unbound"
	end

	function handle:SetKey(key)
		local keyCode = normalizeKeyCode(key)
		if not keyCode then
			return false, "invalid keycode"
		end
		action.keyCode = keyCode
		return true
	end

	function handle:SetCallback(fn)
		if type(fn) ~= "function" then
			return false, "callback must be a function"
		end
		action.callback = fn
		return true
	end

	function handle:SetEnabled(flag)
		action.enabled = flag == true
	end

	function handle:Unbind()
		manager:unbind(setName, action.id)
	end

	return handle
end

function KeybindManager:unbind(setName, actionId)
	setName = tostring(setName or "global"):lower()
	local set = self.sets[setName]
	if not set then
		return false
	end

	for index, action in ipairs(set.actions) do
		if action.id == actionId then
			table.remove(set.actions, index)
			return true
		end
	end

	return false
end

function KeybindManager:captureNextKey(callback, options)
	options = options or {}
	if self.captureConnection then
		self.captureConnection:Disconnect()
		self.captureConnection = nil
	end

	local allowMouse = options.allowMouse == true
	self.captureConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		local keyCode = input.KeyCode
		if keyCode == Enum.KeyCode.Unknown and not allowMouse then
			return
		end

		if self.captureConnection then
			self.captureConnection:Disconnect()
			self.captureConnection = nil
		end

		if type(callback) == "function" then
			pcall(callback, keyCode, input)
		end
	end)
end

function KeybindManager:destroy()
	if self.captureConnection then
		self.captureConnection:Disconnect()
		self.captureConnection = nil
	end
	if self.inputConnection then
		self.inputConnection:Disconnect()
		self.inputConnection = nil
	end
end

return KeybindManager
