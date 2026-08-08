local DetailsService = require("nope.consumers.WindowConsumer.Details.state.DetailsService")

describe("DetailsService", function()
  describe("new", function()
    it("creates service with default state", function()
      local service = DetailsService.new()
      local state = service:get_state()

      assert.is_nil(state.selected_node)
      assert.same(0, state.scroll_offset)
    end)
  end)

  describe("update_from_navigation", function()
    it("updates selected_node from nav state", function()
      local service = DetailsService.new()
      local node = { id = "t1", type = "test", node = { name = "my test" } }

      service:update_from_navigation({
        selected_node = node,
      })

      local state = service:get_state()
      assert.same(node, state.selected_node)
    end)

    it("resets scroll_offset when selected_node changes", function()
      local service = DetailsService.new()
      local node1 = { id = "t1", type = "test" }
      local node2 = { id = "t2", type = "test" }

      service:update_from_navigation({ selected_node = node1 })
      service:set_scroll_offset(50)
      assert.same(50, service:get_state().scroll_offset)

      service:update_from_navigation({ selected_node = node2 })
      assert.same(0, service:get_state().scroll_offset)
    end)

    it("notifies subscribers on change", function()
      local service = DetailsService.new()
      local called = 0
      local received_state = nil

      service:subscribe(function(state)
        called = called + 1
        received_state = state
      end)

      -- Subscribe calls immediately (called = 1)
      local node = { id = "t1", type = "test" }
      service:update_from_navigation({ selected_node = node })

      assert.same(2, called)
      assert.same(node, received_state.selected_node)
    end)

    it("does not notify if nothing changed", function()
      local service = DetailsService.new()
      local called = 0

      service:subscribe(function()
        called = called + 1
      end)

      -- Subscribe calls immediately (called = 1)
      service:update_from_navigation({ selected_node = nil })

      assert.same(1, called) -- No additional call
    end)
  end)

  describe("set_scroll_offset", function()
    it("updates scroll_offset", function()
      local service = DetailsService.new()

      service:set_scroll_offset(100)

      assert.same(100, service:get_state().scroll_offset)
    end)

    it("notifies subscribers", function()
      local service = DetailsService.new()
      local called = 0

      service:subscribe(function()
        called = called + 1
      end)

      service:set_scroll_offset(50)

      assert.same(2, called) -- Subscribe + set_scroll_offset
    end)

    it("does not notify if value unchanged", function()
      local service = DetailsService.new()
      local called = 0

      service:subscribe(function()
        called = called + 1
      end)

      service:set_scroll_offset(0) -- Same as default

      assert.same(1, called) -- Only subscribe call
    end)
  end)

  describe("subscribe", function()
    it("calls callback immediately with current state", function()
      local service = DetailsService.new()
      service:update_from_navigation({ selected_node = { id = "t1" } })

      local received = nil
      service:subscribe(function(state)
        received = state
      end)

      assert.is_not_nil(received)
      assert.same("t1", received.selected_node.id)
    end)

    it("returns unsubscribe function", function()
      local service = DetailsService.new()
      local called = 0

      local unsubscribe = service:subscribe(function()
        called = called + 1
      end)

      unsubscribe()
      service:update_from_navigation({ selected_node = { id = "t1" } })

      assert.same(1, called) -- Only initial call, not update
    end)
  end)
end)
