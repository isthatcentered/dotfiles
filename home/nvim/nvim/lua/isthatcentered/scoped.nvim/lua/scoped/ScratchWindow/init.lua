local constants = require("scoped.constants")

---@class ScratchWindow.PositionStrategy
---@field get_specs fun(origin_buffer: integer, target_buffer: integer): vim.api.keyset.win_config

---@class ScratchWindow
---@field window_id number?
---@field position_strategy ScratchWindow.PositionStrategy
local M = {}
M.__index = M

---@class ScratchWindowConfig
---@field position_strategy ScratchWindow.PositionStrategy

---@param config ScratchWindowConfig
---@return ScratchWindow
function M.new(config)
  return setmetatable({
    position_strategy = config.position_strategy,
    window_id = nil,
  }, M)
end

---@param buffer_to_display integer
---@return boolean -- true if window was opened, false if already open
function M:open(buffer_to_display)
  local origin_buffer = vim.api.nvim_get_current_buf()

  if self:is_opened() then
    return false
  end

  local window_specs = self.position_strategy.get_specs(origin_buffer, buffer_to_display)
  local window_id = vim.api.nvim_open_win(buffer_to_display, true, window_specs)

  if window_id == 0 then
    error("Scoped: Failed to open scratch window")
  end

  self.window_id = window_id

  vim.api.nvim_create_autocmd("BufLeave", {
    group = constants.autocommands_group,
    once = true,
    callback = function()
      self:close()
    end,
  })

  return true
end

function M:close()
  if not self:is_opened() or not self.window_id or not vim.api.nvim_win_is_valid(self.window_id) then
    return
  end

  vim.api.nvim_win_close(self.window_id, false)

  self.window_id = nil
end

function M:is_opened()
  return self.window_id ~= nil
end

return M
