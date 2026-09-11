local repositories = require 'todo_prototype.repository'
local sessions = require 'todo_prototype.session'
local model = require 'todo_prototype.model'

describe('JSONL repository', function()
  it('loads persisted tasks in a completely separate Neovim process', function()
    local directory = tempdir()
    local repo = repositories.new(directory)
    repo:load()
    local tasks = model.apply({ task(1), task(2) }, 'done', 2)
    tasks = model.apply(tasks, 'discard', 2)
    tasks[1].description = 'Persisted across processes\n日本語'
    assert(repo:save(tasks))
    local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
    local script = directory .. '/restart.lua'
    write(
      script,
      ('vim.opt.runtimepath:prepend(%q)\nlocal r = require("todo_prototype.repository").new(%q)\nlocal t = assert(r:load())\nassert(vim.deep_equal(t, vim.json.decode(%q)))\nassert(r:save(require("todo_prototype.model").apply(t, "discard", 2)))\nvim.cmd("qa!")'):format(
        root,
        directory,
        vim.json.encode(tasks)
      )
    )
    local result = vim.system({ vim.v.progpath, '--headless', '-u', 'NONE', '-l', script }, { text = true }):wait(10000)
    eq(result.code, 0)
    eq(model.find(assert(repo:load()), 2).status.kind, 'done')
  end)
  it('creates an empty todo.jsonl only in the exact directory', function()
    local parent = tempdir()
    local child = parent .. '/whatever'
    vim.fn.mkdir(child)
    local a, b = repositories.new(parent), repositories.new(child)
    eq(a:load(), {})
    assert(a:save { task() })
    eq(b:load(), {})
    eq(read(child .. '/todo.jsonl'), '')
    eq(#a:load(), 1)
  end)
  it('round-trips Unicode, quotes, backslashes and multiline descriptions as one line', function()
    local repo = repositories.new(tempdir())
    repo:load()
    local t = task()
    t.title, t.description = 'é 日本語 "todo"', 'first\nsecond\r\n\\path\tend'
    assert(repo:save { t })
    eq(#vim.fn.readfile(repo.path), 1)
    eq(repositories.new(vim.fn.fnamemodify(repo.path, ':h')):load(), { t })
  end)
  it('persists every domain action and restoration metadata across fresh repositories', function()
    local directory = tempdir()
    local session = assert(sessions.open(repositories.new(directory)))
    for i = 1, 3 do
      assert(session:change('add', nil, { title = 'Task ' .. i, description = '' }))
    end
    for _, command in ipairs {
      { 'move', 2 },
      { 'move', 3 },
      { 'reorder', 3, -1 },
      { 'edit', 3, { title = 'Changed', description = 'line 1\nline 2' } },
      { 'done', 3 },
      { 'discard', 3 },
      { 'discard', 3 },
      { 'done', 3 },
    } do
      assert(session:change(unpack(command)))
      local expected = session:tasks()
      session = assert(sessions.open(repositories.new(directory)))
      eq(session:tasks(), expected)
    end
    local ids = {}
    for _, t in ipairs(session:tasks()) do
      if t.status.kind == 'triaged' then
        ids[#ids + 1] = t.id
      end
    end
    eq(ids, { 3, 2 })
  end)
  it('reads CRLF, blank lines and a missing final newline', function()
    local directory = tempdir()
    write(directory .. '/todo.jsonl', '\r\n' .. vim.json.encode(task()) .. '\r\n  \n' .. vim.json.encode(task(2)))
    eq(repositories.new(directory):load(), { task(), task(2) })
  end)
  local invalid_rows = {
    '{',
    'null',
    '[]',
    'true',
    '"hello"',
    '{}',
    '{"version":2,"id":1,"title":"A","description":"","status":{"kind":"backlog"}}',
    '{"version":1,"id":1,"title":"A","description":null,"status":{"kind":"backlog"}}',
    '{"version":1,"id":-1,"title":"A","description":"","status":{"kind":"backlog"}}',
    '{"version":1,"id":1.5,"title":"A","description":"","status":{"kind":"backlog"}}',
    '{"version":1,"id":1,"title":" ","description":"","status":{"kind":"backlog"}}',
    '{"version":1,"id":1,"title":"A","description":"","status":{"kind":"done"}}',
    '{"version":1,"id":1,"title":"A","description":"","status":{"kind":"backlog"},"unexpected_field":true}',
    vim.json.encode(task()), -- duplicate ID on line 2
  }
  for index, row in ipairs(invalid_rows) do
    it('rejects malformed record ' .. index .. ' without modifying any bytes', function()
      local directory = tempdir()
      local repo = repositories.new(directory)
      local original = vim.json.encode(task()) .. '\n' .. row .. '\n'
      write(repo.path, original)
      local tasks, err = repo:load()
      eq(tasks, nil)
      assert(err:find('todo.jsonl:2:', 1, true), err)
      eq(repo:save {}, nil)
      eq(read(repo.path), original)
    end)
  end
  it('validates writes and refuses duplicate IDs', function()
    local repo = repositories.new(tempdir())
    repo:load()
    eq(repo:save { task(), task() }, nil)
    eq(read(repo.path), '')
  end)
  it('detects concurrent sessions and allows reload before retrying', function()
    local directory = tempdir()
    local a, b = repositories.new(directory), repositories.new(directory)
    a:load()
    b:load()
    assert(a:save { task() })
    local ok, err = b:save { task(2) }
    eq(ok, nil)
    assert(err:find('changed outside', 1, true))
    eq(b:load(), { task() })
    assert(b:save { task(), task(2) })
    eq(a:load(), { task(), task(2) })
  end)
  it('does not recreate a file deleted while the manager is open', function()
    local repo = repositories.new(tempdir())
    repo:load()
    vim.fn.delete(repo.path)
    eq(repo:save { task() }, nil)
    eq(vim.uv.fs_stat(repo.path), nil)
  end)
  it('refuses an existing writer lock without removing it', function()
    local repo = repositories.new(tempdir())
    write(repo.path .. '.lock', 'another writer')
    local tasks, err = repo:load()
    eq(tasks, nil)
    assert(err:find('lock', 1, true))
    eq(read(repo.path .. '.lock'), 'another writer')
    eq(vim.uv.fs_stat(repo.path), nil)
  end)
  it('rejects directories and symbolic links without touching their target', function()
    local directory = tempdir()
    local repo = repositories.new(directory)
    vim.fn.mkdir(repo.path)
    eq(repo:load(), nil)
    vim.fn.delete(repo.path, 'd')
    local target = directory .. '/target'
    write(target, 'preserve me')
    assert(vim.uv.fs_symlink(target, repo.path))
    eq(repo:load(), nil)
    eq(read(target), 'preserve me')
  end)
  for _, operation in ipairs { 'fs_write', 'fs_fsync', 'fs_rename', 'fs_mkstemp' } do
    it('preserves original file and cleans up after ' .. operation .. ' failure', function()
      local directory = tempdir()
      local normal = repositories.new(directory)
      normal:load()
      assert(normal:save { task() })
      local original = read(normal.path)
      local fs = setmetatable({}, { __index = vim.uv })
      fs[operation] = function()
        return nil, 'simulated disk error'
      end
      local repo = repositories.new(directory, fs)
      assert(repo:load())
      local ok, err = repo:save { task(2) }
      eq(ok, nil)
      assert(err:find('simulated disk error', 1, true), err)
      eq(read(repo.path), original)
      eq(vim.fn.glob(repo.path .. '.tmp.*'), '')
      eq(vim.uv.fs_stat(repo.path .. '.lock'), nil)
    end)
  end
  it('handles partial writes and preserves file permissions', function()
    local directory = tempdir()
    local repo = repositories.new(directory)
    repo:load()
    assert(vim.uv.fs_chmod(repo.path, 416)) -- 0640
    local fs = setmetatable({}, { __index = vim.uv })
    fs.fs_write = function(fd, data, offset)
      return vim.uv.fs_write(fd, data:sub(1, 3), offset)
    end
    repo = repositories.new(directory, fs)
    repo:load()
    assert(repo:save { task() })
    eq(repo:load(), { task() })
    eq(vim.uv.fs_stat(repo.path).mode % 512, 416)
  end)
  it('reports permission errors on read without changing the file', function()
    local directory = tempdir()
    local repo = repositories.new(directory)
    repo:load()
    local fs = setmetatable({}, { __index = vim.uv })
    fs.fs_open = function(path, flags, mode)
      if path == repo.path then
        return nil, 'EACCES: permission denied'
      end
      return vim.uv.fs_open(path, flags, mode)
    end
    local tasks, err = repositories.new(directory, fs):load()
    eq(tasks, nil)
    assert(err:find('EACCES', 1, true))
    eq(read(repo.path), '')
  end)
  it('cleans up a failed initial creation and can retry opening', function()
    local directory = tempdir()
    local fs = setmetatable({
      fs_rename = function()
        return nil, 'EACCES'
      end,
    }, { __index = vim.uv })
    local repo = repositories.new(directory, fs)
    eq(repo:load(), nil)
    eq(vim.uv.fs_stat(repo.path), nil)
    eq(vim.fn.glob(repo.path .. '.*'), '')
    eq(repositories.new(directory):load(), {})
  end)
  it('rejects a missing parent directory without creating unrelated paths', function()
    local directory = tempdir() .. '/missing'
    eq(repositories.new(directory):load(), nil)
    eq(vim.uv.fs_stat(directory), nil)
  end)
  it('detects a zero-byte write and retains the original file', function()
    local directory = tempdir()
    local repo = repositories.new(directory)
    repo:load()
    local fs = setmetatable({
      fs_write = function()
        return 0
      end,
    }, { __index = vim.uv })
    repo = repositories.new(directory, fs)
    repo:load()
    eq(repo:save { task() }, nil)
    eq(read(repo.path), '')
    eq(vim.fn.glob(repo.path .. '.*'), '')
  end)
end)
