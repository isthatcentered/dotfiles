local model = require 'todo_prototype.model'
local sessions = require 'todo_prototype.session'

describe('task model', function()
  it('moves, reorders, completes, discards and restores without losing original position', function()
    local original = { task(1), task(2), task(3) }
    local tasks = model.apply(original, 'move', 2)
    eq(model.find(tasks, 2).status, { kind = 'triaged' })
    tasks = model.apply(tasks, 'move', 2)
    tasks = model.apply(tasks, 'reorder', 2, -1)
    eq(
      vim.tbl_map(function(t)
        return t.id
      end, tasks),
      { 1, 2, 3 }
    )
    tasks = model.apply(tasks, 'done', 2)
    eq(model.find(tasks, 2).status, { kind = 'done', restore = { kind = 'backlog' }, index = 2 })
    tasks = model.apply(tasks, 'discard', 2)
    eq(model.find(tasks, 2).status.restore.kind, 'done')
    tasks = model.apply(tasks, 'discard', 2)
    tasks = model.apply(tasks, 'done', 2)
    eq(tasks, original)
    eq(original[2].status, { kind = 'backlog' })
  end)
  it('clamps restored positions after other tasks move away', function()
    local tasks = model.apply({ task(1), task(2) }, 'done', 2)
    tasks = model.apply(tasks, 'move', 1)
    tasks = model.apply(tasks, 'done', 2)
    eq(model.find(tasks, 2).status, { kind = 'backlog' })
  end)
  it('ignores completion and column moves for discarded tasks', function()
    local tasks = model.apply({ task() }, 'discard', 1)
    eq(model.apply(tasks, 'done', 1), tasks)
    eq(model.apply(tasks, 'move', 1), tasks)
  end)
  it('ignores moves past either end of a list', function()
    local tasks = { task() }
    eq(model.apply(tasks, 'reorder', 1, -1), tasks)
    eq(model.apply(tasks, 'reorder', 1, 1), tasks)
  end)
  it('generates ids above the maximum, regardless of line order', function()
    local tasks, id = model.apply({ task(80), task(2) }, 'add', nil, { title = 'New', description = '', lane = 'triaged' })
    eq(id, 81)
    eq(model.find(tasks, id).status, { kind = 'triaged' })
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
    local id, err = session:change('done', 1)
    eq(id, nil)
    eq(err, 'disk full')
    eq(session:tasks(), { task() })
    fail = false
    assert(session:change('done', 1))
    eq(session:tasks()[1].status.kind, 'done')
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
