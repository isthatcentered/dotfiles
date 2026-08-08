local DiagnosticsConsumer = require("nope.consumers.DiagnosticsConsumer")
local EventBus = require("nope.EventBus")

-- Get absolute path to fixtures directory
local script_path = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script_path, ":h:h:h")
local fixture_file = plugin_root .. "/lua/nope/fixtures/dummy.test.ts"

---Helper to create a valid TestRunState
---@param overrides? table
---@return table
local function make_state(overrides)
  local base = {
    status = "idle",
    summary = { total = 0, passed = 0, failed = 0, skipped = 0 },
    files = {},
  }
  if overrides then
    for k, v in pairs(overrides) do
      base[k] = v
    end
  end
  return base
end

---Helper to create a test file node
---@param path string
---@param opts? { tests?: table[], suites?: table[], status?: string }
---@return table
local function make_file(path, opts)
  opts = opts or {}
  return {
    id = "file:" .. path,
    path = path,
    status = opts.status or "pending",
    suites = opts.suites or {},
    tests = opts.tests or {},
  }
end

---Helper to create a suite node
---@param name string
---@param opts? { tests?: table[], suites?: table[], status?: string }
---@return table
local function make_suite(name, opts)
  opts = opts or {}
  return {
    id = "suite:" .. name,
    name = name,
    status = opts.status or "pending",
    tests = opts.tests or {},
    suites = opts.suites or {},
  }
end

---Helper to create a test node
---@param name string
---@param opts? { status?: string, location?: table, failure?: table }
---@return table
local function make_test(name, opts)
  opts = opts or {}
  return {
    id = "test:" .. name,
    name = name,
    full_name = name,
    status = opts.status or "pending",
    location = opts.location,
    failure = opts.failure,
  }
end

---Get diagnostics for a file path
---@param ns_id number
---@param file_path string
---@return table[]
local function get_diagnostics_for_file(ns_id, file_path)
  local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(file_path))
  return vim.diagnostic.get(bufnr, { namespace = ns_id })
end

