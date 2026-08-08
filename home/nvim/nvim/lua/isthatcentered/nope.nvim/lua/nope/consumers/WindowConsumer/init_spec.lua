local Service = require("nope.consumers.WindowConsumer.Navigation.state.NavigationService")
local WindowConsumer = require("nope.consumers.WindowConsumer")

describe("WindowConsumer", function()
  it("prevents buffer switch in tree window", function()
    local service = Service.new(function() end)
    local consumer = WindowConsumer.new(service)
    consumer:open()

    local original_buf = consumer.tree_buffer
    vim.api.nvim_set_current_win(consumer.tree_window)

    -- Create another buffer and try to display it
    local other_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(consumer.tree_window, other_buf)

    -- Trigger BufEnter autocmd
    vim.cmd("doautocmd BufEnter")

    -- Should revert back to original buffer
    local current_buf = vim.api.nvim_win_get_buf(consumer.tree_window)
    assert.equal(original_buf, current_buf)

    consumer:close()
  end)

  it("prevents buffer switch in details window", function()
    local service = Service.new(function() end)
    local consumer = WindowConsumer.new(service)
    consumer:open()

    local original_buf = consumer.details_buffer
    vim.api.nvim_set_current_win(consumer.details_window)

    local other_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(consumer.details_window, other_buf)

    -- Trigger BufEnter autocmd
    vim.cmd("doautocmd BufEnter")

    local current_buf = vim.api.nvim_win_get_buf(consumer.details_window)
    assert.equal(original_buf, current_buf)

    consumer:close()
  end)

  it("disables hjkl keys", function()
    local service = Service.new(function() end)
    local consumer = WindowConsumer.new(service)
    consumer:open()

    vim.api.nvim_set_current_win(consumer.tree_window)

    -- hjkl should be no-ops - verify they don't error
    for _, key in ipairs({ "h", "j", "k", "l" }) do
      vim.api.nvim_feedkeys(key, "x", false)
    end

    -- Consumer should still be open and functional
    assert.is_true(vim.api.nvim_win_is_valid(consumer.tree_window))

    consumer:close()
  end)

  it("scrolls details window with C-d/C-u", function()
    local service = Service.new(function() end)
    local consumer = WindowConsumer.new(service)
    consumer:open()

    vim.api.nvim_set_current_win(consumer.tree_window)

    -- Fill details buffer with enough content to scroll
    vim.api.nvim_set_option_value("modifiable", true, { buf = consumer.details_buffer })
    local lines = {}
    for i = 1, 100 do
      table.insert(lines, "Line " .. i)
    end
    vim.api.nvim_buf_set_lines(consumer.details_buffer, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = consumer.details_buffer })

    -- Get initial scroll position
    local initial_line = vim.api.nvim_win_call(consumer.details_window, function()
      return vim.fn.line("w0")
    end)

    -- Press C-d to scroll down
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-d>", true, false, true), "x", false)

    local after_scroll = vim.api.nvim_win_call(consumer.details_window, function()
      return vim.fn.line("w0")
    end)

    assert.is_true(after_scroll > initial_line, "C-d should scroll down")

    consumer:close()
  end)

  it("gf opens file at line but keeps consumer open", function()
    local service = Service.new(function() end)
    -- Feed in a test run with file path
    service:handle_event({
      type = "NopeTestRunResults",
      payload = {
        key = "test-key",
        results = {
          files = {
            {
              id = "file-1",
              path = "lua/nope/ui2/init.lua",
              status = "passed",
              tests = {
                {
                  id = "test-1",
                  name = "some test",
                  status = "passed",
                  location = { line = 42, column = 1 },
                },
              },
              suites = {},
            },
          },
          summary = { total = 1, passed = 1, failed = 0, skipped = 0 },
        },
      },
    })

    local consumer = WindowConsumer.new(service)
    consumer:open()

    local tree_win = consumer.tree_window
    local details_win = consumer.details_window
    vim.api.nvim_set_current_win(tree_win)

    -- Navigate to the test node (nodes: header, file, test)
    service:move_selection(1) -- move to test

    -- Press gf
    vim.api.nvim_feedkeys("gf", "x", false)

    -- Consumer windows should still be valid
    assert.is_true(vim.api.nvim_win_is_valid(tree_win))
    assert.is_true(vim.api.nvim_win_is_valid(details_win))

    -- File should be opened in a different window
    local current_buf_name = vim.api.nvim_buf_get_name(0)
    assert.is_true(current_buf_name:match("ui2/init.lua") ~= nil)

    consumer:close()
  end)

  describe("open", function()
    it("creates tree and details windows", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      assert.is_true(vim.api.nvim_win_is_valid(consumer.tree_window))
      assert.is_true(vim.api.nvim_win_is_valid(consumer.details_window))
      assert.is_true(vim.api.nvim_buf_is_valid(consumer.tree_buffer))
      assert.is_true(vim.api.nvim_buf_is_valid(consumer.details_buffer))

      consumer:close()
    end)

    it("sets window options (no number, wrap settings)", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      -- Tree window: no number, no wrap
      assert.is_false(vim.wo[consumer.tree_window].number)
      assert.is_false(vim.wo[consumer.tree_window].relativenumber)
      assert.is_false(vim.wo[consumer.tree_window].wrap)

      -- Details window: no number, wrap enabled
      assert.is_false(vim.wo[consumer.details_window].number)
      assert.is_false(vim.wo[consumer.details_window].relativenumber)
      assert.is_true(vim.wo[consumer.details_window].wrap)

      consumer:close()
    end)

    it("does nothing if already open", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      local tree_win = consumer.tree_window
      local details_win = consumer.details_window

      consumer:open() -- second open should be no-op

      assert.equal(tree_win, consumer.tree_window)
      assert.equal(details_win, consumer.details_window)

      consumer:close()
    end)

    it("subscribes to service state changes", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      -- Add test data
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-key",
          results = {
            files = {},
            summary = { total = 1, passed = 1, failed = 0, skipped = 0 },
          },
        },
      })

      -- Tree buffer should have been rendered with content
      local lines = vim.api.nvim_buf_get_lines(consumer.tree_buffer, 0, -1, false)
      assert.is_true(#lines > 0)

      consumer:close()
    end)
  end)

  describe("toggle", function()
    it("opens when closed", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)

      consumer:toggle()

      assert.is_true(vim.api.nvim_win_is_valid(consumer.tree_window))
      assert.is_true(vim.api.nvim_win_is_valid(consumer.details_window))

      consumer:close()
    end)

    it("closes when open", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      local tree_win = consumer.tree_window

      consumer:toggle()

      assert.is_false(vim.api.nvim_win_is_valid(tree_win))
    end)
  end)

  describe("make", function()
    it("creates consumer with service wired to events", function()
      local events_received = {}
      local on_event = function(cb)
        -- Immediately send an event
        cb({
          type = "NopeTestRunStarted",
          payload = { key = "test-run" },
        })
        return function() end
      end

      local consumer = WindowConsumer.make(on_event, function() end)
      consumer:open()

      -- Service should have received the event
      local state = consumer.service:get_state()
      assert.equal(1, #state.tabs)

      consumer:close()
    end)

    it("forwards events to service", function()
      local event_callback
      local on_event = function(cb)
        event_callback = cb
        return function() end
      end

      local consumer = WindowConsumer.make(on_event, function() end)
      consumer:open()

      -- Send event through the callback
      event_callback({
        type = "NopeTestRunResults",
        payload = {
          key = "test-key",
          results = {
            files = {},
            summary = { total = 5, passed = 5, failed = 0, skipped = 0 },
          },
        },
      })

      local state = consumer.service:get_state()
      assert.same({ total = 5, passed = 5, failed = 0, skipped = 0 }, state.summary)

      consumer:close()
    end)
  end)

  describe("close", function()
    it("closes both windows and deletes buffers", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      local tree_win = consumer.tree_window
      local details_win = consumer.details_window
      local tree_buf = consumer.tree_buffer
      local details_buf = consumer.details_buffer

      consumer:close()

      assert.is_false(vim.api.nvim_win_is_valid(tree_win))
      assert.is_false(vim.api.nvim_win_is_valid(details_win))
      assert.is_false(vim.api.nvim_buf_is_valid(tree_buf))
      assert.is_false(vim.api.nvim_buf_is_valid(details_buf))
    end)

    it("closes all when tree window is manually closed", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      local tree_win = consumer.tree_window
      local details_win = consumer.details_window
      local tree_buf = consumer.tree_buffer
      local details_buf = consumer.details_buffer

      -- Simulate user doing :q on tree window
      vim.api.nvim_win_close(tree_win, true)

      assert.is_false(vim.api.nvim_win_is_valid(details_win))
      assert.is_false(vim.api.nvim_buf_is_valid(tree_buf))
      assert.is_false(vim.api.nvim_buf_is_valid(details_buf))
    end)

    it("closes all when details window is manually closed", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()

      local tree_win = consumer.tree_window
      local details_win = consumer.details_window
      local tree_buf = consumer.tree_buffer
      local details_buf = consumer.details_buffer

      -- Simulate user doing :q on details window
      vim.api.nvim_win_close(details_win, true)

      assert.is_false(vim.api.nvim_win_is_valid(tree_win))
      assert.is_false(vim.api.nvim_buf_is_valid(tree_buf))
      assert.is_false(vim.api.nvim_buf_is_valid(details_buf))
    end)
  end)

  describe("tab keymaps", function()
    local function setup_multi_tab_service()
      local service = Service.new(function() end)
      -- Create 3 tabs
      for i = 1, 3 do
        service:handle_event({
          type = "NopeTestRunResults",
          payload = {
            key = "run-" .. i,
            results = {
              files = {},
              summary = { total = 1, passed = 1, failed = 0, skipped = 0 },
            },
          },
        })
      end
      return service
    end

    it("H switches to previous tab", function()
      local service = setup_multi_tab_service()
      service:switch_to_tab(2) -- start at tab 2

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      vim.api.nvim_feedkeys("H", "x", false)

      local state = service:get_state()
      assert.equal("run-1", state.active_tab_key)

      consumer:close()
    end)

    it("L switches to next tab", function()
      local service = setup_multi_tab_service()
      service:switch_to_tab(1) -- start at tab 1

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      vim.api.nvim_feedkeys("L", "x", false)

      local state = service:get_state()
      assert.equal("run-2", state.active_tab_key)

      consumer:close()
    end)

    it("[ switches to previous tab", function()
      local service = setup_multi_tab_service()
      service:switch_to_tab(2)

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      vim.api.nvim_feedkeys("[", "x", false)

      local state = service:get_state()
      assert.equal("run-1", state.active_tab_key)

      consumer:close()
    end)

    it("] switches to next tab", function()
      local service = setup_multi_tab_service()
      service:switch_to_tab(1)

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      vim.api.nvim_feedkeys("]", "x", false)

      local state = service:get_state()
      assert.equal("run-2", state.active_tab_key)

      consumer:close()
    end)

    it("1-9 switches to tab by index", function()
      local service = setup_multi_tab_service()

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      vim.api.nvim_feedkeys("3", "x", false)
      assert.equal("run-3", service:get_state().active_tab_key)

      vim.api.nvim_feedkeys("1", "x", false)
      assert.equal("run-1", service:get_state().active_tab_key)

      consumer:close()
    end)
  end)

  describe("help keymaps", function()
    it("g? toggles help overlay", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      assert.is_false(service:get_state().showing_help)

      vim.api.nvim_feedkeys("g?", "x", false)
      assert.is_true(service:get_state().showing_help)

      vim.api.nvim_feedkeys("g?", "x", false)
      assert.is_false(service:get_state().showing_help)

      consumer:close()
    end)

    it("Esc closes help when showing", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      service:toggle_help()
      assert.is_true(service:get_state().showing_help)

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
      assert.is_false(service:get_state().showing_help)

      consumer:close()
    end)

    it("Esc does nothing when help not showing", function()
      local service = Service.new(function() end)
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-key",
          results = {
            files = {},
            summary = { total = 1, passed = 1, failed = 0, skipped = 0 },
          },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      assert.is_false(service:get_state().showing_help)

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

      -- Consumer should still be open (Esc didn't close it)
      assert.is_true(vim.api.nvim_win_is_valid(consumer.tree_window))
      assert.is_false(service:get_state().showing_help)

      consumer:close()
    end)
  end)

  describe("action keymaps", function()
    it("s sends stop command", function()
      local commands = {}
      local service = Service.new(function(cmd)
        table.insert(commands, cmd)
      end)
      service:handle_event({
        type = "NopeTestRunStarted",
        payload = { key = "test-run" },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      vim.api.nvim_feedkeys("s", "x", false)

      assert.equal(1, #commands)
      assert.equal("NopeStopRun", commands[1].type)
      assert.equal("test-run", commands[1].payload.key)

      consumer:close()
    end)

    it("x closes current tab", function()
      local commands = {}
      local service = Service.new(function(cmd)
        table.insert(commands, cmd)
      end)
      -- Create 2 tabs
      for i = 1, 2 do
        service:handle_event({
          type = "NopeTestRunResults",
          payload = {
            key = "run-" .. i,
            results = { files = {}, summary = { total = 1, passed = 1, failed = 0, skipped = 0 } },
          },
        })
      end

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      assert.equal(2, #service:get_state().tabs)

      vim.api.nvim_feedkeys("x", "x", false)

      assert.equal(1, #service:get_state().tabs)
      assert.equal(1, #commands)
      assert.equal("NopeStopRun", commands[1].type)

      consumer:close()
    end)

    it("x closes window when closing last tab", function()
      local service = Service.new(function() end)
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "run-1",
          results = { files = {}, summary = { total = 1, passed = 1, failed = 0, skipped = 0 } },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()

      local tree_win = consumer.tree_window
      vim.api.nvim_set_current_win(tree_win)

      assert.equal(1, #service:get_state().tabs)

      vim.api.nvim_feedkeys("x", "x", false)

      -- Window should be closed since last tab was closed
      assert.is_false(vim.api.nvim_win_is_valid(tree_win))
    end)

    it("ff toggles failures filter", function()
      local service = Service.new(function() end)
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-key",
          results = { files = {}, summary = { total = 1, passed = 0, failed = 1, skipped = 0 } },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      assert.is_false(service:get_state().filter_active)

      vim.api.nvim_feedkeys("ff", "x", false)
      assert.is_true(service:get_state().filter_active)

      vim.api.nvim_feedkeys("ff", "x", false)
      assert.is_false(service:get_state().filter_active)

      consumer:close()
    end)

    it("<CR> toggles scope filter with selected_id", function()
      local service = Service.new(function() end)
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-key",
          results = {
            files = {
              { id = "f1", path = "test.ts", status = "passed", tests = {}, suites = {} },
            },
            summary = { total = 1, passed = 1, failed = 0, skipped = 0 },
          },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      -- Move to file node
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "x", false)
      assert.same("f1", service:get_state().selected_id)

      -- Press enter to scope to file
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
      assert.same("f1", service:get_state().scope_filter_id)

      -- Press enter again to clear scope
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
      assert.is_nil(service:get_state().scope_filter_id)

      consumer:close()
    end)

    it("fc clears scope filter", function()
      local service = Service.new(function() end)
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-key",
          results = {
            files = {
              { id = "f1", path = "test.ts", status = "passed", tests = {}, suites = {} },
            },
            summary = { total = 1, passed = 1, failed = 0, skipped = 0 },
          },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      -- Set scope filter
      service:set_scope_filter("f1")
      assert.same("f1", service:get_state().scope_filter_id)

      -- Clear with fc
      vim.api.nvim_feedkeys("fc", "x", false)
      assert.is_nil(service:get_state().scope_filter_id)

      consumer:close()
    end)
  end)

  describe("render guards", function()
    it("_render_tree handles nil buffer gracefully", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)

      -- Don't open, so buffers are nil
      -- Call internal render - should not error
      local ok = pcall(function()
        consumer:_render_tree(service:get_state())
      end)
      assert.is_true(ok)
    end)

    it("_render_details handles nil buffer gracefully", function()
      local service = Service.new(function() end)
      local consumer = WindowConsumer.new(service)

      -- Don't open, so buffers are nil
      local ok = pcall(function()
        consumer:_render_details(service:get_state())
      end)
      assert.is_true(ok)
    end)
  end)

  describe("selection stability", function()
    it("preserves selection when results update with same structure", function()
      local service = Service.new(function() end)
      -- Initial results: 2 files, each with 1 test
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-run",
          results = {
            files = {
              {
                id = "file-1",
                path = "test1.ts",
                status = "passed",
                tests = {
                  { id = "test-1", name = "test one", status = "passed", location = { line = 1, column = 1 } },
                },
                suites = {},
              },
              {
                id = "file-2",
                path = "test2.ts",
                status = "passed",
                tests = {
                  { id = "test-2", name = "test two", status = "passed", location = { line = 1, column = 1 } },
                },
                suites = {},
              },
            },
            summary = { total = 2, passed = 2, failed = 0, skipped = 0 },
          },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      -- Navigate to test-2 (header -> file-1 -> test-1 -> file-2 -> test-2)
      for _ = 1, 4 do
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "x", false)
      end
      assert.same("test-2", service:get_state().selected_id)

      -- Emit new results with same structure but different statuses
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-run",
          results = {
            files = {
              {
                id = "file-1",
                path = "test1.ts",
                status = "failed",
                tests = {
                  { id = "test-1", name = "test one", status = "failed", location = { line = 1, column = 1 } },
                },
                suites = {},
              },
              {
                id = "file-2",
                path = "test2.ts",
                status = "passed",
                tests = {
                  { id = "test-2", name = "test two", status = "passed", location = { line = 1, column = 1 } },
                },
                suites = {},
              },
            },
            summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
          },
        },
      })

      -- Selection should be preserved
      assert.same("test-2", service:get_state().selected_id)

      consumer:close()
    end)

    it("preserves selection on failing test when toggling filter", function()
      local service = Service.new(function() end)
      -- Mix of pass/fail tests
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-run",
          results = {
            files = {
              {
                id = "file-1",
                path = "test.ts",
                status = "failed",
                tests = {
                  { id = "test-pass", name = "passing test", status = "passed", location = { line = 1, column = 1 } },
                  { id = "test-fail", name = "failing test", status = "failed", location = { line = 10, column = 1 } },
                },
                suites = {},
              },
            },
            summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
          },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      -- Navigate to failing test (header -> file-1 -> test-pass -> test-fail)
      for _ = 1, 3 do
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "x", false)
      end
      assert.same("test-fail", service:get_state().selected_id)

      -- Toggle failures filter on
      vim.api.nvim_feedkeys("ff", "x", false)
      assert.is_true(service:get_state().filter_active)
      -- Failing test should still be selected (it's visible in filter)
      assert.same("test-fail", service:get_state().selected_id)

      -- Toggle failures filter off
      vim.api.nvim_feedkeys("ff", "x", false)
      assert.is_false(service:get_state().filter_active)
      -- Selection should still be preserved
      assert.same("test-fail", service:get_state().selected_id)

      consumer:close()
    end)

    it("resets selection to first visible when current is filtered out", function()
      local service = Service.new(function() end)
      -- Mix of pass/fail tests
      service:handle_event({
        type = "NopeTestRunResults",
        payload = {
          key = "test-run",
          results = {
            files = {
              {
                id = "file-1",
                path = "test.ts",
                status = "failed",
                tests = {
                  { id = "test-pass", name = "passing test", status = "passed", location = { line = 1, column = 1 } },
                  { id = "test-fail", name = "failing test", status = "failed", location = { line = 10, column = 1 } },
                },
                suites = {},
              },
            },
            summary = { total = 2, passed = 1, failed = 1, skipped = 0 },
          },
        },
      })

      local consumer = WindowConsumer.new(service)
      consumer:open()
      vim.api.nvim_set_current_win(consumer.tree_window)

      -- Navigate to passing test (header -> file-1 -> test-pass)
      for _ = 1, 2 do
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "x", false)
      end
      assert.same("test-pass", service:get_state().selected_id)

      -- Toggle failures filter on - passing test should be filtered out
      vim.api.nvim_feedkeys("ff", "x", false)
      assert.is_true(service:get_state().filter_active)

      -- Selection should reset to first visible node (header is first in filtered view)
      local state = service:get_state()
      assert.is_not.same("test-pass", state.selected_id)
      -- Should be a valid node in filtered view
      local found = false
      for _, node in ipairs(state.nodes) do
        if node.id == state.selected_id then
          found = true
          break
        end
      end
      assert.is_true(found, "selected_id should be in filtered nodes")

      consumer:close()
    end)
  end)
end)
