-- Focus UI. Durable task changes go through the application session/repository.
local M = {}
local api = vim.api
local views = require 'todo_prototype.views'
local repository = require 'todo_prototype.repository'
local sessions = require 'todo_prototype.session'
local session
local drafts = {}
local ns = api.nvim_create_namespace 'todo_prototype'
local state = { triaged = {}, backlog = {}, done = {}, discarded = {}, selected = nil, preview_visible = true, screen = 'queue', screen_selected = {} }
local windows, buffers, panes = {}, {}, {}
local origin, editor, opened, rendering = nil, nil, false, false
local editor_draft
local group = api.nvim_create_augroup('TodoPrototype', { clear = true })

local function project()
  state.triaged, state.backlog, state.done, state.discarded = {}, {}, {}, {}
  local tasks = session:tasks()
  for _, task in ipairs(tasks) do
    table.insert(state[task.status.kind], task)
  end
end

local function change(action, id, value)
  local selected_id, err = session:change(action, id, value)
  if not selected_id then
    vim.notify('Tasks were not saved: ' .. err, vim.log.levels.ERROR)
    return nil
  end
  project()
  return selected_id
end

local function selected()
  for _, lane in ipairs { 'triaged', 'backlog', 'done', 'discarded' } do
    for i, t in ipairs(state[lane]) do
      if t.id == state.selected then
        return t, state[lane], i
      end
    end
  end
end

