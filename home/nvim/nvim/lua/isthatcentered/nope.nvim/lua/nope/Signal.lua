---@class Event<K, T> {type: K, payload: T}

---@class Observable2<T> {listen: fun(cb: fun(event: T)): fun()}

---@class Signal<T>: Observable2<T> {private _listeners: fun(value: T)[]}
local Signal = {}
Signal.__index = Signal

---@generic T
---@return Signal<T>
function Signal.new()
  return setmetatable({
    _listeners = {},
  }, Signal)
end

---@generic T
---@param self Signal<T>
---@param listener fun(value: T)
---@return fun() unsubscribe
function Signal:listen(listener)
  table.insert(self._listeners, listener)

  return function()
    for i, l in ipairs(self._listeners) do
      if l == listener then
        table.remove(self._listeners, i)
        return
      end
    end
  end
end

---@generic T
---@param self Signal<T>
---@param value T
function Signal:emit(value)
  -- Copy listeners to avoid issues with unsubscribe during iteration
  local listeners_copy = { unpack(self._listeners) }
  for _, listener in ipairs(listeners_copy) do
    listener(value)
  end
end

---Remove all listeners
function Signal:off()
  self._listeners = {}
end

---@return number
function Signal:listener_count()
  return #self._listeners
end

return Signal
