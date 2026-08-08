local RunConfiguration = require("nope.RunConfiguration")
local make_default_label = require("nope.make_default_label")
local Orchestrator = require("nope.Orchestrator2")
local Signal = require("nope.Signal")
local EventBus = require("nope.EventBus")
local F = require("nope.fake")

local RunConfigurationFake = F.struct({
  configuration_path = F.string,
  file_path = F.string,
  watch = F.always(false),
  label = F.string,
  adapter_name = F.string,
}):map(function(data)
  return RunConfiguration.new(data.adapter_name, data)
end) --[[@as Fake<RunConfiguration>]]

local make_run_configuration_ = F.factory(RunConfigurationFake, function(a, b)
  return vim.tbl_extend("force", a, b)
end)


local function random_run_configuration(adapter_name)
  local config_path, file_path = unpack(F.string:zip(F.string):run())
  return RunConfiguration.new(adapter_name, {
    configuration_path = config_path,
    file_path = file_path,
    watch = false,
    label = make_default_label(adapter_name, file_path, nil, config_path, false),
  })
end

---@class MockRunner2: Runner2
---@field signal Signal<RunnerEvent>
local MockRunner = {}
MockRunner.__index = MockRunner

---@return MockRunner2
function MockRunner.new()
  return setmetatable({
    signal = Signal.new(),
  }, MockRunner)
end

function MockRunner:start()
  -- Force to rely on events rather than synchronous behavior
  vim.schedule(function()
    self.signal:emit({ type = "process_started", payload = nil })
  end)
end

function MockRunner:stop()
  -- Force to rely on events rather than synchronous behavior
  vim.schedule(function()
    self.signal:emit({ type = "process_ended", payload = nil })
  end)
end

function MockRunner:listen(cb)
  return self.signal:listen(cb)
end

