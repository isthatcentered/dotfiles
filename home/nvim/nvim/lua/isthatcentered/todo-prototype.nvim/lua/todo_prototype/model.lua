-- One status owns both column membership and deletion. Ordering is JSONL line order.
---@alias TodoStatus 'backlog'|'active'|'done'|'discarded'
---@class TodoTask
---@field version 2
---@field id integer
---@field title string
---@field description string
---@field status TodoStatus
local M = {}
local lanes = { backlog = true, active = true, done = true }

local function integer(n)
  return type(n) == 'number' and n >= 1 and n <= 9007199254740991 and n == math.floor(n)
end

local function fields(value, allowed)
  assert(type(value) == 'table', 'expected an object')
  for key in pairs(value) do
    assert(allowed[key], 'unknown field: ' .. tostring(key))
  end
end

local function legacy_status(value, allowed)
  fields(value, { kind = true, restore = true, index = true })
  assert(allowed[value.kind], 'invalid status')
  if value.kind == 'backlog' or value.kind == 'triaged' then
    assert(value.restore == nil and value.index == nil, 'working tasks cannot have restoration data')
  else
    assert(integer(value.index), 'restoration index must be a positive integer')
    legacy_status(value.restore, value.kind == 'done' and { backlog = true, triaged = true } or { backlog = true, triaged = true, done = true })
  end
end

local function validate_fields(task)
  fields(task, { version = true, id = true, title = true, description = true, status = true })
  assert(integer(task.id), 'id must be a positive safe integer')
  assert(type(task.title) == 'string' and task.title:find '%S' and not task.title:find '[\r\n]', 'title must be a nonempty single line')
  assert(type(task.description) == 'string', 'description must be a string')
end

function M.validate_task(task)
  validate_fields(task)
  assert(task.version == 2, 'unsupported task version (expected 2)')
  assert(type(task.status) == 'string' and (lanes[task.status] or task.status == 'discarded'), 'invalid status')
  return task
end

-- Only the disk boundary accepts the previous schema. Validate before dropping metadata.
function M.migrate_task(task)
  validate_fields(task)
  if task.version == 1 then
    legacy_status(task.status, { backlog = true, triaged = true, done = true, discarded = true })
    task = vim.deepcopy(task)
    task.version, task.status = 2, task.status.kind == 'triaged' and 'active' or task.status.kind
  end
  return M.validate_task(task)
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

-- Every command returns a validated copy, leaving the previous snapshot intact.
function M.apply(tasks, action, id, value)
  M.validate(tasks)
  local result = vim.deepcopy(tasks)
  local task, index = M.find(result, id)
  if action == 'add' then
    task = {
      version = 2, id = M.next_id(result), title = value.title,
      description = value.description, status = value.lane or 'backlog',
    }
    assert(lanes[task.status], 'new tasks need a board column')
    table.insert(result, 1, task)
  else
    assert(task, 'task no longer exists')
    if action == 'edit' then
      assert(task.status ~= 'discarded', 'cannot edit a deleted task')
      task.title, task.description = value.title, value.description
    elseif action == 'reorder' then
      assert(value == 1 or value == -1, 'reorder needs a direction')
      if task.status ~= 'discarded' then
        for i = index + value, value == 1 and #result or 1, value do
          if result[i].status == task.status then
            result[index], result[i] = result[i], task
            break
          end
        end
      end
    elseif action == 'move' then
      assert(type(value) == 'string' and lanes[value], 'invalid destination column')
      if task.status ~= 'discarded' and task.status ~= value then
        table.remove(result, index)
        task.status = value
        table.insert(result, 1, task)
      end
    elseif action == 'discard' then
      task.status = 'discarded'
    else
      error('unknown task action: ' .. tostring(action))
    end
  end
  return M.validate(result), task.id
end

return M