local function visible_tasks()
  local result = {}
  for _, lane in ipairs(state.screen == 'queue' and { 'triaged', 'backlog' } or { state.screen }) do
    for _, t in ipairs(state[lane]) do
      result[#result + 1] = t
    end
  end
  return result
end

local function select_visible(index)
  local tasks = visible_tasks()
  for _, t in ipairs(tasks) do
    if t.id == state.selected then
      return
    end
  end
  local next_task = tasks[math.min(index or 1, #tasks)]
  state.selected = next_task and next_task.id or nil
end

local function switch_screen()
  if editor then
    return
  end
  state.screen_selected[state.screen] = state.selected
  state.screen = views.next_screen[state.screen]
  state.selected = state.screen_selected[state.screen]
  select_visible()
  M.render()
end

local function transition(action)
  local t = selected()
  if not t then
    return
  end
  local visible_index = 1
  for i, task in ipairs(visible_tasks()) do
    if task.id == t.id then
      visible_index = i
    end
  end
  if change(action, t.id) then
    select_visible(visible_index)
    M.render()
  end
end

local function toggle_done()
  transition 'done'
end

local function toggle_discarded()
  transition 'discard'
end

local function colors()
  api.nvim_set_hl(0, 'TodoProtoTitle', { default = true, bold = true })
  for name, link in pairs {
    Text = 'NormalFloat',
    Muted = 'Comment',
    Accent = 'Title',
    Border = 'FloatBorder',
    Selected = 'PmenuSel',
    Done = 'DiagnosticOk',
  } do
    api.nvim_set_hl(0, 'TodoProto' .. name, { default = true, link = link })
  end
end

local function clean_windows()
  for _, win in ipairs(windows) do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
  for _, buf in ipairs(buffers) do
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_delete(buf, { force = true })
    end
  end
  windows, buffers, panes = {}, {}, {}
end

function M.close(restore_focus)
  if editor and restore_focus ~= false then
    return
  end
  opened = false
  if editor then
    editor_draft = { is_new = editor.is_new, id = editor.id, lane = editor.lane, lines = api.nvim_buf_get_lines(editor.buf, 0, -1, false) }
    api.nvim_win_close(editor.win, true)
  end
  if session then
    drafts[session.path] = editor_draft
  end
  clean_windows()
  if restore_focus ~= false and origin and api.nvim_win_is_valid(origin) then
    api.nvim_set_current_win(origin)
  end
end

local function close_after_buffer_switch(win)
  local destination = api.nvim_win_get_buf(win)
  local cursor = api.nvim_win_get_cursor(win)
  local target = origin
  if not target or not api.nvim_win_is_valid(target) or api.nvim_win_get_tabpage(target) ~= api.nvim_get_current_tabpage() then
    for _, candidate in ipairs(api.nvim_tabpage_list_wins(0)) do
      if api.nvim_win_get_config(candidate).relative == '' then
        target = candidate
        break
      end
    end
  end
  -- Display the destination before closing the float so its buffer stays visible.
  api.nvim_win_set_buf(target, destination)
  M.close(false)
  api.nvim_set_current_win(target)
  api.nvim_win_set_cursor(target, cursor)
end

local function navigate(delta)
  local tasks = visible_tasks()
  if #tasks == 0 then
    return
  end
  local index = 1
  for i, t in ipairs(tasks) do
    if t.id == state.selected then
      index = i
    end
  end
  state.selected = tasks[(index - 1 + delta) % #tasks + 1].id
  M.render()
end

local function reorder(delta)
  if state.selected and change('reorder', state.selected, delta) then
    M.render()
  end
end

local function move()
  if state.selected and change('move', state.selected) then
    M.render()
  end
end

local function edit(is_new, draft_lines, draft_lane)
  if editor then
    return
  end
  local t = selected()
  if not is_new and not t then
    return
  end
  local lane = draft_lane or (t and (t.status.kind == 'triaged' or t.status.kind == 'backlog') and t.status.kind or 'backlog')
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'markdown'
  api.nvim_buf_set_name(buf, 'todo-prototype://edit/' .. (is_new and 'new' or t.id))
  local lines = draft_lines or (is_new and { '', '' } or vim.list_extend({ t.title, '' }, vim.split(t.description, '\n', { plain = true })))
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = draft_lines ~= nil
  local width, height = math.min(78, vim.o.columns - 6), math.min(16, vim.o.lines - 6)
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    zindex = 80,
    title = is_new and (' New task → ' .. lane .. ' ') or ' Edit task ',
    footer = ' Title on line 1 · description below · :w save · q cancel (normal mode) ',
  })
  editor = { win = win, buf = buf, is_new = is_new, id = t and t.id, lane = lane }
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  local function cancel()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
  local function save()
    local content = api.nvim_buf_get_lines(buf, 0, -1, false)
    local title = vim.trim(content[1] or '')
    if title == '' then
      vim.notify('Give this task a title.', vim.log.levels.INFO)
      return
    end
    table.remove(content, 1)
    if content[1] == '' then
      table.remove(content, 1)
    end
    local id = change(is_new and 'add' or 'edit', t and t.id, { title = title, description = table.concat(content, '\n'), lane = lane })
    if not id then
      return
    end
    if is_new then
      state.screen = 'queue'
    end
    state.selected = id
    vim.bo[buf].modified = false
    cancel()
  end
  api.nvim_create_autocmd('BufWriteCmd', { group = group, buffer = buf, nested = true, callback = save })
  api.nvim_create_autocmd('WinClosed', {
    group = group,
    pattern = tostring(win),
    once = true,
    callback = function()
      editor = nil
      vim.schedule(function()
        if opened then
          M.render()
        end
      end)
    end,
  })
  vim.keymap.set({ 'n', 'i' }, '<C-s>', function()
    vim.cmd.stopinsert()
    save()
  end, { buffer = buf, desc = 'Save task' })
  vim.keymap.set('n', '<Esc>', cancel, { buffer = buf, desc = 'Cancel task edit' })
  vim.keymap.set('n', 'q', cancel, { buffer = buf, nowait = true, desc = 'Close task editor without saving' })
  if is_new then
    vim.cmd.startinsert()
  end
end

local function mappings(buf)
  local function map(key, callback, desc)
    vim.keymap.set('n', key, callback, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  map('q', M.close, 'Close prototype')
  map('<Esc>', M.close, 'Close prototype')
  map('<C-p>', function()
    state.preview_visible = not state.preview_visible
    M.render()
  end, 'Toggle preview')
  map('j', function()
    navigate(vim.v.count1)
  end, 'Next task')
  map('k', function()
    navigate(-vim.v.count1)
  end, 'Previous task')
  map('<Down>', function()
    navigate(1)
  end, 'Next task')
  map('<Up>', function()
    navigate(-1)
  end, 'Previous task')
  map('J', function()
    reorder(1)
  end, 'Move task down')
  map('K', function()
    reorder(-1)
  end, 'Move task up')
  map('m', move, 'Move between triaged and backlog')
  map('x', toggle_done, 'Complete task / restore from Done')
  map('a', function()
    edit(true)
  end, 'Add task')
  map('<CR>', function()
    edit(false)
  end, 'Edit title and description')
  map('e', function()
    edit(false)
  end, 'Edit title and description')
  map('gg', function()
    local ts = visible_tasks()
    state.selected = ts[1] and ts[1].id
    M.render()
  end, 'First task')
  map('G', function()
    local ts = visible_tasks()
    state.selected = ts[#ts] and ts[#ts].id
    M.render()
  end, 'Last task')
  for key, lane in pairs { h = 'triaged', l = 'backlog' } do
    map(key, function()
      if state[lane][1] then
        state.screen = 'queue'
        state.selected = state[lane][1].id
        M.render()
      end
    end, 'Select ' .. lane)
  end
  map('<LeftRelease>', function()
    local win = api.nvim_get_current_win()
    for _, p in ipairs(panes) do
      if p.win == win then
        state.selected = p.ids[api.nvim_win_get_cursor(win)[1]] or state.selected
        M.render()
        return
      end
    end
  end, 'Select task under mouse')
  map('?', function()
    vim.notify(table.concat({
      'TODO UI PROTOTYPE — tasks saved to todo.jsonl',
      'j/k: select task across lists; h/l: triaged/backlog; gg/G: first/last',
      'J/K: reorder within the list; m: move to the end of the other list',
      'Tab in queue: Queue / Done / Discarded; x: complete / restore from Done',
      'd in queue: discard / restore from Discarded; a: add; Enter/e: edit',
      'Ctrl-p: toggle preview (shown when opening the queue)',
      'Editor: :w or Ctrl-s saves; :q! or normal-mode q / Esc cancels',
      'Ctrl-w w: focus another pane; Ctrl-d/u: scroll; q: close',
      'Moving to another window or buffer closes the manager; unfinished edits resume on reopening',
    }, '\n'))
  end, 'Show help')
end

local function window(config, lines, focusable)
  local buf = api.nvim_create_buf(false, true)
  buffers[#buffers + 1] = buf
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'todo_prototype'
  api.nvim_buf_set_lines(buf, 0, -1, false, #lines > 0 and lines or { '' })
  vim.bo[buf].modifiable = false
  config.relative, config.style, config.focusable = 'editor', 'minimal', focusable
  config.zindex = 50
  local win = api.nvim_open_win(buf, false, config)
  windows[#windows + 1] = win
  vim.wo[win].winhighlight = 'Normal:NormalFloat,FloatBorder:TodoProtoBorder'
  vim.wo[win].wrap = false
  vim.wo[win].scrolloff = 2
  vim.wo[win].sidescrolloff = 0
  vim.wo[win].cursorline = false
  if focusable then
    mappings(buf)
  end
  return win, buf
end

function M.render()
  if not opened or editor or rendering then
    return
  end
  if vim.o.columns < 60 or vim.o.lines < 18 then
    M.close()
    vim.notify('Focus needs at least 60 columns × 18 rows.', vim.log.levels.INFO)
    return
  end
  rendering = true
  select_visible()
  clean_windows()
  colors()
  local width, height = math.min(114, vim.o.columns - 6), math.min(32, vim.o.lines - 10)
  local x = math.floor((vim.o.columns - width) / 2)
  local y = math.max(0, math.floor((vim.o.lines - height - 8) / 2))
  local header = {
    'FOCUS / ' .. state.screen,
    views.fit(('PROTOTYPE · %d triaged / %d backlog / %d done / %d discarded'):format(#state.triaged, #state.backlog, #state.done, #state.discarded), width),
  }
  window({ row = y, col = x, width = width, height = 2, border = 'none' }, header, false)
  panes = views.build(state, width, height)
  local target, target_row
  for _, p in ipairs(panes) do
    p.win, p.buf =
      window({ row = y + 3 + p.y, col = x + p.x, width = p.w, height = p.h, border = 'rounded', title = views.fit(p.title, p.w - 2) }, p.lines, true)
    if not p.detail then
      vim.keymap.set('n', '<Tab>', switch_screen, { buffer = p.buf, nowait = true, desc = 'Switch Queue / Done / Discarded' })
      vim.keymap.set('n', 'd', toggle_discarded, { buffer = p.buf, nowait = true, desc = 'Discard task / restore from Discarded' })
    end
    for row, text in ipairs(p.lines) do
      local hl = p.highlights[row]
      if hl then
        api.nvim_buf_set_extmark(p.buf, ns, row - 1, 0, { end_col = #text, hl_group = hl, hl_eol = p.ids[row] == state.selected })
      end
      if not p.detail and p.ids[row] == state.selected and not target then
        target, target_row = p.win, row
      end
    end
  end
  window({ row = y + height + 5, col = x, width = width, height = 2, border = 'none' }, {
    views.fit(
      'Tab: '
        .. views.next_screen[state.screen]
        .. '  '
        .. (
          state.screen == 'discarded' and 'd: restore  j/k: task  J/K: reorder  a: add  Enter: edit  ?: help  q: close'
          or (state.screen == 'done' and 'x: restore' or 'x: done') .. '  d: discard  j/k: task  J/K: reorder  a: add  Enter: edit  ?: help  q: close'
        ),
      width
    ),
    views.fit('Ctrl-p: ' .. (state.preview_visible and 'hide' or 'show') .. ' preview', width),
  }, false)
  api.nvim_set_current_win(target or panes[1].win)
  if target then
    api.nvim_win_set_cursor(target, { target_row, 0 })
    api.nvim_win_call(target, function()
      vim.cmd 'normal! zz'
    end)
  end
  rendering = false
end

function M.open()
  if editor then
    return
  end
  if not opened then
    local next_session, err = sessions.open(repository.new(vim.fn.getcwd()))
    if not next_session then
      vim.notify('Cannot open tasks: ' .. err, vim.log.levels.ERROR)
      return
    end
    local same_project = session and session.path == next_session.path
    session = next_session
    project()
    if not same_project then
      state.selected, state.screen, state.screen_selected = nil, 'queue', {}
    end
    editor_draft = drafts[session.path]
    origin = api.nvim_get_current_win()
    state.preview_visible = true
  end
  opened = true
  M.render()
  if opened and editor_draft then
    local draft = editor_draft
    editor_draft, drafts[session.path] = nil, nil
    if draft.id then
      state.selected = draft.id
    end
    if not draft.is_new and not selected() then
      -- Keep the text editable if the original task was deleted externally.
      draft.is_new = true
    end
    edit(draft.is_new, draft.lines, draft.lane)
  end
end

function M.toggle()
  if opened then
    M.close(false)
    if origin and api.nvim_win_is_valid(origin) then
      api.nvim_set_current_win(origin)
    end
  else
    M.open()
  end
end

function M.setup()
  colors()
  vim.keymap.set('n', '<leader>TT', M.toggle, { desc = 'Toggle to-do manager' })
  api.nvim_create_user_command('TodoPrototype', function()
    M.open()
  end, { desc = 'Open the Focus to-do queue' })
  api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = function()
      vim.schedule(M.render)
    end,
  })
  api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
    group = group,
    callback = function()
      if not opened or rendering then
        return
      end
      -- Window creation and redraw briefly change focus; inspect the final destination.
      vim.schedule(function()
        if not opened or rendering then
          return
        end
        local current = api.nvim_get_current_win()
        if editor and current == editor.win then
          return
        end
        for _, pane in ipairs(panes) do
          if current == pane.win and api.nvim_win_get_buf(current) ~= pane.buf then
            close_after_buffer_switch(current)
            return
          end
        end
        for _, win in ipairs(windows) do
          if current == win then
            return
          end
        end
        M.close(false)
      end)
    end,
  })
end

return M
