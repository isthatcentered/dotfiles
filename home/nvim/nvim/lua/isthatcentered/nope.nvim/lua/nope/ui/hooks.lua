---Hooks module for React-style state and lifecycle management
---
---Hooks must be called in the same order every render.
---Only call hooks from component functions.

local M = {}

---@type ComponentInstance|nil
M._current_instance = nil

---@type fun()|nil
M._schedule_rerender = nil

---Set the current rendering context
---@param instance ComponentInstance
---@param schedule_rerender fun()
function M._set_context(instance, schedule_rerender)
  M._current_instance = instance
  M._schedule_rerender = schedule_rerender
  instance._hook_index = 1
end

---Clear the current rendering context
function M._clear_context()
  M._current_instance = nil
  M._schedule_rerender = nil
end

---Get the current instance or error if not in render context
---@return ComponentInstance
local function get_instance()
  if not M._current_instance then
    error('Hooks can only be called during component render')
  end
  return M._current_instance
end

---Create a state value that triggers re-render when updated
---@generic T
---@param initial T
---@return T value
---@return fun(value: T) setter
function M.use_state(initial)
  local instance = get_instance()
  local idx = instance._hook_index
  instance._hook_index = idx + 1

  -- Initialize on first render
  if instance._hooks[idx] == nil then
    instance._hooks[idx] = initial
  end

  local schedule = M._schedule_rerender

  local function setter(value)
    if instance._hooks[idx] ~= value then
      instance._hooks[idx] = value
      if schedule then
        schedule()
      end
    end
  end

  return instance._hooks[idx], setter
end

---Run a callback once when component mounts
---@param fn fun()
function M.use_mount(fn)
  local instance = get_instance()
  local idx = instance._hook_index
  instance._hook_index = idx + 1

  -- Only run on first render (mount)
  if not instance._hooks[idx] then
    instance._hooks[idx] = true
    fn()
  end
end

---Register a cleanup callback to run when component unmounts
---@param fn fun()
function M.use_unmount(fn)
  local instance = get_instance()
  local idx = instance._hook_index
  instance._hook_index = idx + 1

  -- Store/update the unmount callback
  instance._hooks[idx] = fn

  -- Track index for cleanup
  if not instance._unmount_callbacks then
    instance._unmount_callbacks = {}
  end
  instance._unmount_callbacks[idx] = true
end

---Run all unmount callbacks for an instance
---@param instance ComponentInstance
function M._run_unmount_callbacks(instance)
  if instance._unmount_callbacks then
    for idx in pairs(instance._unmount_callbacks) do
      local fn = instance._hooks[idx]
      if type(fn) == 'function' then
        fn()
      end
    end
  end
end

return M
