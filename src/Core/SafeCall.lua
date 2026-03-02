local SafeCall = {}
SafeCall.__index = SafeCall

function SafeCall.new(logger, uiReporter)
	local self = setmetatable({}, SafeCall)
	self.logger = logger
	self.uiReporter = uiReporter
	return self
end

function SafeCall:execute(scope, fn, ...)
	if type(fn) ~= "function" then
		return false, "safe execution received a non-function"
	end

	local packed = table.pack(...)
	local ok, result = xpcall(function()
		return fn(table.unpack(packed, 1, packed.n))
	end, function(err)
		return debug.traceback(tostring(err), 2)
	end)

	if ok then
		return true, result
	end

	local report = ("Scope '%s' failed: %s"):format(tostring(scope), tostring(result))
	if self.logger then
		self.logger:error(report)
	end

	if self.uiReporter then
		pcall(self.uiReporter, scope, result)
	end

	return false, result
end

function SafeCall:wrap(scope, fn, onFailure)
	return function(...)
		local ok, result = self:execute(scope, fn, ...)
		if not ok and onFailure then
			pcall(onFailure, result)
		end
		return ok, result
	end
end

return SafeCall
