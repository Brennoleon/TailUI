local HttpService = game:GetService("HttpService")

local Logger = {}
Logger.__index = Logger

function Logger.new(options)
	options = options or {}

	local self = setmetatable({}, Logger)
	self.prefix = options.prefix or "[TailUI]"
	self.maxEntries = options.maxEntries or 300
	self.entries = {}
	self.onEntry = options.onEntry

	return self
end

function Logger:_push(level, message, context)
	local entry = {
		level = level,
		message = tostring(message),
		context = context,
		timestamp = os.time(),
	}

	table.insert(self.entries, entry)
	if #self.entries > self.maxEntries then
		table.remove(self.entries, 1)
	end

	local line = ("%s [%s] %s"):format(self.prefix, level, entry.message)
	if level == "ERROR" or level == "WARN" then
		warn(line)
	else
		print(line)
	end

	if context ~= nil then
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode(context)
		end)
		if ok then
			print(("%s [CTX] %s"):format(self.prefix, encoded))
		end
	end

	if self.onEntry then
		pcall(self.onEntry, entry)
	end

	return entry
end

function Logger:debug(message, context)
	return self:_push("DEBUG", message, context)
end

function Logger:info(message, context)
	return self:_push("INFO", message, context)
end

function Logger:warn(message, context)
	return self:_push("WARN", message, context)
end

function Logger:error(message, context)
	return self:_push("ERROR", message, context)
end

function Logger:getEntries()
	return self.entries
end

return Logger
