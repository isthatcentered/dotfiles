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
  it('creates the file on opening and persists actual edit, move, done and discard mappings', function()
    local directory = tempdir()
    open(directory)
    eq(read(directory .. '/todo.jsonl'), '')
    key 'a'
    edit { 'My title', '', 'A description', 'with two lines' }
    local function loaded()
      return assert(repositories.new(directory):load())
    end
    eq(loaded()[1].title, 'My title')
    eq(loaded()[1].description, 'A description\nwith two lines')
    key 'm'
    eq(loaded()[1].status.kind, 'triaged')
    key 'e'
    edit { 'New title', '', 'New description' }
    eq(loaded()[1].title, 'New title')
    key 'x'
    eq(loaded()[1].status.kind, 'done')
    key '<Tab>'
    key 'd'
    eq(loaded()[1].status.kind, 'discarded')
    close()
    todo.open()
    settle()
    key '<Tab>'
    key 'd'
    eq(loaded()[1].status.kind, 'done')
    key '<Tab>'
    key '<Tab>'
    key 'x'
    eq(loaded()[1].status.kind, 'triaged')
  end)
  it('persists queue reorder keys', function()
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
    key '<C-p>'
    key '<C-p>'
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
    key 'm'
    eq(repositories.new(a):load()[1].status.kind, 'triaged')
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
