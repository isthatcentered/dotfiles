---@class StreamBuffer
---@field private buffer string
---@field private on_line fun(line: string)
local M = {}
M.__index = M

---@param on_line fun(line: string) callback invoked for each complete line
---@return StreamBuffer
function M.new(on_line)
  return setmetatable({
    buffer = '',
    on_line = on_line,
  }, M)
end

---Push chunks from jobstart on_stdout/on_stderr callback
---@param chunks string[] array of strings split by newlines
function M:push(chunks)
  -- First chunk continues previous incomplete line
  self.buffer = self.buffer .. chunks[1]

  -- Each subsequent chunk means there was a newline before it
  -- So the previous buffer is complete
  for i = 2, #chunks do
    self.on_line(self.buffer)
    self.buffer = chunks[i]
  end
end

---Flush remaining buffer (call on EOF/job exit)
function M:flush()
  if self.buffer ~= '' then
    self.on_line(self.buffer)
    self.buffer = ''
  end
end

return M
