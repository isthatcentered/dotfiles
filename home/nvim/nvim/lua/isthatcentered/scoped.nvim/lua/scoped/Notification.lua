---@class Notification
---@field notify fun(message: string, win_id?: integer)
local M = {}

local window_id = nil
local buffer_id = nil
local timer = nil

local function close_window()
  if timer then
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    timer = nil
  end

  if window_id and vim.api.nvim_win_is_valid(window_id) then
    vim.api.nvim_win_close(window_id, true)
  end
  window_id = nil

  if buffer_id and vim.api.nvim_buf_is_valid(buffer_id) then
    vim.api.nvim_buf_delete(buffer_id, { force = true })
  end
  buffer_id = nil
end

function M.notify(message, win_id)
  -- Reset timer if it exists
  if timer then
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    timer = nil
  end

  local lines = vim.split(message, "\n")
  local height = #lines
  local width = 0
  for _, line in ipairs(lines) do
    if #line > width then
      width = #line
    end
  end

  if width == 0 then width = 1 end

  -- Create buffer if needed
  if not (buffer_id and vim.api.nvim_buf_is_valid(buffer_id)) then
    buffer_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer_id })
    vim.api.nvim_set_option_value("filetype", "scoped_notification", { buf = buffer_id })
  end

  -- Update content
  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, lines)

  local parent_width = vim.o.columns
  local parent_height = vim.o.lines

  -- Center horizontally, bottom vertically.
  -- Assuming rounded border adds 2 to width and height.
  local border_adj = 2
  local margin = 2

  local col = math.max(0, math.floor((parent_width - (width + border_adj)) / 2))
  local row = math.max(0, parent_height - (height + border_adj + margin))

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  if window_id and vim.api.nvim_win_is_valid(window_id) then
    vim.api.nvim_win_set_config(window_id, opts)
  else
    window_id = vim.api.nvim_open_win(buffer_id, false, opts)
    vim.api.nvim_set_option_value("winhighlight", "Normal:Visual,FloatBorder:FloatBorder", { win = window_id })
  end

  -- Start timer
  timer = vim.loop.new_timer()
  timer:start(3000, 0, vim.schedule_wrap(function()
    close_window()
  end))
end

return M
