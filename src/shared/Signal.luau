--!nonstrict
-- Minimal signal: Connect(fn) -> connection with :Disconnect(), Fire(...).

export type Connection = { Disconnect: (self: Connection) -> () }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { [number]: (...any) -> () }, _next = 1 }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local id = self._next
	self._next += 1
	self._handlers[id] = handler
	local handlers = self._handlers
	return {
		Disconnect = function()
			handlers[id] = nil
		end,
	} :: any
end

function Signal:Fire(...)
	for _, handler in self._handlers do
		task.spawn(handler, ...)
	end
end

return Signal
