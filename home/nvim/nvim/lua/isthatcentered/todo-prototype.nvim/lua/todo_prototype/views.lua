-- Pure presentation: the approved board and one optional title/description sidebar.
local M = {}
M.lanes = { 'backlog', 'active', 'done' }

local function fit(text, width)
  text = text:gsub('[\r\n\t]', ' ')
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local result = ''
  for _, char in ipairs(vim.fn.split(text, '\\zs')) do
    if vim.fn.strdisplaywidth(result .. char) > width - 1 then
      break
    end
    result = result .. char
  end
  return result .. '…'
end

local function wrap(text, width)
  local result = {}
  for _, paragraph in ipairs(vim.split(text, '\n', { plain = true })) do
    local line = ''
    for word in paragraph:gmatch('%S+') do
      if line ~= '' and vim.fn.strdisplaywidth(line .. ' ' .. word) > width then
        result[#result + 1], line = line, ''
      end
      if line ~= '' then line = line .. ' ' end
      for _, char in ipairs(vim.fn.split(word, '\\zs')) do
        if vim.fn.strdisplaywidth(line .. char) > width then
          result[#result + 1], line = line, ''
        end
        line = line .. char
      end
    end
    result[#result + 1] = line
  end
  return result
end

local function row(p, text, hl, id)
  p.lines[#p.lines + 1] = fit(text or '', p.width - 1)
  p.highlights[#p.lines] = hl
  p.ids[#p.lines] = id
end

function M.build(state, columns, lines)
  local panels = {}
  local function panel(x, y, width, height, border)
    local p = {
      x = x, y = y, width = width, height = height, border = border or 'none',
      lines = {}, highlights = {}, ids = {}, marks = {}, zindex = 60,
    }
    panels[#panels + 1] = p
    return p
  end
  local width, height = math.min(160, columns - 6), math.min(38, lines - 9)
  local total_width, sidebar_width = width, nil
  if state.preview_visible and columns >= 110 then
    total_width = math.min(220, columns - 6)
    sidebar_width = math.min(64, math.floor(total_width * 0.32))
    width = total_width - sidebar_width - 4
  end
  local column_width = math.floor((width - 2) / 3)
  width = column_width * 3 + 2
  total_width = width + (sidebar_width and sidebar_width + 4 or 0)
  local x = math.floor((columns - total_width) / 2)
  local y = math.max(1, math.floor((lines - height - 7) / 2))
  panel(x - 2, y - 1, width + 2, height, 'rounded').zindex = 50
  panel(x - 3, y - 1, 1, height + 2)
  panel(x + width + 2, y - 1, 1, height + 2)
  panel(x - 1, y, 1, height).focused = state.lane == 1
  panel(x + width, y, 1, height).focused = state.lane == 3
  local offset, selected = 0, nil
  for lane, name in ipairs(M.lanes) do
    local list = state[name]
    local p = panel(x + offset, y, column_width, height)
    p.lane, p.focused = lane, lane == state.lane
    offset = offset + column_width + 1
    row(p)
    row(p, '   ' .. name:upper() .. ' · ' .. #list, 'TodoBoardHeading')
    row(p)
    for _, task in ipairs(list) do
      local chosen = task.id == state.selected
      if chosen then selected = task end
      local prefix = (chosen and '▌ ' or '  ') .. ({ '○', '●', '✓' })[lane] .. ' '
      row(p, prefix .. task.title, chosen and 'TodoBoardSelected' or nil, task.id)
      p.marks[#p.marks + 1] = {
        line = #p.lines, bytes = #prefix,
        hl = chosen and 'TodoBoardMarker' or (lane == 1 and 'TodoBoardMuted' or 'TodoBoardAccent'),
      }
      row(p)
    end
    if #list == 0 then row(p, '   + a to add', 'TodoBoardMuted') end
    if lane < 3 then
      local divider = panel(x + offset - 1, y - 1, 1, height + 2)
      for i = 1, height + 2 do
        divider.lines[i], divider.highlights[i] = '│', 'TodoBoardRule'
      end
      divider.lines[1], divider.lines[height + 2] = '┬', '┴'
    end
  end
  if state.preview_visible then
    local preview_width = sidebar_width or math.min(44, math.floor(columns * 0.48))
    local preview_x = sidebar_width and x + width + 4 or columns - preview_width - 3
    local p = panel(preview_x, y - 1, preview_width, height, 'rounded')
    p.preview, p.focused, p.zindex = true, true, 80
    local padding = preview_width >= 40 and 3 or 1
    row(p)
    local title = selected and ('#%.0f - %s'):format(selected.id, selected.title) or 'No task selected'
    for _, line in ipairs(wrap(title, preview_width - 2 * padding - 1)) do
      row(p, string.rep(' ', padding) .. line, 'TodoBoardHeading')
    end
    row(p)
    if selected then
      for _, line in ipairs(wrap(selected.description, preview_width - 2 * padding - 1)) do
        row(p, string.rep(' ', padding) .. line)
      end
    end
    row(p)
  end
  local footer_width = math.min(columns - 6, math.max(width, 98))
  local footer = panel(math.floor((columns - footer_width) / 2), y + height + 2, footer_width, 1)
  row(footer, ' p preview   h/l column   j/k task   H/L move   a add   e edit   d delete   ? help   q close', 'TodoBoardMuted')
  return panels
end

M.fit = fit
return M
