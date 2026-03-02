local Runtime = {}
Runtime.__index = Runtime

local function readGlobal(name)
	local env = getfenv and getfenv() or _G
	if env and env[name] ~= nil then
		return env[name]
	end
	return _G[name]
end

function Runtime.new(logger)
	local self = setmetatable({}, Runtime)
	self.logger = logger
	return self
end

function Runtime:getExecutorName()
	local identify = readGlobal("identifyexecutor")
	if type(identify) == "function" then
		local ok, value = pcall(identify)
		if ok and value then
			return tostring(value)
		end
	end

	local getName = readGlobal("getexecutorname")
	if type(getName) == "function" then
		local ok, value = pcall(getName)
		if ok and value then
			return tostring(value)
		end
	end

	return "Unknown Executor"
end

function Runtime:getCapabilities()
	return {
		getgc = type(readGlobal("getgc")) == "function",
		getreg = type(readGlobal("getreg")) == "function",
		getrenv = type(readGlobal("getrenv")) == "function",
		getfenv = type(readGlobal("getfenv")) == "function",
		gethui = type(readGlobal("gethui")) == "function",
		readfile = type(readGlobal("readfile")) == "function",
		writefile = type(readGlobal("writefile")) == "function",
		makefolder = type(readGlobal("makefolder")) == "function",
		request = type(readGlobal("request")) == "function"
			or type(readGlobal("http_request")) == "function"
			or (type(readGlobal("syn")) == "table" and type(readGlobal("syn").request) == "function"),
	}
end

function Runtime:protectGui(gui)
	local syn = readGlobal("syn")
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, gui)
		return true
	end

	local protectgui = readGlobal("protectgui")
	if type(protectgui) == "function" then
		pcall(protectgui, gui)
		return true
	end

	return false
end

function Runtime:report()
	return {
		executor = self:getExecutorName(),
		capabilities = self:getCapabilities(),
	}
end

return Runtime
