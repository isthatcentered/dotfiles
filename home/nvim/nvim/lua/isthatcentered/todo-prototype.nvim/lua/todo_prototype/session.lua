-- Application service: publish a new snapshot only after the repository saves it.
local model = require 'todo_prototype.model'
local M = {}

function M.open(repository)
  local tasks, err = repository:load()
  if not tasks then
    return nil, err
  end
  local session = { path = repository.path }
  local history = {}

  function session:tasks()
    return vim.deepcopy(tasks)
  end

  function session:change(action, id, value)
    local ok, next_tasks, selected = pcall(model.apply, tasks, action, id, value)
    if not ok then
      return nil, tostring(next_tasks)
    end
    if not vim.deep_equal(tasks, next_tasks) then
      local saved, save_err = repository:save(next_tasks)
      if not saved then
        return nil, save_err
      end
      history[#history + 1] = { tasks = tasks, id = id }
      tasks = next_tasks
    end
    return selected
  end

  function session:undo()
    local previous = history[#history]
    if not previous then
      return nil
    end
    local saved, save_err = repository:save(previous.tasks)
    if not saved then
      return nil, save_err
    end
    tasks = table.remove(history).tasks
    return true, previous.id
  end

  return session
end

return M
