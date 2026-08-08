local EventEmitter = require("scoped.EventEmitter")

describe("EventEmitter", function()
  local emitter

  before_each(function()
    emitter = EventEmitter.new()
  end)

  describe("listen", function()
    it("errors if callback is not a function", function()
      assert.has_error(function()
        emitter:listen("not a function")
      end)
    end)

    it("returns an unsubscribe function", function()
      local unsubscribe = emitter:listen(function() end)
      assert.is_function(unsubscribe)
    end)
  end)

  describe("emit", function()
    it("calls listener with event", function()
      local received = nil
      emitter:listen(function(event) received = event end)

      emitter:emit({ kind = "test", payload = { foo = "bar" } })

      assert.same({ kind = "test", payload = { foo = "bar" } }, received)
    end)

    it("calls multiple listeners", function()
      local count = 0
      emitter:listen(function() count = count + 1 end)
      emitter:listen(function() count = count + 1 end)

      emitter:emit({ kind = "test", payload = {} })

      assert.same(2, count)
    end)

    it("does nothing with no listeners", function()
      assert.has_no.errors(function()
        emitter:emit({ kind = "test", payload = {} })
      end)
    end)
  end)

  describe("unsubscribe", function()
    it("removes listener", function()
      local count = 0
      local unsubscribe = emitter:listen(function()
        count = count + 1
      end)

      emitter:emit({ kind = "test", payload = {} })
      unsubscribe()
      emitter:emit({ kind = "test", payload = {} })

      assert.same(1, count)
    end)

    it("only removes the specific listener", function()
      local count = 0
      local unsubscribe = emitter:listen(function()
        count = count + 1
      end)
      emitter:listen(function()
        count = count + 10
      end)

      emitter:emit({ kind = "test", payload = {} })
      unsubscribe()
      emitter:emit({ kind = "test", payload = {} })

      assert.same(21, count)
    end)

    it("can be called multiple times safely", function()
      local unsubscribe = emitter:listen(function() end)

      assert.has_no.errors(function()
        unsubscribe()
        unsubscribe()
      end)
    end)
  end)
end)
