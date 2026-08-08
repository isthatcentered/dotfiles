---@alias Unsubscribe fun(): nil

---@class Event
---@field kind string
---@field payload table

---@class EventEmitter
---@field private listeners function[]
local EventEmitter = {}
EventEmitter.__index = EventEmitter

---@return EventEmitter
function EventEmitter.new()
  local self = setmetatable({}, EventEmitter)
  self.listeners = {}
  return self
end

---@param callback fun(event: Event): nil
---@return Unsubscribe
function EventEmitter:listen(callback)
  assert(type(callback) == "function", "Callback must be a function")

  table.insert(self.listeners, callback)

  return function()
    for i, listener in ipairs(self.listeners) do
      if listener == callback then
        table.remove(self.listeners, i)
        break
      end
    end
  end
end

---@param event Event
function EventEmitter:emit(event)
  for _, listener in ipairs(self.listeners) do
    listener(event)
  end
end

return EventEmitter
