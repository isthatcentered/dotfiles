local C = require("nope.ui2")
local BC = require("nope.consumers.WindowConsumer.Navigation.ui.NavigationPanel")

---@return C.BoxConstraints
local function unconstrained()
  return {
    max_width = math.huge,
    min_width = 0,
  }
end

describe("NavigationPanel components", function()
  describe("Header", function()
    it("shows running state with progress", function()
      local state = { status = "pending", summary = { total = 10, passed = 3, failed = 0, skipped = 0 } }
      local widget = BC.Header(state, false, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "◌ Running... 3/10" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("shows passed when done with no failures", function()
      local state = { status = "done", summary = { total = 5, passed = 5, failed = 0, skipped = 0 }, duration_ms = 1234 }
      local widget = BC.Header(state, false, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✓ 5 total, 5 passed (1.23s)" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("shows failed when done with failures", function()
      local state = { status = "done", summary = { total = 5, passed = 3, failed = 2, skipped = 0 } }
      local widget = BC.Header(state, false, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✗ 5 total, 3 passed, 2 failed" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("shows cancelled status", function()
      local state = { status = "cancelled", summary = { total = 0, passed = 0, failed = 0, skipped = 0 } }
      local widget = BC.Header(state, false, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "○ Cancelled" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("shows idle for unknown status", function()
      local state = { status = "idle", summary = { total = 0, passed = 0, failed = 0, skipped = 0 } }
      local widget = BC.Header(state, false, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "○ Idle" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("shows filter indicator when show_only_failures is true", function()
      local state = { status = "done", summary = { total = 5, passed = 5, failed = 0, skipped = 0 } }
      local widget = BC.Header(state, false, true)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✓ 5 total, 5 passed [󰈲 failures only]" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("applies Visual highlight when selected", function()
      local state = { status = "done", summary = { total = 1, passed = 1, failed = 0, skipped = 0 } }
      local widget = BC.Header(state, true, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 40, min_width = 0 })

      local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
      local has_visual = false
      for _, mark in ipairs(extmarks) do
        if mark[4].hl_group == "Visual" then
          has_visual = true
        end
      end
      assert.is_true(has_visual)
    end)
  end)

  describe("TabBar", function()
    it("renders single tab with brackets when active", function()
      local tabs = {
        { key = "a", label = "test", status = "done", has_failures = false },
      }

      local component = BC.TabBar(tabs, "a")
      C.render(0, component, unconstrained())

      assert.same({
        "[✓ test]",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("renders running tab with spinner icon", function()
      local tabs = {
        { key = "a", label = "test", status = "running", has_failures = false },
      }

      local component = BC.TabBar(tabs, "a")
      C.render(0, component, unconstrained())

      assert.same({
        "[◌ test]",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("renders failed tab with error icon", function()
      local tabs = {
        { key = "a", label = "test", status = "done", has_failures = true },
      }

      local component = BC.TabBar(tabs, "a")
      C.render(0, component, unconstrained())

      assert.same({
        "[✗ test]",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("renders cancelled tab with empty circle icon", function()
      local tabs = {
        { key = "a", label = "test", status = "cancelled", has_failures = false },
      }

      local component = BC.TabBar(tabs, "a")
      C.render(0, component, unconstrained())

      assert.same({
        "[○ test]",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("renders multiple tabs with separator", function()
      local tabs = {
        { key = "a", label = "first", status = "done", has_failures = false },
        { key = "b", label = "second", status = "running", has_failures = false },
      }

      local component = BC.TabBar(tabs, "a")
      C.render(0, component, unconstrained())

      assert.same({
        "[✓ first]│ ◌ second ",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("inactive tab has no brackets", function()
      local tabs = {
        { key = "a", label = "one", status = "done", has_failures = false },
        { key = "b", label = "two", status = "done", has_failures = false },
      }

      local component = BC.TabBar(tabs, "b")
      C.render(0, component, unconstrained())

      assert.same({
        " ✓ one │[✓ two]",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("returns empty when no tabs", function()
      local component = BC.TabBar({}, nil)
      C.render(0, component, unconstrained())

      assert.same({
        "",
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)

  describe("Footer", function()
    it("renders help hint", function()
      local component = BC.Footer({})
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(lines[1]:match("g%? help") ~= nil)
    end)

    it("shows failures hint when filter_active", function()
      local component = BC.Footer({ filter_active = true })
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(lines[1]:match("ff") ~= nil, "Should show ff shortcut")
      assert.is_true(
        lines[1]:match("failures") ~= nil or lines[1]:match("filter") ~= nil,
        "Should mention failures/filter"
      )
    end)

    it("shows scope hint when scope_filter_id set", function()
      local component = BC.Footer({ scope_filter_id = "f1" })
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(lines[1]:match("fc") ~= nil, "Should show fc shortcut")
    end)

    it("shows both hints when both filters active", function()
      local component = BC.Footer({ filter_active = true, scope_filter_id = "f1" })
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(lines[1]:match("ff") ~= nil, "Should show ff shortcut")
      assert.is_true(lines[1]:match("fc") ~= nil, "Should show fc shortcut")
    end)
  end)

  describe("Breadcrumb", function()
    it("returns empty widget when no scope filter", function()
      local component = BC.Breadcrumb(nil)
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.same({ "" }, lines)
    end)

    it("renders path with separator", function()
      local component = BC.Breadcrumb({ "foo.test.ts", "outer", "inner" })
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(lines[1]:match("foo.test.ts") ~= nil)
      assert.is_true(lines[1]:match("outer") ~= nil)
      assert.is_true(lines[1]:match("inner") ~= nil)
      -- Check separator exists (could be >, /, or other)
      assert.is_true(lines[1]:match("[>/]") ~= nil or lines[1]:match(" ") ~= nil)
    end)

    it("renders single element without separator", function()
      local component = BC.Breadcrumb({ "foo.test.ts" })
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(lines[1]:match("foo.test.ts") ~= nil)
    end)
  end)

  describe("FileName", function()
    it("renders file with status icon and filename", function()
      local file = { id = "f1", path = "src/utils/test.lua", status = "passed" }
      local widget = BC.FileName(file, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✓ 󰈙 test.lua" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("uses failed highlight for failed file", function()
      local file = { id = "f1", path = "test.lua", status = "failed" }
      local widget = BC.FileName(file, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✗ 󰈙 test.lua" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("applies Visual highlight when selected", function()
      local file = { id = "f1", path = "test.lua", status = "passed" }
      local widget = BC.FileName(file, true)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 40, min_width = 0 })

      local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
      local has_visual = false
      for _, mark in ipairs(extmarks) do
        if mark[4].hl_group == "Visual" then
          has_visual = true
        end
      end
      assert.is_true(has_visual)
    end)
  end)

  describe("SuiteName", function()
    it("renders suite with status icon and name", function()
      local suite = { id = "s1", name = "my suite", status = "passed" }
      local widget = BC.SuiteName(suite, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✓ 󰙅 my suite" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("uses failed highlight for failed suite", function()
      local suite = { id = "s1", name = "my suite", status = "failed" }
      local widget = BC.SuiteName(suite, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✗ 󰙅 my suite" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("applies Visual highlight when selected", function()
      local suite = { id = "s1", name = "my suite", status = "passed" }
      local widget = BC.SuiteName(suite, true)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 40, min_width = 0 })

      local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
      local has_visual = false
      for _, mark in ipairs(extmarks) do
        if mark[4].hl_group == "Visual" then
          has_visual = true
        end
      end
      assert.is_true(has_visual)
    end)
  end)

  describe("TestName", function()
    it("renders test with status icon and name", function()
      local test = { id = "t1", name = "my test", full_name = "suite > my test", status = "passed" }
      local widget = BC.TestName(test, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✓ my test" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("uses failed highlight for failed test", function()
      local test = { id = "t1", name = "my test", full_name = "my test", status = "failed" }
      local widget = BC.TestName(test, false)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 80, min_width = 0 })

      assert.same({ "✗ my test" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("applies Visual highlight when selected", function()
      local test = { id = "t1", name = "my test", full_name = "my test", status = "passed" }
      local widget = BC.TestName(test, true)

      local buf = vim.api.nvim_create_buf(false, true)
      C.render(buf, widget, { max_width = 40, min_width = 0 })

      local extmarks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
      local has_visual = false
      for _, mark in ipairs(extmarks) do
        if mark[4].hl_group == "Visual" then
          has_visual = true
        end
      end
      assert.is_true(has_visual)
    end)
  end)

  describe("HelpOverlay", function()
    it("renders title", function()
      local component = BC.HelpOverlay()
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Line may be padded due to width calculation
      assert.is_true(lines[1]:match("^Keyboard Shortcuts") ~= nil)
    end)

    it("renders separator line", function()
      local component = BC.HelpOverlay()
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.is_true(lines[2]:match("─") ~= nil)
    end)

    it("renders shortcuts", function()
      local component = BC.HelpOverlay()
      C.render(0, component, unconstrained())

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should have more than 2 lines (title + separator + shortcuts)
      assert.is_true(#lines > 2)
      -- Check one shortcut exists
      local found_shortcut = false
      for _, line in ipairs(lines) do
        if line:match("<C%-n>") or line:match("Navigate") then
          found_shortcut = true
          break
        end
      end
      assert.is_true(found_shortcut)
    end)
  end)

  describe("NavigationPanel", function()
    it("renders HelpOverlay when showing_help=true", function()
      local component = BC.NavigationPanel({
        tabs = {},
        nodes = {},
        selected_id = nil,
        active_tab_key = nil,
        showing_help = true,
      })
      C.render(0, component, { max_width = 40, min_width = 0 })

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local has_keyboard_shortcuts = false
      for _, line in ipairs(lines) do
        if line:match("Keyboard Shortcuts") then
          has_keyboard_shortcuts = true
          break
        end
      end
      assert.is_true(has_keyboard_shortcuts, "Should render HelpOverlay title")
    end)

    it("renders EmptyState + Footer when no nodes", function()
      local component = BC.NavigationPanel({
        tabs = {},
        nodes = {},
        selected_id = nil,
        active_tab_key = nil,
        showing_help = false,
      })
      C.render(0, component, { max_width = 40, min_width = 0 })

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- EmptyState has "No test run active" centered
      local has_empty_state = false
      local has_footer = false
      for _, line in ipairs(lines) do
        if line:match("No test run active") then
          has_empty_state = true
        end
        if line:match("g%? help") then
          has_footer = true
        end
      end
      assert.is_true(has_empty_state, "Should render EmptyState")
      assert.is_true(has_footer, "Should render Footer")
    end)

    it("renders TreeNodeRows + Footer when nodes present (no tabs)", function()
      local nodes = {
        { id = "n1", type = "test", _depth = 0, node = { id = "n1", name = "test one", full_name = "test one", status = "passed" } },
        { id = "n2", type = "test", _depth = 0, node = { id = "n2", name = "test two", full_name = "test two", status = "failed" } },
      }
      local component = BC.NavigationPanel({
        tabs = {},
        nodes = nodes,
        selected_id = nil,
        active_tab_key = nil,
        showing_help = false,
      })
      C.render(0, component, { max_width = 40, min_width = 0 })

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- Should have node rows + footer, no empty state
      local has_node1 = false
      local has_node2 = false
      local has_footer = false
      local has_empty_state = false
      for _, line in ipairs(lines) do
        if line:match("test one") then
          has_node1 = true
        end
        if line:match("test two") then
          has_node2 = true
        end
        if line:match("g%? help") then
          has_footer = true
        end
        if line:match("No test run active") then
          has_empty_state = true
        end
      end
      assert.is_true(has_node1, "Should render node 1")
      assert.is_true(has_node2, "Should render node 2")
      assert.is_true(has_footer, "Should render Footer")
      assert.is_false(has_empty_state, "Should NOT render EmptyState")
    end)

    it("renders TabBar when tabs present", function()
      local tabs = {
        { key = "t1", label = "run1", status = "done", has_failures = false },
      }
      local nodes = {
        { id = "n1", type = "test", _depth = 0, node = { id = "n1", name = "test one", full_name = "test one", status = "passed" } },
      }
      local component = BC.NavigationPanel({
        tabs = tabs,
        nodes = nodes,
        selected_id = nil,
        active_tab_key = "t1",
        showing_help = false,
      })
      C.render(0, component, { max_width = 40, min_width = 0 })

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      -- First line should be TabBar
      assert.is_true(lines[1]:match("%[.* run1%]") ~= nil, "First line should be TabBar")
      -- Should also have nodes
      local has_node = false
      for _, line in ipairs(lines) do
        if line:match("test one") then
          has_node = true
        end
      end
      assert.is_true(has_node, "Should render node")
    end)

    it("highlights selected node with Visual", function()
      local nodes = {
        { id = "n1", type = "test", _depth = 0, node = { id = "n1", name = "test one", full_name = "test one", status = "passed" } },
        { id = "n2", type = "test", _depth = 0, node = { id = "n2", name = "test two", full_name = "test two", status = "failed" } },
      }
      local component = BC.NavigationPanel({
        tabs = {},
        nodes = nodes,
        selected_id = "n2",
        active_tab_key = nil,
        showing_help = false,
      })
      C.render(0, component, { max_width = 40, min_width = 0 })

      local extmarks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
      local visual_row = nil
      for _, mark in ipairs(extmarks) do
        if mark[4].hl_group == "Visual" then
          visual_row = mark[2]
          break
        end
      end
      assert.is_not_nil(visual_row, "Should have Visual highlight")
      assert.same(1, visual_row, "Visual should be on second row (n2)")
    end)
  end)
end)