describe("Orchestrator", function()
  local event_bus

  before_each(function()
    event_bus = EventBus.Sync.new()
  end)

  after_each(function()
    if event_bus then
      event_bus:destroy()
    end
  end)

  describe("acceptance tests", function() end)

  describe("start_run", function()
    it("No matching adapter fails", function()
      ---@type FrameworkAdapter
      local adapter = { name = "A" }
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      assert.error_matches(function()
        orchestrator:start_run(random_run_configuration("B"))
      end, [[No such adapter "B"]])
    end)

    it("Notifies on process start", function()
      local events = {}
      event_bus:listen(function(event)
        table.insert(events, event)
      end)
      local runner = MockRunner.new()
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return runner
        end,
      }
      local configuration = random_run_configuration(adapter.name)
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      orchestrator:start_run(configuration)
      vim.wait(1)

      assert.same(1, #events)
      assert.same("NopeTestRunStarted", events[1].type)
      assert.same(configuration, events[1].payload.configuration)
      assert.same(configuration.key, events[1].payload.key)
    end)

    it("Notifies on test run update", function()
      local events = {}
      event_bus:listen(function(event)
        if event.type == "NopeTestRunResults" then
          table.insert(events, event)
        end
      end)
      local runner = MockRunner.new()
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return runner
        end,
      }
      local configuration = random_run_configuration(adapter.name)
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      orchestrator:start_run(configuration)
      runner.signal:emit({ type = "results", payload = "A" })
      runner.signal:emit({ type = "results", payload = "B" })
      runner.signal:emit({ type = "results", payload = "C" })

      assert.same(3, #events)
      assert.same("NopeTestRunResults", events[1].type)
      assert.same(configuration.key, events[1].payload.key)
      assert.same("A", events[1].payload.results)
      assert.same("B", events[2].payload.results)
      assert.same("C", events[3].payload.results)
    end)

    it("Notifies on process end", function()
      local events = {}
      event_bus:listen(function(event)
        if event.type == "NopeTestRunEnded" then
          table.insert(events, event)
        end
      end)
      local runner = MockRunner.new()
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return runner
        end,
      }
      local configuration = random_run_configuration(adapter.name)
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      orchestrator:start_run(configuration)
      runner.signal:emit({ type = "process_ended", payload = nil })

      assert.same(1, #events)
      assert.same("NopeTestRunEnded", events[1].type)
      assert.same(configuration.key, events[1].payload.key)

      vim.wait(1)
      assert.same(0, runner.signal:listener_count())
    end)
  end)

  describe("NopeStopRun event", function()
    it("Stops run when receiving NopeStopRun event", function()
      local stopped = {}
      event_bus:listen(function(event)
        if event.type == "NopeTestRunEnded" then
          table.insert(stopped, event.payload.key)
        end
      end)
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return MockRunner.new()
        end,
      }
      local configuration = random_run_configuration(adapter.name)
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      orchestrator:start_run(configuration)
      event_bus:emit({ type = "NopeStopRun", payload = { key = configuration.key } })

      vim.wait(1)
      assert.same({ configuration.key }, stopped)
    end)

    it("Does nothing when key not provided", function()
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return MockRunner.new()
        end,
      }
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      assert.Not.has_errors(function()
        event_bus:emit({ type = "NopeStopRun", payload = { key = nil } })
      end)
    end)
  end)

  describe("stop", function()
    it("No matching run does nothing", function()
      local runner = MockRunner.new()
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return runner
        end,
      }
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      orchestrator:start_run(random_run_configuration(adapter.name))

      vim.wait(0)
      assert.Not.has_errors(function()
        orchestrator:stop("unknown_key")
      end)
    end)

    it("Run already completed does nothing", function()
      local key = nil
      event_bus:listen(function(event)
        if event.type == "NopeTestRunEnded" then
          key = event.payload.key
        end
      end)
      local runner = MockRunner.new()
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return runner
        end,
      }
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      orchestrator:start_run(random_run_configuration(adapter.name))
      runner:stop()

      vim.wait(0)
      assert.Not.same(nil, key)
      assert.Not.has_errors(function()
        orchestrator:stop("unknown_key")
      end)
    end)

    it("Stops given run", function()
      local stopped = {}
      event_bus:listen(function(event)
        if event.type == "NopeTestRunEnded" then
          table.insert(stopped, event.payload.key)
        end
      end)
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return MockRunner.new()
        end,
      }
      local configuration_A = random_run_configuration(adapter.name)
      local configuration_B = random_run_configuration(adapter.name)
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      orchestrator:start_run(configuration_A)
      orchestrator:start_run(configuration_B)
      orchestrator:stop(configuration_A.key)

      vim.wait(1)
      assert.same({ configuration_A.key }, stopped)
    end)
  end)

  describe("stop_all", function()
    it("No pending test does nothing", function()
      local runner = MockRunner.new()
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return runner
        end,
      }
      local orchestrator = Orchestrator.new({ adapter }, event_bus)

      assert.Not.has_errors(function()
        orchestrator:stop_all()
      end)
    end)

    it("Stops all pendings runs", function()
      local events = {}
      event_bus:listen(function(event)
        if event.type == "NopeTestRunEnded" then
          table.insert(events, event.type)
        end
      end)
      ---@type FrameworkAdapter
      local adapter = {
        name = "adapter_name",
        get_runner = function()
          return MockRunner.new()
        end,
      }
      local configuration_A = random_run_configuration(adapter.name)
      local configuration_B = random_run_configuration(adapter.name)
      local orchestrator = Orchestrator.new({ adapter }, event_bus)
      orchestrator:start_run(configuration_A)
      orchestrator:start_run(configuration_B)

      orchestrator:stop_all()

      vim.wait(0)
      assert.same({ "NopeTestRunEnded", "NopeTestRunEnded" }, events)
    end)
  end)

  --- already a run active restarts the runner
  --- TODO: we might be loosing the runner when calling start twice instead of re-using/trashing it and starting a new one
  -- restart behavior since i clear the listeners

  --- ensure runners are cleaned up automatically once done
  ---                                             on stop
  --can differentiate events between two runs
  --same config, same key, always
  --starting the same job twice
  --stop
  --restart???
  --- Completed runs are discarded
end)
