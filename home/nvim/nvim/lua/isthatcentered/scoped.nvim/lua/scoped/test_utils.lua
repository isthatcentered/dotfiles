local utils = require("scoped.utils")

---@class Buffer
---@field id integer
---@field is_file boolean
---@field name string?
---@field contents string[]
local Buffer = {}
Buffer.__index = Buffer

---@param buffer_id integer
---@return Buffer
function Buffer.new(buffer_id)
  local filetype = vim.api.nvim_get_option_value("buftype", { buf = buffer_id })
  local filename = vim.api.nvim_buf_get_name(buffer_id)
  local contents = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)

  return setmetatable({
    id = buffer_id,
    is_file = filetype == "" and filename ~= "",
    name = filename,
    contents = contents,
  }, Buffer)
end

function Buffer:ensure_valid_file()
  local filetype = vim.fn.getftype(self.name)

  if filetype == "file" then
    return
  end

  error("Not a valid file: " .. self.name)
end

---@class Window
---@field id integer
---@field buffer Buffer
local Window = {}
Window.__index = Window

---@param window_id integer
---@return Window
function Window.new(window_id)
  return setmetatable({
    id = window_id,
    buffer = Buffer.new(vim.api.nvim_win_get_buf(window_id)),
  }, Window)
end

local M = {}

function M.print(...)
  vim.print({ "🛑", ... })
end

---@return {buffers : Buffer[], windows: Window[], current_window: Window}
function M.get_editor_snapshot()
  ---@type Buffer[]
  local buffers = vim.tbl_map(function(buffer_id)
    return Buffer.new(buffer_id)
  end, vim.api.nvim_list_bufs())

  ---@type Window[]
  local windows = vim.tbl_map(function(window_id)
    return Window.new(window_id)
  end, vim.api.nvim_list_wins())

  return {
    buffers = buffers,
    windows = windows,
    total_windows = #windows,
    total_buffers = #buffers,
    current_window = Window.new(vim.api.nvim_get_current_win()),
  }
end

function M.current_buffer_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

function M.window_buffer_file_path(window_id)
  local buffer_id = vim.api.nvim_get_current_buf()

  local buffer = Buffer.new(buffer_id)
  buffer:ensure_valid_file()

  return buffer.name
end
function M.current_opened_file_path()
  local buffer_id = vim.api.nvim_get_current_buf()

  local buffer = Buffer.new(buffer_id)
  buffer:ensure_valid_file()

  return buffer.name
end

function M.list_extmarks(buffer_id, namespace)
  local extmarks = vim.api.nvim_buf_get_extmarks(buffer_id, namespace, 0, -1, { details = true })
  local transformed = vim.tbl_map(function(extmark)
    local mark = {}
    mark.start_col = extmark[3]
    mark.start_row = extmark[2]
    for key, value in pairs(extmark[4]) do
      mark[key] = value
    end
    return mark
  end, extmarks)

  return transformed
end

function M.open_file_in_current_window(file_path)
  vim.cmd("e " .. file_path)
  local window = Window.new(vim.api.nvim_get_current_win())
  window.buffer:ensure_valid_file()
  return window
end

function M.open_file_in_new_split(file_path)
  vim.cmd("vsplit " .. file_path)
  local window = Window.new(vim.api.nvim_get_current_win())
  window.buffer:ensure_valid_file()
  return window
end

function M.reset_editor()
  local buffers = vim.api.nvim_list_bufs()
  for _, buffer in pairs(buffers) do
    vim.api.nvim_buf_delete(buffer, { force = true })
  end

  local windows = vim.api.nvim_list_wins()
  for _, window in pairs(windows) do
    -- Keep at least one window opened (otherwise neovim rejects)
    if _ > 1 then
      vim.api.nvim_win_close(window, true)
    end
  end
end

---@return integer, integer
function M.split_window()
  local buffer_id = vim.api.nvim_create_buf(true, true)
  local window_id = vim.api.nvim_open_win(buffer_id, true, {
    split = "left",
    win = 0,
  })
  return window_id, buffer_id
end

---@param window_id integer
function M.force_close_window(window_id)
  vim.api.nvim_win_close(window_id, true)
end

---@param keys string
function M.type(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", true)
  -- local called = false
  -- vim.schedule(function()
  --   called = true
  -- end)
  -- vim.wait(1000, function()
  --   return called
  -- end, 50) -- Process pending events to trigger autocmds
end

return M
