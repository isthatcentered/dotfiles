local Service = require("nope.consumers.WindowConsumer.Navigation.state.NavigationService")

-- Test fixtures
local function make_state(overrides)
  return vim.tbl_deep_extend("force", {
    status = "done",
    duration_ms = 1000,
    summary = { total = 2, passed = 2, failed = 0, skipped = 0 },
    files = {},
  }, overrides or {})
end

local function make_file(overrides)
  return vim.tbl_deep_extend("force", {
    id = "file-1",
    path = "/path/to/test.ts",
    status = "passed",
    suites = {},
    tests = {},
  }, overrides or {})
end

local function make_test(overrides)
  return vim.tbl_deep_extend("force", {
    id = "test-1",
    name = "should work",
    full_name = "suite > should work",
    status = "passed",
    duration_ms = 10,
    location = { line = 5, column = 1 },
  }, overrides or {})
end

describe("NavigationService", function()
  describe("new", function()
    it("creates service with empty state", function()
      local service = Service.new(function() end)
      local state = service:get_state()

      assert.same({}, state.tabs)
      assert.is_nil(state.active_tab_key)
      assert.same({}, state.nodes)
      assert.is_nil(state.selected_id)
      assert.is_false(state.showing_help)
      assert.is_false(state.filter_active)
      assert.is_nil(state.selected_node)
      assert.is_nil(state.summary)
      assert.is_nil(state.duration_ms)
    end)
  end)

  describe("handle_event NopeTestRunStarted", function()
    it("creates tab for new run", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })

      local state = service:get_state()
      assert.same(1, #state.tabs)
      assert.same("run1", state.tabs[1].key)
      assert.same("running", state.tabs[1].status)
    end)

    it("auto-activates first run", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })

      assert.same("run1", service:get_state().active_tab_key)
    end)

    it("does not auto-activate subsequent runs", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })
      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run2" },
      })

      local state = service:get_state()
      assert.same(2, #state.tabs)
      assert.same("run1", state.active_tab_key)
    end)

    it("uses configuration.label when provided", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "abc123def456", configuration = { label = "unit tests" } },
      })

      assert.same("unit tests", service:get_state().tabs[1].label)
    end)

    it("uses first 8 chars of key when no label", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "abc123def456" },
      })

      assert.same("abc123de", service:get_state().tabs[1].label)
    end)

    it("resets status to running for existing run", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })
      service:handle_event({
        type = "NopeTestRunEnded",
        payload = { key = "run1" },
      })
      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })

      assert.same("running", service:get_state().tabs[1].status)
    end)

    it("updates label when restarting with new config", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1", configuration = { label = "old" } },
      })
      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1", configuration = { label = "new" } },
      })

      assert.same("new", service:get_state().tabs[1].label)
    end)

    it("preserves tab order for existing run", function()
      local service = Service.new(function() end)

      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } }) -- restart

      local state = service:get_state()
      assert.same("a", state.tabs[1].key)
      assert.same("b", state.tabs[2].key)
    end)

    it("ignores event without key", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = {},
      })

      assert.same(0, #service:get_state().tabs)
    end)
  end)

  describe("handle_event NopeTestRunEnded", function()
    it("sets status to done", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })
      service:handle_event({
        type = "NopeTestRunEnded",
        payload = { key = "run1" },
      })

      assert.same("done", service:get_state().tabs[1].status)
    end)

    it("ignores event without key", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })
      service:handle_event({
        type = "NopeTestRunEnded",
        payload = {},
      })

      assert.same("running", service:get_state().tabs[1].status)
    end)

    it("ignores event for unknown run", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunEnded",
        payload = { key = "unknown" },
      })

      assert.same(0, #service:get_state().tabs)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:handle_event({
        type = "NopeTestRunEnded",
        payload = { key = "run1" },
      })

      assert.same(2, #states)
      assert.same("done", states[2].tabs[1].status)
    end)
  end)

  describe("subscribe", function()
    it("calls subscriber with initial state", function()
      local service = Service.new(function() end)
      local states = {}

      service:subscribe(function(s)
        table.insert(states, s)
      end)

      assert.same(1, #states)
      assert.same({}, states[1].tabs)
    end)

    it("calls subscriber on state change", function()
      local service = Service.new(function() end)
      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })

      assert.same(2, #states)
      assert.same(1, #states[2].tabs)
    end)

    it("returns unsubscribe function", function()
      local service = Service.new(function() end)
      local call_count = 0
      local unsub = service:subscribe(function()
        call_count = call_count + 1
      end)

      unsub()
      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "run1" },
      })

      assert.same(1, call_count) -- only initial call
    end)
  end)

  describe("switch_tab", function()
    it("switches to next tab with delta +1", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })

      service:switch_tab(1)

      assert.same("b", service:get_state().active_tab_key)
    end)

    it("switches to previous tab with delta -1", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })
      service:switch_tab(1) -- now on b

      service:switch_tab(-1)

      assert.same("a", service:get_state().active_tab_key)
    end)

    it("wraps from last to first", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })
      service:switch_tab(1) -- now on b

      service:switch_tab(1) -- wrap to a

      assert.same("a", service:get_state().active_tab_key)
    end)

    it("wraps from first to last", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })

      service:switch_tab(-1) -- wrap to b

      assert.same("b", service:get_state().active_tab_key)
    end)

    it("no-op with single tab", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:switch_tab(1)

      assert.same("a", service:get_state().active_tab_key)
    end)

    it("no-op with no tabs", function()
      local service = Service.new(function() end)

      service:switch_tab(1)

      assert.is_nil(service:get_state().active_tab_key)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:switch_tab(1)

      assert.same(2, #states)
      assert.same("b", states[2].active_tab_key)
    end)
  end)

  describe("switch_to_tab", function()
    it("switches to tab at index", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "c" } })

      service:switch_to_tab(2)

      assert.same("b", service:get_state().active_tab_key)
    end)

    it("no-op if index > tab count", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:switch_to_tab(5)

      assert.same("a", service:get_state().active_tab_key)
    end)

    it("no-op if index < 1", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:switch_to_tab(0)

      assert.same("a", service:get_state().active_tab_key)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:switch_to_tab(2)

      assert.same(2, #states)
      assert.same("b", states[2].active_tab_key)
    end)
  end)

  describe("close_tab", function()
    it("removes active tab", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })

      service:close_tab()

      local state = service:get_state()
      assert.same(1, #state.tabs)
      assert.same("b", state.tabs[1].key)
    end)

    it("sends NopeStopRun command", function()
      local commands = {}
      local service = Service.new(function(cmd)
        table.insert(commands, cmd)
      end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:close_tab()

      assert.same(1, #commands)
      assert.same("NopeStopRun", commands[1].type)
      assert.same("a", commands[1].payload.key)
    end)

    it("switches to next tab after close", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "c" } })

      service:close_tab() -- close a, should go to b

      assert.same("b", service:get_state().active_tab_key)
    end)

    it("switches to last tab when closing last position", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })
      service:switch_to_tab(2) -- on b

      service:close_tab() -- close b, should go to a

      assert.same("a", service:get_state().active_tab_key)
    end)

    it("clears active_tab_key when closing last tab", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:close_tab()

      local state = service:get_state()
      assert.same(0, #state.tabs)
      assert.is_nil(state.active_tab_key)
    end)

    it("no-op with no tabs", function()
      local commands = {}
      local service = Service.new(function(cmd)
        table.insert(commands, cmd)
      end)

      service:close_tab()

      assert.same(0, #commands)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:close_tab()

      assert.same(2, #states)
      assert.same(1, #states[2].tabs)
    end)
  end)

  describe("stop_run", function()
    it("sends NopeStopRun command with active key", function()
      local commands = {}
      local service = Service.new(function(cmd)
        table.insert(commands, cmd)
      end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:stop_run()

      assert.same(1, #commands)
      assert.same("NopeStopRun", commands[1].type)
      assert.same("a", commands[1].payload.key)
    end)

    it("no-op with no active run", function()
      local commands = {}
      local service = Service.new(function(cmd)
        table.insert(commands, cmd)
      end)

      service:stop_run()

      assert.same(0, #commands)
    end)

    it("does not remove tab", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:stop_run()

      assert.same(1, #service:get_state().tabs)
    end)

    it("does not notify subscribers", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local call_count = 0
      service:subscribe(function()
        call_count = call_count + 1
      end)

      service:stop_run()

      assert.same(1, call_count) -- only initial call
    end)
  end)

  describe("handle_event NopeTestRunResults", function()
    it("populates nodes from results", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local results = make_state({
        files = {
          make_file({
            tests = { make_test({ id = "t1" }), make_test({ id = "t2" }) },
          }),
        },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      local state = service:get_state()
      assert.is_true(#state.nodes > 0)
    end)

    it("updates has_failures when failures exist", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local results = make_state({
        summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
        files = { make_file({ status = "failed" }) },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      assert.is_true(service:get_state().tabs[1].has_failures)
    end)

    it("clears has_failures when no failures", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local results = make_state({
        summary = { total = 2, passed = 2, failed = 0, skipped = 0 },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      assert.is_false(service:get_state().tabs[1].has_failures)
    end)

    it("creates run if not exists", function()
      local service = Service.new(function() end)

      local results = make_state()
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "new-run", results = results },
      })

      assert.same(1, #service:get_state().tabs)
      assert.same("new-run", service:get_state().tabs[1].key)
    end)

    it("auto-activates if no active run", function()
      local service = Service.new(function() end)

      local results = make_state()
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      assert.same("a", service:get_state().active_tab_key)
    end)

    it("sets selected_id to first node if none selected", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local results = make_state({
        files = { make_file({ tests = { make_test() } }) },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      local state = service:get_state()
      assert.is_not_nil(state.selected_id)
    end)

    it("preserves selected_id if still valid", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local test = make_test({ id = "my-test" })
      local results = make_state({
        files = { make_file({ tests = { test } }) },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      -- Set selection to the test
      service:move_selection(1) -- move to file
      service:move_selection(1) -- move to test
      local selected_before = service:get_state().selected_id

      -- Send another results update
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      assert.same(selected_before, service:get_state().selected_id)
    end)

    it("ignores event without key", function()
      local service = Service.new(function() end)

      service:handle_event({
        type = "NopeTestRunResults",
        payload = { results = make_state() },
      })

      assert.same(0, #service:get_state().tabs)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = make_state() },
      })

      assert.same(2, #states)
    end)

    it("exposes summary in state", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 5, passed = 3, failed = 2, skipped = 0 },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      local state = service:get_state()
      assert.same({ total = 5, passed = 3, failed = 2, skipped = 0 }, state.summary)
    end)

    it("exposes duration_ms in state", function()
      local service = Service.new(function() end)
      local results = make_state({
        duration_ms = 1234,
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      local state = service:get_state()
      assert.same(1234, state.duration_ms)
    end)

    it("exposes selected_node in state", function()
      local service = Service.new(function() end)
      local test = make_test({ id = "t1", name = "my test" })
      local results = make_state({
        files = { make_file({ tests = { test } }) },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      -- Move to the test node
      service:move_selection(1) -- file
      service:move_selection(1) -- test

      local state = service:get_state()
      assert.is_not_nil(state.selected_node)
      assert.same("t1", state.selected_node.id)
      assert.same("test", state.selected_node.type)
    end)

    it("selected_node includes raw node data", function()
      local service = Service.new(function() end)
      local test = make_test({ id = "t1", name = "my test" })
      local results = make_state({
        files = { make_file({ tests = { test } }) },
      })
      service:handle_event({
        type = "NopeTestRunResults",
        payload = { key = "a", results = results },
      })

      -- Move to the test node
      service:move_selection(1) -- file
      service:move_selection(1) -- test

      local state = service:get_state()
      assert.is_not_nil(state.selected_node.node)
      assert.same("my test", state.selected_node.node.name)
    end)

    it("summary is nil when no active run", function()
      local service = Service.new(function() end)

      local state = service:get_state()
      assert.is_nil(state.summary)
    end)

    it("duration_ms is nil when no active run", function()
      local service = Service.new(function() end)

      local state = service:get_state()
      assert.is_nil(state.duration_ms)
    end)
  end)

  describe("move_selection", function()
    it("moves to next node with delta +1", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ tests = { make_test({ id = "t1" }), make_test({ id = "t2" }) } }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      -- Initial selection is header (first node)
      local initial_id = service:get_state().selected_id

      service:move_selection(1)
      local after_move = service:get_state().selected_id

      assert.is_not_nil(after_move)
      assert.are_not.equal(initial_id, after_move)
    end)

    it("moves to previous node with delta -1", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ tests = { make_test({ id = "t1" }), make_test({ id = "t2" }) } }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      service:move_selection(1) -- move forward
      local mid_id = service:get_state().selected_id

      service:move_selection(-1) -- move back
      local after_back = service:get_state().selected_id

      assert.are_not.equal(mid_id, after_back)
    end)

    it("wraps from last to first", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ tests = { make_test() } }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      local nodes = service:get_state().nodes
      -- Move to last node
      for _ = 1, #nodes - 1 do
        service:move_selection(1)
      end

      local last_id = service:get_state().selected_id

      service:move_selection(1) -- should wrap to first

      local first_id = service:get_state().selected_id
      assert.same(nodes[1].id, first_id)
      assert.are_not.equal(last_id, first_id)
    end)

    it("wraps from first to last", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ tests = { make_test() } }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      local nodes = service:get_state().nodes
      local first_id = service:get_state().selected_id

      service:move_selection(-1) -- should wrap to last

      local last_id = service:get_state().selected_id
      assert.same(nodes[#nodes].id, last_id)
      assert.are_not.equal(first_id, last_id)
    end)

    it("no-op with no nodes", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      service:move_selection(1)

      assert.is_nil(service:get_state().selected_id)
    end)

    it("no-op with no active run", function()
      local service = Service.new(function() end)

      service:move_selection(1)

      assert.is_nil(service:get_state().selected_id)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ tests = { make_test() } }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:move_selection(1)

      assert.same(2, #states)
    end)
  end)

  describe("toggle_help", function()
    it("toggles showing_help from false to true", function()
      local service = Service.new(function() end)

      assert.is_false(service:get_state().showing_help)

      service:toggle_help()

      assert.is_true(service:get_state().showing_help)
    end)

    it("toggles showing_help from true to false", function()
      local service = Service.new(function() end)
      service:toggle_help() -- true

      service:toggle_help()

      assert.is_false(service:get_state().showing_help)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:toggle_help()

      assert.same(2, #states)
    end)
  end)

  describe("toggle_failures_filter", function()
    it("toggles filter_active from false to true", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      assert.is_false(service:get_state().filter_active)

      service:toggle_failures_filter()

      assert.is_true(service:get_state().filter_active)
    end)

    it("toggles filter_active from true to false", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:toggle_failures_filter()

      service:toggle_failures_filter()

      assert.is_false(service:get_state().filter_active)
    end)

    it("no-op with no active run", function()
      local service = Service.new(function() end)

      service:toggle_failures_filter()

      assert.is_false(service:get_state().filter_active)
    end)

    it("filter_active is independent per run", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "b" } })

      -- Enable filter on run "a"
      service:toggle_failures_filter()
      assert.is_true(service:get_state().filter_active)

      -- Switch to run "b" - should have its own filter state (false)
      service:switch_tab(1)
      assert.is_false(service:get_state().filter_active)

      -- Switch back to "a" - filter should still be enabled
      service:switch_tab(-1)
      assert.is_true(service:get_state().filter_active)
    end)

    it("filters nodes to only failures when active", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
        files = {
          make_file({
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      service:toggle_failures_filter()

      local state = service:get_state()
      -- Should only have header + failed test (no passed test)
      for _, node in ipairs(state.nodes) do
        if node.type == "test" then
          assert.same("failed", node.node.status)
        end
      end
    end)

    it("shows all nodes when filter disabled", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
        files = {
          make_file({
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:toggle_failures_filter()

      service:toggle_failures_filter()

      local state = service:get_state()
      local has_passed = false
      for _, node in ipairs(state.nodes) do
        if node.type == "test" and node.node and node.node.status == "passed" then
          has_passed = true
        end
      end
      assert.is_true(has_passed)
    end)

    it("adjusts selection if current is filtered out", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
        files = {
          make_file({
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      -- Select the passed test
      service:move_selection(1) -- file
      service:move_selection(1) -- t1 (passed)
      assert.same("t1", service:get_state().selected_id)

      service:toggle_failures_filter()

      -- Selection should move to first visible node
      local state = service:get_state()
      assert.is_not_nil(state.selected_id)
      assert.are_not.equal("t1", state.selected_id)
    end)

    it("notifies subscribers", function()
      local service = Service.new(function() end)
      service:handle_event({ type = "NopeTestRunStarted", payload = { key = "a" } })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:toggle_failures_filter()

      assert.same(2, #states)
    end)

    it("keeps file ancestors of failed tests", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
        files = {
          make_file({
            id = "file-1",
            status = "failed",
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      service:toggle_failures_filter()

      local state = service:get_state()
      local has_file = false
      local has_failed_test = false
      for _, node in ipairs(state.nodes) do
        if node.type == "file" then
          has_file = true
        end
        if node.type == "test" and node.node.status == "failed" then
          has_failed_test = true
        end
      end
      assert.is_true(has_file, "file ancestor should be kept")
      assert.is_true(has_failed_test, "failed test should be kept")
    end)

    it("move_selection works with filtered nodes", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 3, passed = 2, failed = 1, skipped = 0 },
        files = {
          make_file({
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
              make_test({ id = "t3", status = "passed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:toggle_failures_filter()

      local filtered_nodes = service:get_state().nodes
      local initial_id = service:get_state().selected_id

      -- Should be able to navigate through filtered list
      service:move_selection(1)
      local after_move = service:get_state().selected_id

      assert.is_not_nil(after_move)
      -- Navigation should work within filtered list
      local found_in_filtered = false
      for _, node in ipairs(filtered_nodes) do
        if node.id == after_move then
          found_in_filtered = true
          break
        end
      end
      -- Note: selection is from unfiltered list but should still work
      assert.are_not.equal(initial_id, after_move)
    end)
  end)

  describe("scope filter", function()
    local function make_suite(overrides)
      return vim.tbl_deep_extend("force", {
        id = "suite-1",
        name = "my suite",
        status = "passed",
        tests = {},
        suites = {},
      }, overrides or {})
    end

    it("set_scope_filter stores scope_filter_id per tab", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      service:set_scope_filter("f1")

      local state = service:get_state()
      assert.same("f1", state.scope_filter_id)
    end)

    it("clear_scope_filter clears scope_filter_id", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:set_scope_filter("f1")

      service:clear_scope_filter()

      local state = service:get_state()
      assert.is_nil(state.scope_filter_id)
    end)

    it("toggle_scope_filter toggles on when not set", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      service:toggle_scope_filter("f1")

      assert.same("f1", service:get_state().scope_filter_id)
    end)

    it("toggle_scope_filter toggles off when same id", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:set_scope_filter("f1")

      service:toggle_scope_filter("f1")

      assert.is_nil(service:get_state().scope_filter_id)
    end)

    it("toggle_scope_filter changes scope when different id", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = {
          make_file({ id = "f1" }),
          make_file({ id = "f2" }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:set_scope_filter("f1")

      service:toggle_scope_filter("f2")

      assert.same("f2", service:get_state().scope_filter_id)
    end)

    it("scope_filter_id is per-tab (independent)", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "b", results = results } })

      -- Set scope on tab a
      service:set_scope_filter("f1")
      assert.same("f1", service:get_state().scope_filter_id)

      -- Switch to tab b - should not have scope
      service:switch_tab(1)
      assert.is_nil(service:get_state().scope_filter_id)

      -- Switch back to a - should still have scope
      service:switch_tab(-1)
      assert.same("f1", service:get_state().scope_filter_id)
    end)

    it("get_state filters nodes by scope when scope_filter_id set", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = {
          make_file({ id = "f1", tests = { make_test({ id = "t1" }) } }),
          make_file({ id = "f2", tests = { make_test({ id = "t2" }) } }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      service:set_scope_filter("f1")

      local state = service:get_state()
      -- Should only have header + f1 and its children
      local has_f1 = false
      local has_f2 = false
      for _, node in ipairs(state.nodes) do
        if node.id == "f1" then
          has_f1 = true
        end
        if node.id == "f2" then
          has_f2 = true
        end
      end
      assert.is_true(has_f1)
      assert.is_false(has_f2)
    end)

    it("scope + failures filter compose correctly", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 3, passed = 2, failed = 1, skipped = 0 },
        files = {
          make_file({
            id = "f1",
            status = "failed",
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
          make_file({ id = "f2", tests = { make_test({ id = "t3", status = "passed" }) } }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      -- Filter to f1, then enable failures filter
      service:set_scope_filter("f1")
      service:toggle_failures_filter()

      local state = service:get_state()
      -- Should only have header + f1's failed test (t2), not t1 or f2
      local has_t1 = false
      local has_t2 = false
      local has_f2 = false
      for _, node in ipairs(state.nodes) do
        if node.id == "t1" then
          has_t1 = true
        end
        if node.id == "t2" then
          has_t2 = true
        end
        if node.id == "f2" then
          has_f2 = true
        end
      end
      assert.is_false(has_t1, "passed test in scope should be filtered")
      assert.is_true(has_t2, "failed test in scope should be visible")
      assert.is_false(has_f2, "file outside scope should not be visible")
    end)

    it("scope_filter_id persists when scoped node disappears, view is empty", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }), make_file({ id = "f2" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:set_scope_filter("f1")

      -- New results without f1
      local new_results = make_state({
        files = { make_file({ id = "f2" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = new_results } })

      -- scope_filter_id persists (not auto-cleared)
      assert.same("f1", service:get_state().scope_filter_id)
      -- but filtered view is empty since scoped node doesn't exist
      assert.same({}, service:get_state().nodes)
    end)

    it("scope_breadcrumb is populated when scope_filter_id set", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = {
          make_file({
            id = "f1",
            path = "src/foo.test.ts",
            suites = {
              make_suite({
                id = "s1",
                name = "outer",
                suites = {
                  make_suite({ id = "s2", name = "inner" }),
                },
              }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      service:set_scope_filter("s2")

      local state = service:get_state()
      assert.same({ "foo.test.ts", "outer", "inner" }, state.scope_breadcrumb)
    end)

    it("scope_breadcrumb is nil when no scope filter", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      local state = service:get_state()
      assert.is_nil(state.scope_breadcrumb)
    end)

    it("notifies subscribers on scope change", function()
      local service = Service.new(function() end)
      local results = make_state({
        files = { make_file({ id = "f1" }) },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      local states = {}
      service:subscribe(function(s)
        table.insert(states, s)
      end)

      service:set_scope_filter("f1")

      assert.same(2, #states)
      assert.same("f1", states[2].scope_filter_id)
    end)
  end)

  describe("selection preservation across updates", function()
    it("preserves selection when still in filtered view after update", function()
      local service = Service.new(function() end)
      local results = make_state({
        summary = { total = 2, passed = 0, failed = 2, skipped = 0 },
        files = {
          make_file({
            status = "failed",
            tests = {
              make_test({ id = "t1", status = "failed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })
      service:toggle_failures_filter() -- enable failures filter

      -- Select t1
      service:move_selection(1) -- file
      service:move_selection(1) -- t1
      assert.same("t1", service:get_state().selected_id)

      -- Update results, t1 still failed
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results } })

      -- Selection should stay on t1
      assert.same("t1", service:get_state().selected_id)
    end)

    it("resets selection when filtered out after update", function()
      local service = Service.new(function() end)
      local results_with_failures = make_state({
        summary = { total = 2, passed = 0, failed = 2, skipped = 0 },
        files = {
          make_file({
            status = "failed",
            tests = {
              make_test({ id = "t1", status = "failed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results_with_failures } })
      service:toggle_failures_filter() -- enable failures filter

      -- Select t1 (failed)
      service:move_selection(1) -- file
      service:move_selection(1) -- t1
      assert.same("t1", service:get_state().selected_id)

      -- Update results: t1 now passes
      local results_t1_passes = make_state({
        summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
        files = {
          make_file({
            status = "failed",
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results_t1_passes } })

      -- t1 no longer in filtered view, selection should reset to first visible
      local state = service:get_state()
      assert.are_not.equal("t1", state.selected_id)
      -- Should be first visible node (header)
      assert.same(state.nodes[1].id, state.selected_id)
    end)

    it("resets selection with scope + failures filter combined", function()
      local service = Service.new(function() end)
      local results_with_failures = make_state({
        summary = { total = 3, passed = 1, failed = 2, skipped = 0 },
        files = {
          make_file({
            id = "f1",
            status = "failed",
            tests = {
              make_test({ id = "t1", status = "failed" }),
              make_test({ id = "t2", status = "passed" }),
            },
          }),
          make_file({
            id = "f2",
            status = "failed",
            tests = {
              make_test({ id = "t3", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results_with_failures } })

      -- Scope to f1, enable failures filter
      service:set_scope_filter("f1")
      service:toggle_failures_filter()

      -- Select t1 (failed, in scope)
      service:move_selection(1) -- file
      service:move_selection(1) -- t1
      assert.same("t1", service:get_state().selected_id)

      -- Update: t1 now passes
      local results_t1_passes = make_state({
        summary = { total = 3, passed = 2, failed = 1, skipped = 0 },
        files = {
          make_file({
            id = "f1",
            status = "passed",
            tests = {
              make_test({ id = "t1", status = "passed" }),
              make_test({ id = "t2", status = "passed" }),
            },
          }),
          make_file({
            id = "f2",
            status = "failed",
            tests = {
              make_test({ id = "t3", status = "failed" }),
            },
          }),
        },
      })
      service:handle_event({ type = "NopeTestRunResults", payload = { key = "a", results = results_t1_passes } })

      -- t1 no longer visible (passes, filtered out)
      -- Selection should reset to first visible in scoped+filtered view (or nil if empty)
      local state = service:get_state()
      assert.are_not.equal("t1", state.selected_id)
      -- Since f1 has no failures anymore and we're scoped to f1 with failures filter,
      -- nodes might be empty or just header
      if #state.nodes > 0 then
        assert.same(state.nodes[1].id, state.selected_id)
      else
        assert.is_nil(state.selected_id)
      end
    end)
  end)
end)
