local api = vim.api
local repositories = require 'todo_prototype.repository'
local todo = require 'todo_prototype'
local notifications = {}
vim.notify = function(message)
  notifications[#notifications + 1] = message
end
todo.setup()

local function settle()
  vim.wait(20)
end

local function key(lhs)
  local mapping = vim.fn.maparg(lhs, 'n', false, true)
  assert(type(mapping.callback) == 'function', 'missing mapping ' .. lhs)
  mapping.callback()
  vim.cmd.stopinsert()
  settle()
end

local function close()
  todo.close(false)
  settle()
end

local function open(directory, tasks)
  close()
  vim.cmd.cd(vim.fn.fnameescape(directory))
  if tasks then
    local repo = repositories.new(directory)
    assert(repo:load())
    assert(repo:save(tasks))
  end
  todo.open()
  settle()
end

local function edit(lines)
  api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.cmd.write()
  settle()
end

describe('manager persistence integration', function()
  it('keeps windows, buffers and focus stable while selecting tasks', function()
    local first, second = task(1), task(2)
    first.title, second.title = 'First task', 'Second task'
    open(tempdir(), { first, second })
    key 'p'
    local windows = api.nvim_list_wins()
    local buffers = vim.tbl_map(api.nvim_win_get_buf, windows)
    local current = api.nvim_get_current_win()
    local events = {}
    local autocmd = api.nvim_create_autocmd({ 'WinNew', 'WinClosed', 'WinEnter', 'BufEnter' }, {
      callback = function(event) events[#events + 1] = event.event end,
    })
    key 'j'
    local selected_line = api.nvim_get_current_line()
    key 'k'
    api.nvim_del_autocmd(autocmd)
    eq(api.nvim_list_wins(), windows)
    eq(vim.tbl_map(api.nvim_win_get_buf, windows), buffers)
    eq(api.nvim_get_current_win(), current)
    eq(events, {})
    assert(selected_line:find('Second task', 1, true))
    assert(api.nvim_get_current_line():find('First task', 1, true))
    for _, win in ipairs(windows) do
      local buf = api.nvim_win_get_buf(win)
      if vim.b[buf].todo_preview then
        eq(vim.trim(api.nvim_buf_get_lines(buf, 1, 2, false)[1]), '#1 - First task')
      end
    end
  end)
  it('preserves the column viewport and uses current task rows after a reorder', function()
    local tasks = {}
    for i = 1, 40 do
      tasks[i] = task(i)
      tasks[i].title = 'Task ' .. i
    end
    open(tempdir(), tasks)
    key 'G'
    key 'k'
    key 'k'
    local win = api.nvim_get_current_win()
    local topline = api.nvim_win_call(win, vim.fn.winsaveview).topline
    key 'k'
    eq(api.nvim_get_current_win(), win)
    eq(api.nvim_win_call(win, vim.fn.winsaveview).topline, topline)
    key 'gg'
    key 'J'
    -- CursorMoved must consult the updated row IDs on the reused pane.
    api.nvim_win_set_cursor(win, { 4, 0 })
    api.nvim_exec_autocmds('CursorMoved', { buffer = api.nvim_win_get_buf(win) })
    settle()
    key 'p'
    for _, pane in ipairs(api.nvim_list_wins()) do
      local buf = api.nvim_win_get_buf(pane)
      if vim.b[buf].todo_preview then
        eq(vim.trim(api.nvim_buf_get_lines(buf, 1, 2, false)[1]), '#2 - Task 2')
      end
    end
  end)
  it('persists add, edit, movement and hidden deletion through actual mappings', function()
    local directory = tempdir()
    open(directory)
    eq(read(directory .. '/todo.jsonl'), '')
    key 'a'
    edit { 'My title', '', 'A description', 'with two lines' }
    local function loaded() return assert(repositories.new(directory):load()) end
    eq(loaded()[1].title, 'My title')
    eq(loaded()[1].description, 'A description\nwith two lines')
    key 'L'
    eq(loaded()[1].status, 'active')
    key 'e'
    edit { 'New title', '', 'New description' }
    eq(loaded()[1].title, 'New title')
    key 'L'
    eq(loaded()[1].status, 'done')
    key 'd'
    eq(loaded()[1].status, 'discarded')
    for _, win in ipairs(api.nvim_list_wins()) do
      local buf = api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'todo_prototype' then
        assert(not table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), '\n'):find('New title', 1, true))
      end
    end
    key 'u'
    eq(loaded()[1].status, 'done')
    key 'd'
    close()
    todo.open()
    settle()
    eq(loaded()[1].status, 'discarded')
    key 'u' -- Undo history belongs to the prior opening.
    eq(loaded()[1].status, 'discarded')
  end)
  for lane_index, lane in ipairs { 'backlog', 'active', 'done' } do
    for _, index in ipairs { 1, 2, 3 } do
      it(('follows %s task %d to the top of the destination'):format(lane, index), function()
        local directory = tempdir()
        local destination = lane == 'done' and 'active' or (lane == 'active' and 'done' or 'active')
        local tasks = { task(4, destination), task(1, lane), task(2, lane), task(3, lane) }
        for _, t in ipairs(tasks) do t.title = 'Task ' .. t.id end
        open(directory, tasks)
        for _ = 2, lane_index do key 'l' end
        for _ = 2, index do key 'j' end
        key(lane == 'done' and 'H' or 'L')
        assert(api.nvim_get_current_line():find('Task ' .. index, 1, true))
        eq(api.nvim_win_get_cursor(0)[1], 4)
        local loaded = assert(repositories.new(directory):load())
        local destination_ids = {}
        for _, t in ipairs(loaded) do
          if t.status == destination then destination_ids[#destination_ids + 1] = t.id end
        end
        eq(destination_ids, { index, 4 })
      end)
    end
    it('adds in an empty ' .. lane .. ' column and undoes deletion there', function()
      local directory = tempdir()
      open(directory)
      for _ = 2, lane_index do key 'l' end
      key 'a'
      edit { 'New task in empty column', '', 'Its description' }
      eq(repositories.new(directory):load()[1].status, lane)
      key 'd'
      eq(vim.b.todo_lane, lane_index)
      key 'u'
      eq(repositories.new(directory):load()[1].status, lane)
      assert(api.nvim_get_current_line():find('New task', 1, true))
    end)
  end
  it('shows the ID before the title in a scrollable optional preview', function()
    local t = task()
    t.description = string.rep('Long description with 日本語 text\n', 80)
    open(tempdir(), { t })
    local function preview()
      for _, win in ipairs(api.nvim_list_wins()) do
        if vim.b[api.nvim_win_get_buf(win)].todo_preview then return win end
      end
    end
    eq(preview(), nil)
    key 'p'
    local win = assert(preview())
    local lines = api.nvim_buf_get_lines(api.nvim_win_get_buf(win), 0, -1, false)
    eq(vim.trim(lines[2]), '#1 - ' .. t.title)
    assert(lines[4]:find('Long description', 1, true))
    key '<C-d>'
    assert(api.nvim_win_get_cursor(win)[1] > 1)
    key '<C-u>'
    eq(api.nvim_win_get_cursor(win)[1], 1)
    key '<CR>'
    eq(preview(), nil)
  end)
  it('retains the saved selection and file after a conflicting delete or move', function()
    local directory = tempdir()
    open(directory, { task() })
    local repo = repositories.new(directory)
    repo:load()
    local external = task()
    external.title = 'Outside change'
    assert(repo:save { external })
    key 'd'
    key 'L'
    eq(repo:load()[1].title, 'Outside change')
    eq(repo:load()[1].status, 'backlog')
    assert(api.nvim_get_current_line():find('A task', 1, true))
    eq(vim.b.todo_lane, 1)
  end)
  it('persists column reorder keys', function()
    local directory = tempdir()
    open(directory, { task(1), task(2), task(3) })
    key 'J'
    eq(
      vim.tbl_map(function(t)
        return t.id
      end, assert(repositories.new(directory):load())),
      { 2, 1, 3 }
    )
    key 'K'
    eq(
      vim.tbl_map(function(t)
        return t.id
      end, assert(repositories.new(directory):load())),
      { 1, 2, 3 }
    )
  end)
  it('does not write when navigating, toggling preview or cancelling edits', function()
    local directory = tempdir()
    open(directory, { task(1), task(2) })
    local before = read(directory .. '/todo.jsonl')
    local stat = vim.uv.fs_stat(directory .. '/todo.jsonl')
    key 'j'
    key 'p'
    key 'p'
    key 'e'
    api.nvim_buf_set_lines(0, 0, -1, false, { 'Cancelled edit' })
    key 'q'
    eq(read(directory .. '/todo.jsonl'), before)
    eq(vim.uv.fs_stat(directory .. '/todo.jsonl').mtime, stat.mtime)
    eq(vim.bo.filetype, 'todo_prototype')
  end)
  it('keeps the editor and original task on write conflict', function()
    local directory = tempdir()
    open(directory, { task() })
    key 'e'
    local external = task()
    external.title = 'Changed elsewhere'
    local repo = repositories.new(directory)
    repo:load()
    assert(repo:save { external })
    edit { 'My unsaved edit', '', 'Keep this draft' }
    eq(vim.bo.filetype, 'markdown')
    eq(vim.bo.modified, true)
    eq(api.nvim_buf_get_lines(0, 0, -1, false)[1], 'My unsaved edit')
    eq(repo:load()[1].title, 'Changed elsewhere')
    -- Reopening reloads disk while preserving the draft for an explicit retry.
    close()
    todo.open()
    settle()
    eq(vim.bo.filetype, 'markdown')
    vim.cmd.write()
    settle()
    eq(repo:load()[1].title, 'My unsaved edit')
  end)
  it('keeps drafts separate across working directories', function()
    local a, b = tempdir(), tempdir()
    open(a, { task() })
    key 'e'
    api.nvim_buf_set_lines(0, 0, -1, false, { 'Draft for A' })
    open(b)
    eq(vim.bo.filetype, 'todo_prototype')
    eq(read(b .. '/todo.jsonl'), '')
    open(a)
    eq(vim.bo.filetype, 'markdown')
    eq(api.nvim_buf_get_lines(0, 0, -1, false)[1], 'Draft for A')
    key 'q'
    eq(repositories.new(a):load()[1].title, 'A task')
  end)
  it('returns to the draft task column after visiting another project', function()
    local a, b = tempdir(), tempdir()
    open(a, { task(1), task(2, 'active') })
    key 'l'
    key 'e'
    api.nvim_buf_set_lines(0, 0, -1, false, { 'Active task draft' })
    open(b)
    open(a)
    eq(vim.bo.filetype, 'markdown')
    vim.cmd.write()
    settle()
    eq(vim.b.todo_lane, 2)
    assert(api.nvim_get_current_line():find('Active task draft', 1, true))
  end)
  it('uses window-local cwd and never searches ancestors', function()
    close()
    local parent = tempdir()
    local child = parent .. '/nested'
    vim.fn.mkdir(child)
    vim.cmd.cd(vim.fn.fnameescape(parent))
    vim.cmd.lcd(vim.fn.fnameescape(child))
    todo.open()
    settle()
    eq(read(child .. '/todo.jsonl'), '')
    eq(vim.uv.fs_stat(parent .. '/todo.jsonl'), nil)
  end)
  it('pins writes to the directory captured on open until the next opening', function()
    local a, b = tempdir(), tempdir()
    open(a, { task() })
    vim.cmd.cd(vim.fn.fnameescape(b))
    key 'L'
    eq(repositories.new(a):load()[1].status, 'active')
    eq(vim.uv.fs_stat(b .. '/todo.jsonl'), nil)
    close()
    todo.open()
    settle()
    eq(read(b .. '/todo.jsonl'), '')
  end)
  it('does not open the manager or overwrite a corrupt file', function()
    local directory = tempdir()
    write(directory .. '/todo.jsonl', 'corrupt')
    open(directory)
    assert(vim.bo.filetype ~= 'todo_prototype')
    eq(read(directory .. '/todo.jsonl'), 'corrupt')
    assert(notifications[#notifications]:find('todo.jsonl:1:', 1, true))
  end)
  it('still closes when changing a buffer or focusing an external window', function()
    open(tempdir(), { task() })
    local ordinary
    for _, win in ipairs(api.nvim_list_wins()) do
      if api.nvim_win_get_config(win).relative == '' then
        ordinary = win
      end
    end
    api.nvim_set_current_win(ordinary)
    settle()
    for _, win in ipairs(api.nvim_list_wins()) do
      eq(api.nvim_win_get_config(win).relative, '')
    end
    todo.open()
    settle()
    local destination = api.nvim_create_buf(true, false)
    api.nvim_win_set_buf(0, destination)
    settle()
    eq(api.nvim_get_current_win(), ordinary)
    eq(api.nvim_get_current_buf(), destination)
    for _, win in ipairs(api.nvim_list_wins()) do
      eq(api.nvim_win_get_config(win).relative, '')
    end
  end)
end)
close()
