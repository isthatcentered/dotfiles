---@class CenteredToBufferPositionStrategy

local M = {}

local function get_buffer_size(buffer_id)
  local origin_buffer_window = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buffer_id then
      origin_buffer_window = win
      break
    end
  end
  assert(origin_buffer_window, "[PositionStrategy] No window displaying the given buffer")

  local origin_buffer_window_width = vim.api.nvim_win_get_width(origin_buffer_window)
  local origin_buffer_window_height = vim.api.nvim_win_get_height(origin_buffer_window)

  return origin_buffer_window_width, origin_buffer_window_height
end
---@param max_width integer
---@param max_height integer
---@param width_percentage integer
---@param height_percentage integer
---@return ScratchWindow.PositionStrategy
function M.new(max_width, max_height, width_percentage, height_percentage)
  return {
    get_specs = function(origin_buffer_id, target_buffer)
      local origin_buffer_window_width, origin_buffer_window_height = get_buffer_size(origin_buffer_id)

      local target_width = math.max(1, math.floor(math.min(origin_buffer_window_width * width_percentage, max_width)))
      local target_height =
        math.max(1, math.floor(math.min(origin_buffer_window_height * height_percentage, max_height)))
      local target_window_left_offset = math.floor((origin_buffer_window_width - target_width) / 2)
      local target_window_top_offset = math.floor((origin_buffer_window_height - target_height) / 2)

      return {
        border = "rounded",
        title = "Scratch",
        title_pos = "center",
        col = target_window_left_offset,
        row = target_window_top_offset,
        width = target_width,
        height = target_height,
        relative = "win",
      }
    end,
  }
end

return M
