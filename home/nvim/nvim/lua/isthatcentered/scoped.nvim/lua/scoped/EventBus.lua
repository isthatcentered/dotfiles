---@class EventBus<A>
---@field private subscribers function[]
local EventBus = {}
EventBus.__index = EventBus

---@generic A
---@return EventBus<A>
function EventBus.new()
  local self = setmetatable({}, EventBus)
  self.subscribers = {}
  return self
end

---@generic A
---@param self EventBus<A>
---@param callback fun(event: A): nil
---@return fun(): nil unsubscribe function
function EventBus:subscribe(callback)
  assert(type(callback) == "function" or type(callback) == "table", "Callback must be a function")

  table.insert(self.subscribers, callback)

  local function unsubscribe()
    for i, subscriber in ipairs(self.subscribers) do
      if subscriber == callback then
        table.remove(self.subscribers, i)
        break
      end
    end
  end

  return unsubscribe
end

---@generic A
---@param self EventBus<A>
---@param event A
function EventBus:emit(event)
  for _, subscriber in ipairs(self.subscribers) do
    subscriber(event)
  end
end



return EventBus


