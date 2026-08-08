local EventBus = require("nope.EventBus")

---@param create_bus fun(): EventBus
local function shared_tests(create_bus)
  it("emits and receives events", function()
    local bus = create_bus()
    local received = {}

    bus:listen(function(event)
      table.insert(received, event)
    end)

    bus:emit({ type = "NopeTestRunStarted", payload = { key = "k1", configuration = {} } })

    assert.same(1, #received)
    assert.same("NopeTestRunStarted", received[1].type)
    assert.same("k1", received[1].payload.key)

    bus:destroy()
  end)

  it("multiple listeners receive same event", function()
    local bus = create_bus()
    local received1 = {}
    local received2 = {}

    bus:listen(function(event)
      table.insert(received1, event)
    end)
    bus:listen(function(event)
      table.insert(received2, event)
    end)

    bus:emit({ type = "NopeTestRunEnded", payload = { key = "k1" } })

    assert.same(1, #received1)
    assert.same(1, #received2)

    bus:destroy()
  end)

  it("unsubscribe stops receiving events", function()
    local bus = create_bus()
    local received = {}

    local unsubscribe = bus:listen(function(event)
      table.insert(received, event)
    end)

    bus:emit({ type = "NopeTestRunStarted", payload = { key = "k1", configuration = {} } })
    unsubscribe()
    bus:emit({ type = "NopeTestRunStarted", payload = { key = "k2", configuration = {} } })

    assert.same(1, #received)
    assert.same("k1", received[1].payload.key)

    bus:destroy()
  end)

  it("handles all event types", function()
    local bus = create_bus()
    local received = {}

    bus:listen(function(event)
      table.insert(received, event.type)
    end)

    bus:emit({ type = "NopeTestRunStarted", payload = { key = "k1", configuration = {} } })
    bus:emit({ type = "NopeTestRunResults", payload = { key = "k1", results = {} } })
    bus:emit({ type = "NopeTestRunEnded", payload = { key = "k1" } })
    bus:emit({ type = "NopeStopRun", payload = { key = "k1" } })

    assert.same({
      "NopeTestRunStarted",
      "NopeTestRunResults",
      "NopeTestRunEnded",
      "NopeStopRun",
    }, received)

    bus:destroy()
  end)

  it("destroy cleans up", function()
    local bus = create_bus()

    assert.has_no.errors(function()
      bus:destroy()
    end)
  end)
end

describe("EventBus", function()
  describe("SyncEventBus", function()
    shared_tests(EventBus.Sync.new)
  end)

  describe("AutocmdEventBus", function()
    shared_tests(EventBus.Autocmd.new)
  end)
end)
