-- JSONL repository. All storage, validation at the disk boundary, locking and
-- atomic replacement live here. The UI and domain model never access files.
local model = require 'todo_prototype.model'
local M = {}

---@class TodoRepository
---@field path string
---@field load fun(self: TodoRepository): TodoTask[]?, string?
---@field save fun(self: TodoRepository, tasks: TodoTask[]): boolean?, string?

---@param directory string Absolute working directory, captured when opening the manager.
---@return TodoRepository
function M.new(directory, fs)
  fs = fs or vim.uv
  local path = vim.fs.joinpath(directory, 'todo.jsonl')
  local snapshot
  local repo = { path = path }

  local function read()
    local stat, err, code = fs.fs_lstat(path)
    if not stat and code == 'ENOENT' then
      return nil
    end
    assert(stat, err)
    assert(stat.type == 'file', 'todo.jsonl must be a regular file (not a directory or symlink)')
    local fd = assert(fs.fs_open(path, 'r', 384))
    local ok, data = pcall(function()
      local size = assert(fs.fs_fstat(fd)).size
      local chunks, offset = {}, 0
      while offset < size do
        local chunk = assert(fs.fs_read(fd, size - offset, offset))
        assert(#chunk > 0, 'file changed while reading')
        chunks[#chunks + 1], offset = chunk, offset + #chunk
      end
      return table.concat(chunks)
    end)
    local closed, close_err = fs.fs_close(fd)
    assert(ok, data)
    assert(closed, close_err)
    return data, stat
  end

  local function locked(callback)
    local lock = path .. '.lock'
    local fd, err = fs.fs_open(lock, 'wx', 384)
    assert(fd, 'cannot acquire task file lock: ' .. tostring(err))
    local ok, result = pcall(callback)
    local closed, close_err = fs.fs_close(fd)
    local removed, remove_err = fs.fs_unlink(lock)
    assert(ok, result)
    assert(closed, close_err)
    assert(removed, remove_err)
    return result
  end

  local function decode(data)
    local tasks, ids = {}, {}
    for line_number, line in ipairs(vim.split(data, '\n', { plain = true })) do
      if line:find '%S' then
        local ok, task = pcall(function()
          local value = model.validate_task(vim.json.decode(line))
          assert(not ids[value.id], 'duplicate task id: ' .. value.id)
          return value
        end)
        assert(ok, ('%s:%d: %s'):format(path, line_number, tostring(task)))
        ids[task.id] = true
        tasks[#tasks + 1] = task
      end
    end
    return tasks
  end

  local function replace(data, mode)
    local fd, temp = fs.fs_mkstemp(path .. '.tmp.XXXXXX')
    assert(fd, temp)
    local ok, err = pcall(function()
      assert(fs.fs_fchmod(fd, mode or 384))
      local offset = 0
      while offset < #data do
        local written = assert(fs.fs_write(fd, data:sub(offset + 1), offset))
        assert(written > 0, 'could not finish writing tasks')
        offset = offset + written
      end
      assert(fs.fs_fsync(fd))
      assert(fs.fs_close(fd))
      fd = nil
      assert(fs.fs_rename(temp, path))
    end)
    if fd then
      fs.fs_close(fd)
    end
    if not ok then
      fs.fs_unlink(temp)
      error(err)
    end
  end

  function repo:load()
    local ok, result = pcall(function()
      return locked(function()
        local data = read()
        if data == nil then
          replace ''
          data = ''
        end
        local tasks = decode(data)
        snapshot = data
        return tasks
      end)
    end)
    if not ok then
      return nil, tostring(result)
    end
    return result
  end

  function repo:save(tasks)
    local ok, err = pcall(function()
      assert(snapshot ~= nil, 'load the repository before saving')
      model.validate(tasks)
      local lines = {}
      for _, task in ipairs(tasks) do
        lines[#lines + 1] = vim.json.encode(task)
      end
      local data = #lines == 0 and '' or table.concat(lines, '\n') .. '\n'
      locked(function()
        local current, stat = read()
        assert(current == snapshot, 'todo.jsonl changed outside this manager; close and reopen to reload before retrying')
        if data ~= current then
          replace(data, stat.mode % 512)
        end
        snapshot = data
      end)
    end)
    if not ok then
      return nil, tostring(err)
    end
    return true
  end

  return repo
end

return M
