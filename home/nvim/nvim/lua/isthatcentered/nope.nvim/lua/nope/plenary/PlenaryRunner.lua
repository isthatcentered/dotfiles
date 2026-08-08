local Signal = require("nope.Signal")
local Job = require("nope.Job")
local Parser = require("nope.plenary.PlenaryOutputParser")

---@class PlenaryRunner: Runner
---@field private command string[]
---@field private job Job?
---@field private signal Signal<RunnerEvent>
---@field private parser PlenaryOutputParser
local M = {}
M.__index = M

---@param command string[]
---@return PlenaryRunner
function M.new(command)
  ---@type Signal<RunnerEvent>
  local signal = Signal.new()

  return setmetatable({
    command = command,
    signal = signal,
    job = nil,
    parser = Parser.new(),
  }, M)
end

---@param listener fun(event: RunnerEvent)
---@return fun() unsubscribe
function M:listen(listener)
  return self.signal:listen(listener)
end

function M:start()
  if self.job then
    return
  end

  self.parser:reset()

  self.job = Job.new(
    self.command,
    function(chunks)
      for _, chunk in ipairs(chunks) do
        self.parser:parse_line(chunk)
      end
      self.signal:emit({ type = "results", payload = self.parser:get_state() })
    end,
    function(_) end, -- stderr
    function(_)
      self.parser:complete()
      self.signal:emit({ type = "results", payload = self.parser:get_state() })
      self.signal:emit({ type = "process_ended" })
      self.job = nil
    end
  )

  self.signal:emit({ type = "process_started" })
  self.job:start()
end

function M:stop()
  if self.job then
    self.job:stop()
    self.job = nil
  end
end

return M
