local Signal = require("nope.Signal")
local JSONParser = require("nope.json_parser")
local Job = require("nope.Job")

---@class VitestRunner: Runner
---@field private command string[]
---@field private job Job?
---@field private signal Signal<RunnerEvent>
local M = {}
M.__index = M

---@param command string[]
---@return Runner
function M.new(command)
  ---@type Signal<RunnerEvent>
  local signal = Signal.new()

  return setmetatable({
    command = command,
    signal = signal,
    job = nil,
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

  local json_parser = JSONParser.new()

  self.job = Job.new(
    self.command,
    function(chunks)
      local parsed_objects, errors = json_parser:parse_lines(chunks)

      for _, err in ipairs(errors) do
        error(err)
      end

      for _, status in ipairs(parsed_objects) do
        self.signal:emit({ type = "results", payload = status })
      end
    end,
    function(_)
      -- stderr intentionally ignored to avoid vim.notify storm during rapid reruns
    end,
    function(_)
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
  end
end

return M
