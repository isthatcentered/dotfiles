---@class DetailsServiceState
---@field selected_node TreeNode|nil
---@field scroll_offset number

---@class DetailsService
---@field private state DetailsServiceState
---@field private subscribers fun(state: DetailsServiceState)[]
local DetailsService = {}
DetailsService.__index = DetailsService

---@return DetailsService
function DetailsService.new()
  local self = setmetatable({
    state = {
      selected_node = nil,
      scroll_offset = 0,
    },
    subscribers = {},
  }, DetailsService)
  return self
end

---@private
function DetailsService:_notify()
  for _, cb in ipairs(self.subscribers) do
    cb(self.state)
  end
end

---Update state from NavigationService state
---@param nav_state NavigationServiceState
function DetailsService:update_from_navigation(nav_state)
  if self.state.selected_node ~= nav_state.selected_node then
    self.state.selected_node = nav_state.selected_node
    self.state.scroll_offset = 0
    self:_notify()
  end
end

---Set scroll offset
---@param offset number
function DetailsService:set_scroll_offset(offset)
  if self.state.scroll_offset ~= offset then
    self.state.scroll_offset = offset
    self:_notify()
  end
end

---Get current state
---@return DetailsServiceState
function DetailsService:get_state()
  return self.state
end

---Subscribe to state changes
---@param callback fun(state: DetailsServiceState)
---@return fun() unsubscribe
function DetailsService:subscribe(callback)
  table.insert(self.subscribers, callback)
  callback(self.state) -- Immediate callback with current state
  return function()
    for i, cb in ipairs(self.subscribers) do
      if cb == callback then
        table.remove(self.subscribers, i)
        break
      end
    end
  end
end

return DetailsService
