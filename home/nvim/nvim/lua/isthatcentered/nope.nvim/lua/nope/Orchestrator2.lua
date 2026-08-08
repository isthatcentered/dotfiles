---@alias RunnerEvent Event<"process_started", nil> | Event<"process_ended", nil> | Event<"results", TestRunState>

---@class Orchestrator2
---@field private adapters {[string]: FrameworkAdapter}
---@field private runners {[string]: Runner}
---@field private event_bus EventBus
---@field private unsubscribe fun()|nil
local M = {}
M.__index = M

---@param adapters FrameworkAdapter[]
---@param event_bus EventBus
---@return Orchestrator2
function M.new(adapters, event_bus)
  local adapters_by_name = {}
  for _, adapter in pairs(adapters) do
    adapters_by_name[adapter.name] = adapter
  end

  local self = setmetatable({
    adapters = adapters_by_name,
    runners = {},
    event_bus = event_bus,
    unsubscribe = nil,
  }, M)

  -- Subscribe to stop command from consumers
  self.unsubscribe = event_bus:listen(function(event)
    if event.type == "NopeStopRun" then
      local key = event.payload.key
      if key then
        self:stop(key)
      end
    end
  end)

  return self
end

---@param configuration RunConfiguration
function M:start_run(configuration)
  local adapter = self.adapters[configuration.adapter]

  if not adapter then
    error(string.format([[No such adapter "%s"]], configuration.adapter))
  end

  local runner = adapter:get_runner(configuration)
  local unsubscribe = nil
  unsubscribe = runner:listen(function(event)
    ---@cast event RunnerEvent
    if event.type == "process_started" then
      self.event_bus:emit({
        type = "NopeTestRunStarted",
        payload = {
          configuration = configuration,
          key = configuration.key,
        },
      })
    elseif event.type == "results" then
      self.event_bus:emit({
        type = "NopeTestRunResults",
        payload = {
          key = configuration.key,
          results = event.payload,
        },
      })
    elseif event.type == "process_ended" then
      vim.schedule(function()
        unsubscribe()
      end)

      self.event_bus:emit({
        type = "NopeTestRunEnded",
        payload = {
          key = configuration.key,
        },
      })
    end
  end)

  runner:start()
  self.runners[configuration.key] = runner
end

function M:stop(key)
  local match = self.runners[key]
  if not match then
    return
  end

  match:stop()
end

function M:stop_all()
  for _, runner in pairs(self.runners) do
    runner:stop()
  end
end

function M:destroy()
  if self.unsubscribe then
    self.unsubscribe()
    self.unsubscribe = nil
  end
end

return M
