-- Kanban manager. Durable changes go through the application session/repository.
local M = {}
local api = vim.api
local views = require 'todo_prototype.views'
local theme = require 'todo_prototype.theme'
local repository = require 'todo_prototype.repository'
local sessions = require 'todo_prototype.session'
local session
local drafts = {}
local ns = api.nvim_create_namespace 'todo_prototype'
local state = { backlog = {}, active = {}, done = {}, lane = 1, selected = nil, preview_visible = false }
local windows, buffers, panes = {}, {}, {}
local origin, editor, opened, rendering = nil, nil, false, false
local editor_draft
local group = api.nvim_create_augroup('TodoPrototype', { clear = true })

local function project()
  state.backlog, state.active, state.done = {}, {}, {}
  for _, task in ipairs(session:tasks()) do
    if state[task.status] then
      table.insert(state[task.status], task)
    end
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
  for lane, name in ipairs(views.lanes) do
    for i, task in ipairs(state[name]) do
      if task.id == state.selected then
        return task, lane, i
      end
    end
  end
end

local function visible_tasks()
  return state[views.lanes[state.lane]]
end

local function select_visible(index)
  for _, task in ipairs(visible_tasks()) do
    if task.id == state.selected then return end
  end
  local tasks = visible_tasks()
  local next_task = tasks[math.min(index or 1, #tasks)]
  state.selected = next_task and next_task.id or nil
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
  local _, _, index = selected()
  local tasks = visible_tasks()
  local task = tasks[math.max(1, math.min(#tasks, (index or 1) + delta))]
  state.selected = task and task.id or nil
  M.render()
end

local function change_lane(delta)
  state.lane = math.max(1, math.min(3, state.lane + delta))
  select_visible()
  M.render()
end

local function reorder(delta)
  if state.selected and change('reorder', state.selected, delta) then M.render() end
end

local function move(delta)
  local task, lane = selected()
  if not task or lane + delta < 1 or lane + delta > 3 then return end
  if change('move', task.id, views.lanes[lane + delta]) then
    state.lane = lane + delta
    M.render()
  end
end

local function discard()
  local task, _, index = selected()
  if task and change('discard', task.id) then
    select_visible(index)
    M.render()
  end
end

local function undo()
  local ok, id_or_error = session:undo()
  if not ok then
    if id_or_error then vim.notify('Tasks were not saved: ' .. id_or_error, vim.log.levels.ERROR) end
    return
  end
  project()
  state.selected = id_or_error
  local _, lane = selected()
  state.lane = lane or state.lane
  M.render()
end

local function scroll_preview(direction)
  for _, p in ipairs(panes) do
    if p.preview then
      local position = api.nvim_win_get_cursor(p.win)[1]
      local next_row = math.max(1, math.min(#p.lines, position + direction * math.max(1, math.floor(p.height / 2))))
      api.nvim_win_set_cursor(p.win, { next_row, 0 })
      api.nvim_win_call(p.win, function() vim.cmd('normal! zt') end)
    end
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
  local lane = draft_lane or views.lanes[state.lane]
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
    zindex = 100,
    title = is_new and (' New task → ' .. lane .. ' ') or ' Edit task ',
    footer = ' Title on line 1 · description below · :w save · q cancel (normal mode) ',
  })
  theme.window(win, true)
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
      for i, name in ipairs(views.lanes) do
        if name == lane then state.lane = i end
      end
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
  local function preview()
    state.preview_visible = not state.preview_visible
    M.render()
  end
  map('q', M.close, 'Close tasks')
  map('<Esc>', M.close, 'Close tasks')
  map('p', preview, 'Toggle preview')
  map('<CR>', preview, 'Toggle preview')
  map('<C-d>', function() scroll_preview(1) end, 'Scroll preview down')
  map('<C-u>', function() scroll_preview(-1) end, 'Scroll preview up')
  for key, delta in pairs { j = 1, k = -1, ['<Down>'] = 1, ['<Up>'] = -1 } do
    map(key, function() navigate(delta * vim.v.count1) end, 'Select task')
  end
  for key, delta in pairs { h = -1, l = 1, ['<Left>'] = -1, ['<Right>'] = 1 } do
    map(key, function() change_lane(delta) end, 'Select column')
  end
  map('gg', function() navigate(-math.huge) end, 'First task')
  map('G', function() navigate(math.huge) end, 'Last task')
  map('H', function() move(-1) end, 'Move task to left column')
  map('L', function() move(1) end, 'Move task to right column')
  map('J', function() reorder(1) end, 'Move task down')
  map('K', function() reorder(-1) end, 'Move task up')
  map('d', discard, 'Delete task')
  map('u', undo, 'Undo last task change')
  map('a', function() edit(true) end, 'Add task')
  map('e', function() edit(false) end, 'Edit title and description')
  map('<LeftRelease>', function()
    for _, p in ipairs(panes) do
      if p.lane and p.win == api.nvim_get_current_win() then
        state.lane, state.selected = p.lane, p.ids[api.nvim_win_get_cursor(p.win)[1]]
        M.render()
        return
      end
    end
  end, 'Select task under mouse')
  map('?', function()
    vim.notify(table.concat({
      'TASKS — Backlog / Active / Done',
      'h/l: column; j/k: task; gg/G: first/last; arrows also work',
      'H/L: move to top of left/right column and follow; J/K: reorder',
      'a: add in selected column; e: edit title and description',
      'd: delete (kept in file, hidden); u: undo during this opening',
      'p / Enter: preview title and description; Ctrl-d/u: scroll preview',
      'Editor: :w or Ctrl-s saves; :q! or normal-mode q / Esc cancels',
      'q / Esc: close; moving outside the manager closes it too',
      'Changes save immediately. Unfinished edits resume on reopening.',
    }, '\n'))
  end, 'Show help')
end

local function window(p)
  local buf = api.nvim_create_buf(false, true)
  buffers[#buffers + 1] = buf
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'todo_prototype'
  vim.b[buf].todo_lane = p.lane
  vim.b[buf].todo_preview = p.preview
  api.nvim_buf_set_lines(buf, 0, -1, false, #p.lines > 0 and p.lines or { '' })
  vim.bo[buf].modifiable = false
  local win = api.nvim_open_win(buf, false, {
    relative = 'editor', style = 'minimal', focusable = p.lane ~= nil or p.preview == true,
    row = p.y, col = p.x, width = p.width, height = p.height,
    border = p.border, zindex = p.zindex,
  })
  windows[#windows + 1] = win
  theme.window(win, p.focused)
  vim.wo[win].wrap = false
  vim.wo[win].scrolloff = 2
  vim.wo[win].sidescrolloff = 0
  vim.wo[win].cursorline = false
  if p.lane or p.preview then mappings(buf) end
  return win, buf
end

local function same_layout(next_panes)
  if #panes ~= #next_panes then return false end
  for i, p in ipairs(panes) do
    local next_pane = next_panes[i]
    if not api.nvim_win_is_valid(p.win) or not api.nvim_buf_is_valid(p.buf) then return false end
    for _, field in ipairs { 'x', 'y', 'width', 'height', 'border', 'zindex', 'lane', 'preview' } do
      if not vim.deep_equal(p[field], next_pane[field]) then return false end
    end
  end
  return true
end

local function update_lines(buf, before, after)
  local first, last_before, last_after = 1, #before, #after
  while first <= last_before and first <= last_after and before[first] == after[first] do first = first + 1 end
  while last_before >= first and last_after >= first and before[last_before] == after[last_after] do
    last_before, last_after = last_before - 1, last_after - 1
  end
  if first > last_before and first > last_after then return end
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, first - 1, last_before, false, vim.list_slice(after, first, last_after))
  vim.bo[buf].modifiable = false
end

function M.render()
  if not opened or editor or rendering then return end
  if vim.o.columns < 60 or vim.o.lines < 19 then
    M.close()
    vim.notify('Tasks need at least 60 columns × 19 rows.', vim.log.levels.INFO)
    return
  end
  rendering = true
  select_visible()
  local next_panes = views.build(state, vim.o.columns, vim.o.lines)
  local reuse = same_layout(next_panes)
  if not reuse then
    clean_windows()
    theme.apply()
    panes = next_panes
  end
  local target, target_row
  for i, p in ipairs(panes) do
    if reuse then
      local next_pane = next_panes[i]
      update_lines(p.buf, p.lines, next_pane.lines)
      api.nvim_buf_clear_namespace(p.buf, ns, 0, -1)
      if p.focused ~= next_pane.focused then theme.window(p.win, next_pane.focused) end
      -- Keep the pane object used by its CursorMoved callback current.
      p.lines, p.ids, p.highlights, p.marks, p.focused = next_pane.lines, next_pane.ids, next_pane.highlights, next_pane.marks, next_pane.focused
    else
      p.win, p.buf = window(p)
    end
    if p.lane == state.lane then target, target_row = p.win, 2 end
    for row, text in ipairs(p.lines) do
      if p.highlights[row] then
        api.nvim_buf_set_extmark(p.buf, ns, row - 1, 0, { end_col = #text, hl_group = p.highlights[row], hl_eol = true })
      end
      if p.lane == state.lane and p.ids[row] == state.selected then target_row = row end
    end
    for _, mark in ipairs(p.marks) do
      api.nvim_buf_set_extmark(p.buf, ns, mark.line - 1, 0, { end_col = mark.bytes, hl_group = mark.hl, priority = 110 })
    end
    if p.lane and not reuse then
      api.nvim_create_autocmd('CursorMoved', {
        group = group, buffer = p.buf,
        callback = function()
          if rendering or not opened or editor or not api.nvim_win_is_valid(p.win) or api.nvim_get_current_win() ~= p.win then return end
          local id = p.ids[api.nvim_win_get_cursor(p.win)[1]]
          if state.lane ~= p.lane or (id and id ~= state.selected) then
            state.lane, state.selected = p.lane, id
            vim.schedule(M.render)
          end
        end,
      })
    end
  end
  api.nvim_set_current_win(target)
  api.nvim_win_set_cursor(target, { target_row, 0 })
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
      state.selected, state.lane = nil, 1
    end
    editor_draft = drafts[session.path]
    origin = api.nvim_get_current_win()
    state.preview_visible = false
  end
  opened = true
  M.render()
  if opened and editor_draft then
    local draft = editor_draft
    editor_draft, drafts[session.path] = nil, nil
    if draft.id then
      state.selected = draft.id
      local _, lane = selected()
      state.lane = lane or state.lane
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
  theme.apply()
  vim.keymap.set('n', '<leader>TT', M.toggle, { desc = 'Toggle to-do manager' })
  api.nvim_create_user_command('TodoPrototype', function()
    M.open()
  end, { desc = 'Open the Kanban to-do manager' })
  api.nvim_create_autocmd('ColorScheme', { group = group, callback = theme.apply })
  api.nvim_create_autocmd('User', { group = group, pattern = 'AcidVariantChanged', callback = theme.apply })
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
            for _, pane in ipairs(panes) do
              if pane.win == current and pane.lane and pane.lane ~= state.lane then
                state.lane = pane.lane
                select_visible()
                M.render()
                break
              end
            end
            return
          end
        end
        M.close(false)
      end)
    end,
  })
end

return M
