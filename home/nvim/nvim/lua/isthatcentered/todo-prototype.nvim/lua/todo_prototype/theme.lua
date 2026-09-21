local api = vim.api
local M = {}

function M.apply()
  local has_acid, acid = pcall(require, 'acid')
  -- The isolated launcher has no plugins; mirror Acid's normal palette there.
  local colors = has_acid and acid.colors() or {
    white = '#ffffff', text = '#000000', gray_4 = '#5D5D5D',
    primary = '#4c0095', primary_light = '#f0ebf9', secondary = '#ffc500',
  }
  local channels = {}
  for _, offset in ipairs { 2, 4, 6 } do
    local purple = tonumber(colors.primary_light:sub(offset, offset + 1), 16)
    local white = tonumber(colors.white:sub(offset, offset + 1), 16)
    channels[#channels + 1] = math.floor(purple * 0.25 + white * 0.75 + 0.5)
  end
  local board_bg = string.format('#%02x%02x%02x', unpack(channels))
  local daylight = {
    Base = { fg = colors.text, bg = board_bg },
    Focus = { fg = colors.text, bg = colors.white },
    Heading = { fg = colors.primary, bold = true },
    Accent = { fg = colors.primary, bold = true },
    Muted = { fg = colors.gray_4 },
    Rule = { fg = colors.primary, bg = board_bg },
    Selected = { fg = colors.text, bg = colors.secondary, bold = true },
    Marker = { fg = colors.primary, bg = colors.secondary, bold = true },
  }
  for name, attributes in pairs(daylight) do
    api.nvim_set_hl(0, 'TodoBoard' .. name, attributes)
  end
end

function M.window(win, focused)
  local base = focused and 'TodoBoardFocus' or 'TodoBoardBase'
  vim.wo[win].winhighlight = 'Normal:' .. base .. ',NormalNC:' .. base
    .. ',NormalFloat:' .. base .. ',EndOfBuffer:' .. base
    .. ',FloatBorder:TodoBoardRule,FloatTitle:TodoBoardHeading'
  vim.wo[win].winblend = 0
end

return M
