---Root module - orchestrates component rendering to a buffer
---
---Usage:
---  local root = Root.new(buf)
---  root:render(function()
---    return MyComponent({ data = some_data })
---  end)
---  root:unmount()

local renderer = require('nope.ui.renderer')
local reconciler = require('nope.ui.reconciler')

---@class Root
---@field buf number
---@field ns_id number
---@field _component_fn fun(): VNode|nil
---@field _instance ComponentInstance|nil
---@field _pending_render boolean
---@field _mounted boolean
---@field _existing_keys table<string, boolean>
local Root = {}
Root.__index = Root

---Create a new Root attached to a buffer
---@param buf number
---@return Root
function Root.new(buf)
  local ns_id = vim.api.nvim_create_namespace('nope_ui_' .. buf)

  local self = setmetatable({
    buf = buf,
    ns_id = ns_id,
    _component_fn = nil,
    _instance = nil,
    _pending_render = false,
    _mounted = true,
    _existing_keys = {},
  }, Root)

  return self
end

---Schedule a re-render (debounced via vim.schedule)
function Root:_schedule_rerender()
  if self._pending_render or not self._mounted then
    return
  end

  self._pending_render = true

  vim.schedule(function()
    self._pending_render = false

    if not self._mounted or not self._component_fn then
      return
    end

    -- Check buffer still valid
    if not vim.api.nvim_buf_is_valid(self.buf) then
      self:unmount()
      return
    end

    self:_do_render()
  end)
end

---Perform the actual render
function Root:_do_render()
  if not self._component_fn then
    return
  end

  ---@type ReconcileState
  local state = {
    instances = {},
    schedule_rerender = function()
      self:_schedule_rerender()
    end,
  }

  -- Reconcile component
  local vnode, instance = reconciler.reconcile_component(
    self._component_fn,
    {},
    self._instance,
    state
  )

  self._instance = instance

  if not vnode then
    return
  end

  -- Render to output
  local output = renderer.render(vnode)

  -- Apply to buffer
  renderer.apply(self.buf, output, self.ns_id)
  renderer.apply_keybinds(self.buf, output.keybinds, self._existing_keys)
end

---Render a component tree to the buffer
---@param component_fn fun(): VNode
function Root:render(component_fn)
  if not self._mounted then
    error('Cannot render to unmounted root')
  end

  self._component_fn = component_fn
  self:_do_render()
end

---Unmount and cleanup
function Root:unmount()
  if not self._mounted then
    return
  end

  self._mounted = false

  -- Run unmount callbacks
  if self._instance then
    reconciler.unmount_instance(self._instance)
    self._instance = nil
  end

  -- Clear keybinds
  for key in pairs(self._existing_keys) do
    pcall(vim.keymap.del, 'n', key, { buffer = self.buf })
  end
  self._existing_keys = {}

  -- Clear namespace
  if vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_clear_namespace(self.buf, self.ns_id, 0, -1)
  end

  self._component_fn = nil
end

return Root
