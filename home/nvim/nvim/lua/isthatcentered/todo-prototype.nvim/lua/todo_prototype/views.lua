-- PROTOTYPE: Focus — task queue on the left, selected task details on the right.
local M = {}

M.next_screen = { queue = 'done', done = 'discarded', discarded = 'queue' }

local function add(p, text, hl, id)
  p.lines[#p.lines + 1] = text or ''
  p.highlights[#p.lines] = hl
  p.ids[#p.lines] = id
end

local function wrap(text, width)
  local lines = {}
  for _, paragraph in ipairs(vim.split(text, '\n', { plain = true })) do
    local line = ''
    for word in paragraph:gmatch '%S+' do
      if line ~= '' and vim.fn.strdisplaywidth(line .. ' ' .. word) > width then
        lines[#lines + 1] = line
        line = ''
      end
      if line ~= '' then
        line = line .. ' '
      end
      for _, char in ipairs(vim.fn.split(word, '\\zs')) do
        if vim.fn.strdisplaywidth(line .. char) > width and line ~= '' then
          lines[#lines + 1] = line
          line = ''
        end
        line = line .. char
      end
    end
    lines[#lines + 1] = line
  end
  return lines
end

local function fit(text, width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local result = ''
  for _, char in ipairs(vim.fn.split(text, '\\zs')) do
    if vim.fn.strdisplaywidth(result .. char) > math.max(1, width - 1) then
      break
    end
    result = result .. char
  end
  return result .. '…'
end

local function panel(title, x, y, w, h)
  return { title = title, x = x, y = y, w = w, h = h, lines = {}, highlights = {}, ids = {} }
end

local function task(p, t, selected, index)
  local prefix = (selected == t.id and '▸ ' or '  ') .. (t.status.kind == 'discarded' and '[-] ' or ((t.status.kind == 'done') and '[x] ' or '[ ] '))
  if index then
    prefix = prefix .. index .. '. '
  end
  local hl = selected == t.id and 'TodoProtoSelected' or ((t.status.kind == 'done') and 'TodoProtoDone' or 'TodoProtoText')
  add(p, fit(prefix .. t.title, p.w - 1), hl, t.id)
end

local function lane(p, state, name)
  add(p, '  ' .. name:upper() .. '  ·  ' .. #state[name], 'TodoProtoAccent')
  add(p)
  if #state[name] == 0 then
    local empty = { done = '  Nothing done yet. Tab: Discarded.', discarded = '  Nothing discarded. Tab: Queue.' }
    add(p, empty[name] or '  Empty — a: add a task', 'TodoProtoMuted')
  end
  for i, t in ipairs(state[name]) do
    task(p, t, state.selected, i)
  end
end

local function detail(p, t)
  p.detail = true
  if not t then
    add(p, '  No task selected.', 'TodoProtoText')
    return
  end
  for _, line in ipairs(wrap(t.title, p.w - 4)) do
    add(p, '  ' .. line, 'TodoProtoTitle', t.id)
  end
  add(p)
  for _, line in ipairs(wrap(t.description, p.w - 4)) do
    add(p, '  ' .. line, 'TodoProtoText', t.id)
  end
end

function M.build(state, width, height)
  local selected
  for _, name in ipairs { 'triaged', 'backlog', 'done', 'discarded' } do
    for _, t in ipairs(state[name]) do
      if t.id == state.selected then
        selected = t
      end
    end
  end
  local rail = math.floor((width - 2) / 2)
  local queue = panel(' ' .. state.screen:upper() .. ' ', 0, 0, rail, height)
  if state.screen == 'queue' then
    lane(queue, state, 'triaged')
    add(queue)
    lane(queue, state, 'backlog')
  else
    lane(queue, state, state.screen)
  end
  if not state.preview_visible then
    return { queue }
  end
  local focus = panel(' FOCUS ', rail + 2, 0, rail, height)
  detail(focus, selected)
  return { queue, focus }
end

M.fit = fit
return M
