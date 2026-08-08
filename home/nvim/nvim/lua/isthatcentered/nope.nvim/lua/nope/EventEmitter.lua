---@class EventEmitter
---@field private _listeners table<string, fun(...)[]>
local EventEmitter = {}
EventEmitter.__index = EventEmitter

---@return EventEmitter
function EventEmitter.new()
  return setmetatable({
    _listeners = {},
  }, EventEmitter)
end

---@param event string
---@param listener fun(...)
---@return fun() unsubscribe
function EventEmitter:on(event, listener)
  if not self._listeners[event] then
    self._listeners[event] = {}
  end
  table.insert(self._listeners[event], listener)

  return function()
    local listeners = self._listeners[event]
    if not listeners then
      return
    end
    for i, l in ipairs(listeners) do
      if l == listener then
        table.remove(listeners, i)
        return
      end
    end
  end
end

---@param event string
---@param listener fun(...)
---@return fun() unsubscribe
function EventEmitter:once(event, listener)
  local unsubscribe
  unsubscribe = self:on(event, function(...)
    unsubscribe()
    listener(...)
  end)
  return unsubscribe
end

---@param event string
---@param ... any
function EventEmitter:emit(event, ...)
  local listeners = self._listeners[event]
  if not listeners then
    return
  end
  -- Copy listeners to avoid issues with unsubscribe during iteration
  local listeners_copy = { unpack(listeners) }
  for _, listener in ipairs(listeners_copy) do
    listener(...)
  end
end

---@param event? string
function EventEmitter:off(event)
  if event then
    self._listeners[event] = nil
  else
    self._listeners = {}
  end
end

---@return number
function EventEmitter:listener_count()
  local count = 0
  for _, listeners in pairs(self._listeners) do
    count = count + #listeners
  end
  return count
end

return EventEmitter