describe("DiagnosticsConsumer", function()
  local consumer
  local event_bus

  before_each(function()
    event_bus = EventBus.Sync.new()
    consumer = DiagnosticsConsumer.new(function(cb) return event_bus:listen(cb) end)
  end)

  after_each(function()
    vim.diagnostic.reset(consumer.ns_id)
    event_bus:destroy()
  end)

  ---Fire NopeTestRunStarted event
  ---@param key string
  ---@param configuration? table
  local function fire_started(key, configuration)
    event_bus:emit({
      type = "NopeTestRunStarted",
      payload = { key = key, configuration = configuration },
    })
  end

  ---Fire NopeTestRunResults event
  ---@param state table
  ---@param key? string
  local function fire_results(state, key)
    event_bus:emit({
      type = "NopeTestRunResults",
      payload = { key = key or "test", results = state },
    })
  end

  describe("new()", function()
    it("creates a new consumer with namespace", function()
      assert.is_not_nil(consumer)
      assert.is_number(consumer.ns_id)
    end)
  end)

  describe("receives NopeTestRunResults event", function()

    it("creates no diagnostics for passing tests", function()
      local state = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("passes", { status = "passed", location = { line = 4, column = 3 } }),
            },
          }),
        },
      })

      fire_results(state)

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(0, #diags)
    end)

    it("creates diagnostic for failed test at correct position", function()
      local state = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("fails", {
                status = "failed",
                location = { line = 8, column = 3 },
                failure = { message = "Expected true to be false" },
              }),
            },
          }),
        },
      })

      fire_results(state)

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(1, #diags)

      local diag = diags[1]
      assert.same(7, diag.lnum) -- 0-indexed (line 8 -> 7)
      assert.same(2, diag.col) -- 0-indexed (column 3 -> 2)
      assert.same("Expected true to be false", diag.message)
      assert.same(vim.diagnostic.severity.ERROR, diag.severity)
      assert.same("nope", diag.source)
    end)

    it("creates diagnostics for multiple failed tests in same file", function()
      local state = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("fails1", {
                status = "failed",
                location = { line = 8, column = 3 },
                failure = { message = "Error 1" },
              }),
              make_test("fails2", {
                status = "failed",
                location = { line = 14, column = 3 },
                failure = { message = "Error 2" },
              }),
            },
          }),
        },
      })

      fire_results(state)

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(2, #diags)
    end)

    it("creates diagnostics for failed tests in nested suites", function()
      local state = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            suites = {
              make_suite("outer", {
                suites = {
                  make_suite("inner", {
                    tests = {
                      make_test("nested fail", {
                        status = "failed",
                        location = { line = 9, column = 5 },
                        failure = { message = "Nested error" },
                      }),
                    },
                  }),
                },
              }),
            },
          }),
        },
      })

      fire_results(state)

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(1, #diags)
      assert.same(8, diags[1].lnum) -- 0-indexed
    end)

    it("clears previous diagnostics on update", function()
      -- First update with one failing test
      local state1 = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("fails", {
                status = "failed",
                location = { line = 8, column = 3 },
                failure = { message = "Error" },
              }),
            },
          }),
        },
      })
      fire_results(state1)
      assert.same(1, #get_diagnostics_for_file(consumer.ns_id, fixture_file))

      -- Second update with passing test (no failures)
      local state2 = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("passes", { status = "passed", location = { line = 8, column = 3 } }),
            },
          }),
        },
      })
      fire_results(state2)

      -- Should have cleared previous diagnostics
      assert.same(0, #get_diagnostics_for_file(consumer.ns_id, fixture_file))
    end)

    it("skips failed tests without location", function()
      local state = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("no location", {
                status = "failed",
                failure = { message = "Error" },
              }),
            },
          }),
        },
      })

      fire_results(state)

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(0, #diags)
    end)

    it("uses first line of multi-line error message", function()
      local state = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("multi-line", {
                status = "failed",
                location = { line = 8, column = 3 },
                failure = { message = "First line\nSecond line\nThird line" },
              }),
            },
          }),
        },
      })

      fire_results(state)

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same("First line", diags[1].message)
    end)

    it("uses default message when failure has no message", function()
      local state = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("no message", {
                status = "failed",
                location = { line = 8, column = 3 },
              }),
            },
          }),
        },
      })

      fire_results(state)

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same("Test failed", diags[1].message)
    end)
  end)

  describe("parallel runs", function()
    local fixture_file2

    before_each(function()
      fixture_file2 = plugin_root .. "/lua/nope/fixtures/dummy.test.ts"
    end)

    it("tracks diagnostics from multiple runs with different files", function()
      -- Run 1 with file1
      fire_started("run1")
      local state1 = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("fails1", {
                status = "failed",
                location = { line = 8, column = 3 },
                failure = { message = "Error 1" },
              }),
            },
          }),
        },
      })
      fire_results(state1, "run1")

      -- Run 2 with same file but different key
      fire_started("run2")
      local state2 = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("fails2", {
                status = "failed",
                location = { line = 10, column = 3 },
                failure = { message = "Error 2" },
              }),
            },
          }),
        },
      })
      fire_results(state2, "run2")

      -- Last result wins for same file
      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(1, #diags)
      assert.same(9, diags[1].lnum) -- line 10 -> 9 (0-indexed)
    end)

    it("clears previous diagnostics when same run restarts", function()
      -- First run
      fire_started("run1")
      local state1 = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("fails", {
                status = "failed",
                location = { line = 8, column = 3 },
                failure = { message = "Error" },
              }),
            },
          }),
        },
      })
      fire_results(state1, "run1")

      local diags_before = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(1, #diags_before)

      -- Same run restarts (NopeTestRunStarted clears old diagnostics)
      fire_started("run1")

      local diags_after = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(0, #diags_after)
    end)

    it("does not clear diagnostics from other runs when one restarts", function()
      -- Run 1
      fire_started("run1")
      local state1 = make_state({
        status = "done",
        files = {
          make_file(fixture_file, {
            tests = {
              make_test("fails1", {
                status = "failed",
                location = { line = 8, column = 3 },
                failure = { message = "Error 1" },
              }),
            },
          }),
        },
      })
      fire_results(state1, "run1")

      -- Run 2 starts - should NOT clear run1's diagnostics
      fire_started("run2")

      local diags = get_diagnostics_for_file(consumer.ns_id, fixture_file)
      assert.same(1, #diags)
      assert.same("Error 1", diags[1].message)
    end)
  end)
end)
