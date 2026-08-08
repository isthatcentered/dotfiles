local WatchController = require("nope.plenary.WatchController")
local Signal = require("nope.Signal")
local spy = require("luassert.spy")

---@class MockRunner: Runner
---@field signal Signal<RunnerEvent>
---@field started boolean
---@field stopped boolean
local MockRunner = {}
MockRunner.__index = MockRunner

function MockRunner.new()
  return setmetatable({
    signal = Signal.new(),
    started = false,
    stopped = false,
  }, MockRunner)
end

function MockRunner:listen(listener)
  return self.signal:listen(listener)
end

function MockRunner:start()
  self.started = true
  self.stopped = false
end

function MockRunner:stop()
  self.stopped = true
  self.started = false
end

function MockRunner:emit(event)
  self.signal:emit(event)
end

describe("WatchController", function()
  local mock_runner
  local controller

  before_each(function()
    mock_runner = MockRunner.new()
    controller = WatchController.new(mock_runner)
  end)

  describe("new", function()
    it("accepts a runner", function()
      assert.is_not_nil(controller)
    end)
  end)

  describe("start", function()
    it("starts inner runner", function()
      controller:start()
      assert.is_true(mock_runner.started)
    end)

    it("emits own process_started event", function()
      local listener = spy.new(function() end)
      controller:listen(listener)

      controller:start()

      assert.spy(listener).was.called_with({ type = "process_started" })
    end)
  end)

  describe("stop", function()
    it("stops inner runner", function()
      controller:start()
      controller:stop()
      assert.is_true(mock_runner.stopped)
    end)

    it("emits process_ended event", function()
      local events = {}
      controller:listen(function(event)
        table.insert(events, event)
      end)

      controller:start()
      controller:stop()

      local found_ended = false
      for _, event in ipairs(events) do
        if event.type == "process_ended" then
          found_ended = true
          break
        end
      end
      assert.is_true(found_ended)
    end)
  end)

  describe("event forwarding", function()
    it("forwards results events from inner runner", function()
      local events = {}
      controller:listen(function(event)
        table.insert(events, event)
      end)

      controller:start()

      local results_event = { type = "results", payload = { status = "done" } }
      mock_runner:emit(results_event)

      local found_results = false
      for _, event in ipairs(events) do
        if event.type == "results" then
          found_results = true
          assert.same({ status = "done" }, event.payload)
          break
        end
      end
      assert.is_true(found_results)
    end)

    it("does NOT forward process_started from inner runner", function()
      local process_started_count = 0
      controller:listen(function(event)
        if event.type == "process_started" then
          process_started_count = process_started_count + 1
        end
      end)

      controller:start()
      mock_runner:emit({ type = "process_started" })
      mock_runner:emit({ type = "process_started" })

      -- Only 1 from WatchController.start(), not from inner runner
      assert.same(1, process_started_count)
    end)

    it("does NOT forward process_ended from inner runner", function()
      local process_ended_count = 0
      controller:listen(function(event)
        if event.type == "process_ended" then
          process_ended_count = process_ended_count + 1
        end
      end)

      controller:start()
      mock_runner:emit({ type = "process_ended" })
      mock_runner:emit({ type = "process_ended" })

      -- 0 because we haven't called stop() yet
      assert.same(0, process_ended_count)

      controller:stop()
      -- Now 1 from WatchController.stop()
      assert.same(1, process_ended_count)
    end)
  end)

  describe("listen", function()
    it("returns unsubscribe function", function()
      local call_count = 0
      local unsub = controller:listen(function()
        call_count = call_count + 1
      end)

      controller:start()
      assert.same(1, call_count)

      unsub()

      controller:stop()
      -- Should still be 1 after unsub
      assert.same(1, call_count)
    end)
  end)
end)
