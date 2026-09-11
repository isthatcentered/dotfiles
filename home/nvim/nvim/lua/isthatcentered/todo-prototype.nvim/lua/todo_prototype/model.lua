-- Canonical tasks have one tagged status, never separate lane/completion flags.
---@class TodoWorkingStatus
---@field kind 'backlog'|'triaged'

---@class TodoDoneStatus
---@field kind 'done'
---@field restore TodoWorkingStatus
---@field index integer

---@class TodoDiscardedStatus
---@field kind 'discarded'
---@field restore TodoWorkingStatus|TodoDoneStatus
---@field index integer

---@alias TodoStatus TodoWorkingStatus|TodoDoneStatus|TodoDiscardedStatus

---@class TodoTask
---@field version 1
---@field id integer
---@field title string
---@field description string
---@field status TodoStatus

local M = {}
local lanes = { backlog = true, triaged = true, done = true, discarded = true }

local function integer(n)
  return type(n) == 'number' and n >= 1 and n <= 9007199254740991 and n == math.floor(n)
end

local function fields(value, allowed)
  assert(type(value) == 'table', 'expected an object')
  for key in pairs(value) do
    assert(allowed[key], 'unknown field: ' .. tostring(key))
  end
end

local function status(value, allowed)
  fields(value, { kind = true, restore = true, index = true })
  assert(allowed[value.kind], 'invalid status')
  if value.kind == 'backlog' or value.kind == 'triaged' then
    assert(value.restore == nil and value.index == nil, 'working tasks cannot have restoration data')
  else
    assert(integer(value.index), 'restoration index must be a positive integer')
    status(value.restore, value.kind == 'done' and { backlog = true, triaged = true } or { backlog = true, triaged = true, done = true })
  end
end

function M.validate_task(task)
  fields(task, { version = true, id = true, title = true, description = true, status = true })
  assert(task.version == 1, 'unsupported task version (expected 1)')
  assert(integer(task.id), 'id must be a positive safe integer')
  assert(type(task.title) == 'string' and task.title:find '%S' and not task.title:find '[\r\n]', 'title must be a nonempty single line')
  assert(type(task.description) == 'string', 'description must be a string')
  status(task.status, lanes)
  return task
end

function M.validate(tasks)
  assert(type(tasks) == 'table' and vim.islist(tasks), 'tasks must be a list')
  local ids = {}
  for _, task in ipairs(tasks) do
    M.validate_task(task)
    assert(not ids[task.id], 'duplicate task id: ' .. task.id)
    ids[task.id] = true
  end
  return tasks
end

function M.find(tasks, id)
  for index, task in ipairs(tasks) do
    if task.id == id then
      return task, index
    end
  end
end

function M.next_id(tasks)
  local id = 1
  for _, task in ipairs(tasks) do
    id = math.max(id, task.id + 1)
  end
  assert(integer(id), 'task id space exhausted')
  return id
end

-- Physical line order defines relative order within each status.
local function position(tasks, task)
  local index = 0
  for _, other in ipairs(tasks) do
    if other.status.kind == task.status.kind then
      index = index + 1
    end
    if other.id == task.id then
      return index
    end
  end
end

local function insert(tasks, task, wanted)
  local seen, last = 0, #tasks
  for i, other in ipairs(tasks) do
    if other.status.kind == task.status.kind then
      seen, last = seen + 1, i
      if seen == wanted then
        table.insert(tasks, i, task)
        return
      end
    end
  end
  table.insert(tasks, last + 1, task)
end

-- Every command returns a validated copy, leaving the previous snapshot intact.
function M.apply(tasks, action, id, value)
  local result = vim.deepcopy(tasks)
  local task, index = M.find(result, id)
  if action == 'add' then
    task = {
      version = 1,
      id = M.next_id(result),
      title = value.title,
      description = value.description,
      status = { kind = value.lane or 'backlog' },
    }
    assert(task.status.kind == 'backlog' or task.status.kind == 'triaged', 'new tasks need a working status')
    insert(result, task)
  else
    assert(task, 'task no longer exists')
    local kind = task.status.kind
    if action == 'edit' then
      task.title, task.description = value.title, value.description
    elseif action == 'reorder' then
      local wanted = position(result, task) + value
      local count = 0
      for _, other in ipairs(result) do
        if other.status.kind == kind then
          count = count + 1
        end
      end
      if wanted >= 1 and wanted <= count then
        table.remove(result, index)
        insert(result, task, wanted)
      end
    elseif action == 'move' then
      if kind == 'backlog' or kind == 'triaged' then
        table.remove(result, index)
        task.status = { kind = kind == 'backlog' and 'triaged' or 'backlog' }
        insert(result, task)
      end
    elseif action == 'done' or action == 'discard' then
      local destination = action == 'done' and 'done' or 'discarded'
      if action ~= 'done' or kind ~= 'discarded' then
        local previous_index = position(result, task)
        table.remove(result, index)
        if kind == destination then
          local restore_index = task.status.index
          task.status = task.status.restore
          insert(result, task, restore_index)
        else
          task.status = { kind = destination, restore = task.status, index = previous_index }
          insert(result, task)
        end
      end
    else
      error('unknown task action: ' .. tostring(action))
    end
  end
  return M.validate(result), task.id
end

return M
