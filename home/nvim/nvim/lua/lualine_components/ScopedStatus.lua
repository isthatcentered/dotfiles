local scoped_instance = require('scoped').instance()
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
  -- assert(options.is_active ~= nil, 'is_active must be defined')
  -- self.is_active = options.is_active
end

function M:apply_highlight(str, hl)
  return string.format('%%#%s#%s%%*', hl, str)
end

function M:update_status()
  local buffer_id = vim.api.nvim_get_current_buf()
  local bound_list_name = scoped_instance:get_bound_list_name(vim.api.nvim_get_current_win())
  local is_file_bound_to_list = scoped_instance:is_current_file_bound_to_current_list()
  if bound_list_name  then
    return '[' .. bound_list_name .. ' ' .. (is_file_bound_to_list and '✓' or '✗') .. ']'
  end

  return ''

  -- return self:apply_highlight('PENDING', HIGHLIGHTS.pending)
end

return M
