local StreamBuffer = require("nope.StreamBuffer")

---@class Job
---@field command string[]
---@field on_stdout fun(data:string[])
---@field on_stderr fun(data:string[])
---@field on_exit fun(code: integer)
---@field job_id integer?
---@field private running  boolean
local M = {}
M.__index = M

---@param command string[]
---@param on_stdout fun(chunks: string[])
---@param on_stderr fun(chunks: string[])
---@param on_exit fun(code: integer)
---@return Job
function M.new(command, on_stdout, on_stderr, on_exit)
  return setmetatable({
    command = command,
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = on_exit,
    pending = false,
  }, M)
end

function M:start()
  if self.running then
    return
  end

  local stdout_buffer = StreamBuffer.new(function(line)
    self.on_stdout({line})
  end)
  local stderr_buffer = StreamBuffer.new(function(line)
    self.on_stderr({line})
  end)

  local job_id = vim.fn.jobstart(self.command, {
    on_stdout = function(job_id, chunks, type)
      stdout_buffer:push(chunks)
    end,
    on_stderr = function(job_id, chunks, type)
      stderr_buffer:push(chunks)
    end,
    on_exit = function(_, code)
      stdout_buffer:flush()
      stderr_buffer:flush()
      self.running = false
      self.on_exit(code)
    end,
  })

  if job_id == 0 then
    error("Invalid command arguments")
  end

  if job_id == -1 then
    error(self.command[1] .. " cannot be executed")
  end

  self.running = true
  self.job_id = job_id
end

function M:stop()
  if not self.job_id then
    return
  end
  vim.fn.jobstop(self.job_id)
end

return M
