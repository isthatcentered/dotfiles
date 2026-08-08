local EventBus = require("scoped.EventBus")
local spy = require("luassert.spy")

describe("EventBus", function()
  describe("subscribe", function()
    it("Subscribing with non-function fails", function()
      local bus = EventBus.new()

      assert.has_error(function()
        bus:subscribe("not a function")
      end)
    end)

    it("Returns unsubscribe function", function()
      local bus = EventBus.new()

      local unsubscribe = bus:subscribe(function() end)

      assert.same("function", type(unsubscribe))
    end)

    it("Calls subscriber when event is emitted", function()
      local bus = EventBus.new()
      local callback = spy.new(function() end)

      bus:subscribe(callback)
      bus:emit("event_data")

      assert.spy(callback).was_called_with("event_data")
    end)

    it("Only receives events sent after subscription", function()
      local bus = EventBus.new()
      local callback = spy.new(function() end)

      bus:emit("before_subscription")
      bus:subscribe(callback)

      assert.spy(callback).was_not_called()
    end)

    it("Multiple subscribers receive the same event", function()
      local bus = EventBus.new()
      local callback_1 = spy.new(function() end)
      local callback_2 = spy.new(function() end)

      bus:subscribe(callback_1)
      bus:subscribe(callback_2)
      bus:emit("event_data")

      assert.spy(callback_1).was_called_with("event_data")
      assert.spy(callback_2).was_called_with("event_data")
    end)

    it("Subscribers are called in subscription order", function()
      local bus = EventBus.new()
      local call_order = {}

      bus:subscribe(function()
        table.insert(call_order, 1)
      end)
      bus:subscribe(function()
        table.insert(call_order, 2)
      end)
      bus:emit("event")

      assert.same({ 1, 2 }, call_order)
    end)
  end)

  describe("unsubscribe", function()
    it("Subscribers stop receiving events once unsubscribed", function()
      local bus = EventBus.new()
      local callback = spy.new(function() end)

      local unsubscribe = bus:subscribe(callback)
      unsubscribe()
      bus:emit("event_data")

      assert.spy(callback).was_not_called()
    end)

    it("Unsubscribes the correct subscriber", function()
      local bus = EventBus.new()
      local callback_1 = spy.new(function() end)
      local callback_2 = spy.new(function() end)

      local unsubscribe_1 = bus:subscribe(callback_1)
      bus:subscribe(callback_2)
      unsubscribe_1()
      bus:emit("event_data")

      assert.spy(callback_1).was_not_called()
      assert.spy(callback_2).was_called_with("event_data")
    end)

    it("Calling unsubscribe multiple times is safe", function()
      local bus = EventBus.new()
      local callback = spy.new(function() end)

      local unsubscribe = bus:subscribe(callback)
      unsubscribe()
      unsubscribe()
      bus:emit("event_data")

      assert.spy(callback).was_not_called()
    end)
  end)

  describe("emit", function()
    it("Emitting with no subscribers does nothing", function()
      local bus = EventBus.new()

      bus:emit("event_data")
    end)

    it("Passes event data to subscribers", function()
      local bus = EventBus.new()
      local received_data = nil

      bus:subscribe(function(data)
        received_data = data
      end)
      bus:emit({ key = "value" })

      assert.same({ key = "value" }, received_data)
    end)
  end)
end)
