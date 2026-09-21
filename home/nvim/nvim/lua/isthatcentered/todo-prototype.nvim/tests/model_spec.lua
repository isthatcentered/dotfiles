local model = require 'todo_prototype.model'
local sessions = require 'todo_prototype.session'

describe('task model', function()
  for _, source in ipairs { 'backlog', 'active', 'done' } do
    for _, destination in ipairs { 'backlog', 'active', 'done' } do
      it('moves ' .. source .. ' to the top of ' .. destination .. ' without losing text', function()
        local original = { task(1, source), task(2, destination), task(3, destination) }
        original[1].description = 'Keep this\n日本語'
        local tasks = model.apply(original, 'move', 1, destination)
        eq(tasks[1].id, 1)
        eq(tasks[1].status, destination)
        eq(tasks[1].description, original[1].description)
        eq(original[1].status, source)
      end)
    end
  end
  it('places an interleaved moved task before existing destination tasks', function()
    local tasks = model.apply({ task(1, 'active'), task(2), task(3, 'active') }, 'move', 2, 'active')
    eq(vim.tbl_map(function(t) return t.id end, tasks), { 2, 1, 3 })
  end)
  it('reorders only within the same column', function()
    local tasks = model.apply({ task(1), task(2, 'active'), task(3) }, 'reorder', 1, 1)
    eq(vim.tbl_map(function(t) return t.id end, tasks), { 3, 2, 1 })
    tasks = model.apply(tasks, 'reorder', 1, -1)
    eq(vim.tbl_map(function(t) return t.id end, tasks), { 1, 2, 3 })
  end)
  it('keeps discarded tasks deleted across repeated discard or movement commands', function()
    local tasks = model.apply({ task() }, 'discard', 1)
    eq(tasks[1].status, 'discarded')
    eq(model.apply(tasks, 'discard', 1), tasks)
    eq(model.apply(tasks, 'move', 1, 'active'), tasks)
    eq(model.apply(tasks, 'reorder', 1, 1), tasks)
  end)
  it('ignores moves past either end of a list', function()
    local tasks = { task() }
    eq(model.apply(tasks, 'reorder', 1, -1), tasks)
    eq(model.apply(tasks, 'reorder', 1, 1), tasks)
  end)
  it('allocates IDs above deleted tasks and adds to the top of any board column', function()
    for _, lane in ipairs { 'backlog', 'active', 'done' } do
      local tasks, id = model.apply({ task(80, 'discarded'), task(2, lane) }, 'add', nil, { title = 'New', description = '', lane = lane })
      eq(id, 81)
      eq(tasks[1].id, 81)
      eq(tasks[1].status, lane)
    end
    assert(not pcall(model.apply, {}, 'add', nil, { title = 'New', description = '', lane = 'discarded' }))
    assert(not pcall(model.apply, { task() }, 'move', 1, 'triaged'))
  end)
  it('rejects exhausted or unsafe IDs without changing existing tasks', function()
    local tasks = { task(9007199254740991) }
    assert(model.validate(tasks))
    assert(not pcall(model.apply, tasks, 'add', nil, { title = 'New', description = '' }))
    assert(not pcall(model.validate_task, task(9007199254740992)))
    eq(tasks[1].id, 9007199254740991)
  end)
  for _, invalid in ipairs {
    { kind = 'backlog', restore = { kind = 'triaged' }, index = 1 },
    { kind = 'done' },
    { kind = 'done', restore = { kind = 'discarded' }, index = 1 },
    { kind = 'done', restore = { kind = 'backlog' }, index = 0 },
    { kind = 'discarded', restore = { kind = 'discarded' }, index = 1 },
    { kind = 'active' },
    'triaged',
    'deleted',
    '',
    false,
  } do
    it('rejects impossible state ' .. vim.inspect(invalid), function()
      local t = task()
      t.status = invalid
      assert(not pcall(model.validate_task, t))
    end)
  end
  it('rejects contradictory legacy flags instead of silently dropping them', function()
    local t = task()
    t.done = true
    assert(not pcall(model.validate_task, t))
  end)
end)

describe('application session', function()
  it('keeps the previous snapshot on save failure and supports retry', function()
    local fail, saves = true, 0
    local repository = {
      load = function()
        return { task() }
      end,
      save = function()
        saves = saves + 1
        if fail then
          return nil, 'disk full'
        end
        return true
      end,
    }
    local session = assert(sessions.open(repository))
    local id, err = session:change('move', 1, 'done')
    eq(id, nil)
    eq(err, 'disk full')
    eq(session:tasks(), { task() })
    fail = false
    assert(session:change('move', 1, 'done'))
    eq(session:tasks()[1].status, 'done')
    eq(saves, 2)
  end)
  it('does not save navigation-independent no-ops or expose mutable state', function()
    local saves = 0
    local session = assert(sessions.open {
      load = function()
        return { task() }
      end,
      save = function()
        saves = saves + 1
        return true
      end,
    })
    session:tasks()[1].title = 'Mutated outside session'
    eq(session:tasks()[1].title, 'A task')
    assert(session:change('reorder', 1, -1))
    eq(saves, 0)
  end)
end)

describe('session undo', function()
  it('persists undo and keeps history and current state when undo fails', function()
    local fail = false
    local saved
    local session = assert(sessions.open {
      load = function() return { task() } end,
      save = function(_, tasks)
        if fail then return nil, 'conflict' end
        saved = vim.deepcopy(tasks)
        return true
      end,
    })
    assert(session:change('discard', 1))
    fail = true
    local ok, err = session:undo()
    eq(ok, nil)
    eq(err, 'conflict')
    eq(session:tasks()[1].status, 'discarded')
    fail = false
    local restored, id = session:undo()
    eq(restored, true)
    eq(id, 1)
    eq(saved, { task() })
    eq(session:tasks(), saved)
    eq(session:undo(), nil)
  end)
end)
