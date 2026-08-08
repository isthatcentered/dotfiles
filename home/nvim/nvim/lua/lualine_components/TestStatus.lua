local colors = require('acid').colors()

local HIGHLIGHTS = {
  passing = 'IsThatCenteredLualineNeotestPasing',
  failing = 'IsThatCenteredLualineNeotestFailing',
  pending = 'IsThatCenteredLualineNeotestPending',
}

---TODO: use a neotest consumer to highlight the whole satus bar

function is_test_file(buffer_id)
  if not vim.api.nvim_buf_is_valid(buffer_id) then
    return false
  end

  local buffer_name = vim.api.nvim_buf_get_name(buffer_id)

  return (string.match(buffer_name, 'spec') or string.match(buffer_name, 'test')) and true or false
end

---@return {running: number, failed: number, passed: number, total: number}?
local function get_file_test_status(bufnr)
  local neotest = require 'neotest'
  local adapters = neotest.state.adapter_ids()
  local overall_state = { running = 0, failed = 0, passed = 0, total = 0 }
  local is_attached = false

  for _, adapter_id in pairs(adapters) do
    local state = neotest.state.status_counts(adapter_id, { buffer = bufnr })
    if state then
      is_attached = true
      overall_state.running = overall_state.running + state.running
      overall_state.failed = overall_state.failed + state.failed
      overall_state.passed = overall_state.passed + state.passed
      overall_state.total = overall_state.total + state.total
    end
  end

  if not is_attached then
    return nil
  end

  return overall_state
end

local M = require('lualine.component'):extend()
local highlight = require 'lualine.highlight'

function M:init(options)
  M.super.init(self, options)
  assert(options.is_active ~= nil, 'is_active must be defined')
  self.is_active = options.is_active
  -- self.orginal_active_highlight = {
  --   lualine_x_normal = get_hl_colors 'lualine_x_normal',
  --   lualine_c_normal = get_hl_colors 'lualine_c_normal',
  -- }
  -- self.orginal_inactive_highlight = {
  --   lualine_x_inactive = get_hl_colors 'lualine_x_inactive',
  --   lualine_c_inactive = get_hl_colors 'lualine_c_inactive',
  -- }
end

function M:apply_highlight(str, hl)
  return string.format('%%#%s#%s%%*', hl, str)
end

function M:update_status()
  local buffer_id = vim.api.nvim_get_current_buf()

  if not is_test_file(buffer_id) then
    -- if self.is_active then
    --   for highlight_name, highlight_settings in pairs(self.orginal_active_highlight) do
    --     vim.api.nvim_set_hl(0, highlight_name, highlight_settings)
    --   end
    -- else
    --   for highlight_name, highlight_settings in pairs(self.orginal_inactive_highlight) do
    --     vim.api.nvim_set_hl(0, highlight_name, highlight_settings)
    --   end
    -- end
    return ''
  end

  local state = get_file_test_status(buffer_id)

  if state == nil then
    -- if self.is_active then
    --   for highlight_name, highlight_settings in pairs(self.orginal_active_highlight) do
    --     vim.api.nvim_set_hl(0, highlight_name, highlight_settings)
    --   end
    -- else
    --   for highlight_name, highlight_settings in pairs(self.orginal_inactive_highlight) do
    --     vim.api.nvim_set_hl(0, highlight_name, highlight_settings)
    --   end
    -- end
    return ''
  end

  if state.failed > 0 then
    --- TODO: reset highlights on tab change/state change
    --- TODO: Cache original highlights first
    -- if self.is_active then

    --   vim.api.nvim_set_hl(0, 'lualine_c_normal', { fg = colors.white, bg = colors.red })
    --   vim.api.nvim_set_hl(0, 'lualine_x_normal', { fg = colors.white, bg = colors.red })
    -- else
    --   vim.api.nvim_set_hl(0, 'lualine_c_inactive', { fg = colors.white, bg = colors.red })
    --   vim.api.nvim_set_hl(0, 'lualine_x_inactive', { fg = colors.white, bg = colors.red })
    -- end
    return self:apply_highlight('FAIL (' .. state.failed .. '/' .. state.total .. ')', HIGHLIGHTS.failing)
  end

  if state.running > 0 then
    return self:apply_highlight('PENDING (' .. state.running .. '/' .. state.total .. ')', HIGHLIGHTS.pending)
  end

  if state.passed > 0 then
    return self:apply_highlight('PASS (' .. state.passed .. '/' .. state.total .. ')', HIGHLIGHTS.passing)
  end

  -- We have state but nothing has happened yet
  return self:apply_highlight('PENDING', HIGHLIGHTS.pending)
end

return M
