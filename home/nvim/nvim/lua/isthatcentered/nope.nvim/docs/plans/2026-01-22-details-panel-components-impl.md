# Details Panel Components Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor TestDetailsFormatter to component functions in DetailsPanel.lua that return C.Widget directly.

**Architecture:** Delete TestDetailsFormatter.lua, add components (TestHeader, Logs, Failure, FileDetails, SuiteDetails) to DetailsPanel.lua, update dispatch logic, remove dead summary/duration fields from DetailsService.

**Tech Stack:** Lua, nope.ui2 widget system (C.Text, C.Highlight, C.Stack), Plenary test runner

**Design doc:** `docs/plans/2026-01-22-details-panel-components-design.md`

---

### Task 1: TestHeader Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua`

**Step 1: Write the failing tests**

Add to `DetailsPanel_spec.lua`:

```lua
local function reset_editor()
  local window_ids = vim.api.nvim_list_wins()
  local current_window_id = vim.api.nvim_get_current_win()
  for _, window_id in pairs(window_ids) do
    if window_id ~= current_window_id then
      vim.api.nvim_win_close(window_id, true)
    end
  end
  local buffer_ids = vim.api.nvim_list_bufs()
  for _, buffer_id in pairs(buffer_ids) do
    vim.api.nvim_buf_delete(buffer_id, { force = true })
  end
end

describe("TestHeader", function()
  before_each(reset_editor)

  it("shows icon and full name for passed test", function()
    local test = { full_name = "suite > test", status = "passed" }
    local widget = BC.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ suite > test" }, lines)
  end)

  it("shows icon and full name for failed test", function()
    local test = { full_name = "suite > test", status = "failed" }
    local widget = BC.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✗ suite > test" }, lines)
  end)

  it("shows duration when present", function()
    local test = { full_name = "test", status = "passed", duration_ms = 123.45 }
    local widget = BC.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ test", "Duration: 123.45ms" }, lines)
  end)

  it("shows location when present", function()
    local test = { full_name = "test", status = "passed", location = { line = 10, column = 5 } }
    local widget = BC.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ test", "Location: line 10, col 5" }, lines)
  end)

  it("shows both duration and location when present", function()
    local test = { full_name = "test", status = "passed", duration_ms = 50, location = { line = 5, column = 1 } }
    local widget = BC.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ test", "Duration: 50.00ms", "Location: line 5, col 1" }, lines)
  end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: FAIL with "attempt to call field 'TestHeader' (a nil value)"

**Step 3: Write minimal implementation**

Add to `DetailsPanel.lua` after `local M = {}`:

```lua
local ICONS = {
  passed = "✓",
  failed = "✗",
  pending = "◌",
  skipped = "○",
}

local HL_GROUPS = {
  passed = "DiagnosticOk",
  failed = "DiagnosticError",
  pending = "DiagnosticHint",
  skipped = "Comment",
}

---@param test TestNode
---@return C.Widget
function M.TestHeader(test)
  local lines = {}
  local icon = ICONS[test.status] or "?"
  table.insert(lines, C.Highlight(HL_GROUPS[test.status], C.Text(string.format("%s %s", icon, test.full_name))))

  if test.duration_ms then
    table.insert(lines, C.Text(string.format("Duration: %.2fms", test.duration_ms)))
  end

  if test.location then
    table.insert(lines, C.Text(string.format("Location: line %d, col %d", test.location.line, test.location.column)))
  end

  return C.Stack(lines)
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua
git commit -m "feat(DetailsPanel): add TestHeader component"
```

---

### Task 2: Logs Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua`

**Step 1: Write the failing tests**

Add to `DetailsPanel_spec.lua`:

```lua
describe("Logs", function()
  before_each(reset_editor)

  it("shows logs header and content", function()
    local widget = BC.Logs({ "log line 1", "log line 2" })

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Logs:", "  log line 1", "  log line 2" }, lines)
  end)

  it("shows (none) when no logs", function()
    local widget = BC.Logs(nil)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Logs:", "  (none)" }, lines)
  end)

  it("shows (none) when empty logs array", function()
    local widget = BC.Logs({})

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Logs:", "  (none)" }, lines)
  end)

  it("splits multiline logs", function()
    local widget = BC.Logs({ "line1\nline2" })

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Logs:", "  line1", "  line2" }, lines)
  end)

  it("strips ANSI codes from logs", function()
    local widget = BC.Logs({ "\027[31mred text\027[0m" })

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Logs:", "  red text" }, lines)
  end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: FAIL with "attempt to call field 'Logs' (a nil value)"

**Step 3: Write minimal implementation**

Add to `DetailsPanel.lua`:

```lua
---Strip ANSI escape codes from text
---@param text string|nil
---@return string|nil
local function strip_ansi(text)
  if not text then return text end
  return text:gsub('\027%[[0-9;]*m', ''):gsub('%[%d+;?%d*m', '')
end

---@param logs string[]|nil
---@return C.Widget
function M.Logs(logs)
  local widgets = {}
  table.insert(widgets, C.Highlight("Title", C.Text("Logs:")))

  if logs and #logs > 0 then
    for _, log in ipairs(logs) do
      for log_line in strip_ansi(log):gmatch("[^\n]+") do
        table.insert(widgets, C.Text("  " .. log_line))
      end
    end
  else
    table.insert(widgets, C.Highlight("Comment", C.Text("  (none)")))
  end

  return C.Stack(widgets)
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua
git commit -m "feat(DetailsPanel): add Logs component"
```

---

### Task 3: Failure Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua`

**Step 1: Write the failing tests**

Add to `DetailsPanel_spec.lua`:

```lua
describe("Failure", function()
  before_each(reset_editor)

  it("shows error message", function()
    local failure = { message = "Expected true but got false" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Error:", "  Expected true but got false", "" }, lines)
  end)

  it("shows multiline error message", function()
    local failure = { message = "line1\nline2" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Error:", "  line1", "  line2", "" }, lines)
  end)

  it("shows diff section", function()
    local failure = { diff = "+added\n-removed\n unchanged" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Diff:", "+added", "-removed", " unchanged", "" }, lines)
  end)

  it("shows stack trace", function()
    local failure = { stack = "at file.lua:10\nat other.lua:20" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Stack trace:", "  at file.lua:10", "  at other.lua:20" }, lines)
  end)

  it("shows all sections when present", function()
    local failure = { message = "error", diff = "+a\n-b", stack = "at x:1" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Error:", "  error", "", "Diff:", "+a", "-b", "", "Stack trace:", "  at x:1" }, lines)
  end)

  it("strips ANSI codes from all sections", function()
    local failure = { message = "\027[31mred\027[0m" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "Error:", "  red", "" }, lines)
  end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: FAIL with "attempt to call field 'Failure' (a nil value)"

**Step 3: Write minimal implementation**

Add to `DetailsPanel.lua`:

```lua
---@param failure TestFailure
---@return C.Widget
function M.Failure(failure)
  local widgets = {}

  if failure.message then
    table.insert(widgets, C.Highlight(HL_GROUPS.failed, C.Text("Error:")))
    for msg_line in strip_ansi(failure.message):gmatch("[^\n]+") do
      table.insert(widgets, C.Text("  " .. msg_line))
    end
    table.insert(widgets, C.Text(""))
  end

  if failure.diff then
    table.insert(widgets, C.Text("Diff:"))
    for diff_line in strip_ansi(failure.diff):gmatch("[^\n]+") do
      local widget = C.Text(diff_line)
      if diff_line:match("^%+") then
        widget = C.Highlight("DiagnosticError", widget)
      elseif diff_line:match("^%-") then
        widget = C.Highlight("DiagnosticOk", widget)
      end
      table.insert(widgets, widget)
    end
    table.insert(widgets, C.Text(""))
  end

  if failure.stack then
    table.insert(widgets, C.Text("Stack trace:"))
    for stack_line in strip_ansi(failure.stack):gmatch("[^\n]+") do
      table.insert(widgets, C.Text("  " .. stack_line))
    end
  end

  return C.Stack(widgets)
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua
git commit -m "feat(DetailsPanel): add Failure component"
```

---

### Task 4: FileDetails Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua`

**Step 1: Write the failing tests**

Add to `DetailsPanel_spec.lua`:

```lua
describe("FileDetails", function()
  before_each(reset_editor)

  it("shows file icon, name and counts", function()
    local file = {
      path = "/path/to/file_spec.lua",
      status = "passed",
      tests = {
        { status = "passed" },
        { status = "passed" },
      },
      suites = {},
    }
    local widget = BC.FileDetails(file)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ 󰈙 file_spec.lua (2 passed, 0 failed)" }, lines)
  end)

  it("shows failed status with counts", function()
    local file = {
      path = "test.lua",
      status = "failed",
      tests = {
        { status = "passed" },
        { status = "failed" },
        { status = "failed" },
      },
      suites = {},
    }
    local widget = BC.FileDetails(file)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✗ 󰈙 test.lua (1 passed, 2 failed)" }, lines)
  end)

  it("counts tests in nested suites", function()
    local file = {
      path = "test.lua",
      status = "passed",
      tests = { { status = "passed" } },
      suites = {
        {
          tests = { { status = "passed" }, { status = "failed" } },
          suites = {},
        },
      },
    }
    local widget = BC.FileDetails(file)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ 󰈙 test.lua (2 passed, 1 failed)" }, lines)
  end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: FAIL with "attempt to call field 'FileDetails' (a nil value)"

**Step 3: Write minimal implementation**

Add to `DetailsPanel.lua`:

```lua
---Count passed/failed tests recursively
---@param tests TestNode[]
---@param suites SuiteNode[]
---@return number passed, number failed
local function count_tests(tests, suites)
  local passed, failed = 0, 0
  for _, test in ipairs(tests or {}) do
    if test.status == "passed" then
      passed = passed + 1
    elseif test.status == "failed" then
      failed = failed + 1
    end
  end
  for _, suite in ipairs(suites or {}) do
    local sp, sf = count_tests(suite.tests, suite.suites)
    passed = passed + sp
    failed = failed + sf
  end
  return passed, failed
end

---@param file FileNode
---@return C.Widget
function M.FileDetails(file)
  local filename = file.path:match("([^/]+)$") or file.path
  local icon = ICONS[file.status] or "?"
  local passed, failed = count_tests(file.tests, file.suites)
  local text = string.format("%s 󰈙 %s (%d passed, %d failed)", icon, filename, passed, failed)
  return C.Highlight(HL_GROUPS[file.status], C.Text(text))
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua
git commit -m "feat(DetailsPanel): add FileDetails component"
```

---

### Task 5: SuiteDetails Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua`

**Step 1: Write the failing tests**

Add to `DetailsPanel_spec.lua`:

```lua
describe("SuiteDetails", function()
  before_each(reset_editor)

  it("shows suite icon, name and counts", function()
    local suite = {
      name = "my suite",
      status = "passed",
      tests = {
        { status = "passed" },
        { status = "passed" },
      },
      suites = {},
    }
    local widget = BC.SuiteDetails(suite)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ 󰙅 my suite (2 passed, 0 failed)" }, lines)
  end)

  it("shows failed status with counts", function()
    local suite = {
      name = "failing suite",
      status = "failed",
      tests = {
        { status = "passed" },
        { status = "failed" },
      },
      suites = {},
    }
    local widget = BC.SuiteDetails(suite)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✗ 󰙅 failing suite (1 passed, 1 failed)" }, lines)
  end)

  it("counts tests in nested suites", function()
    local suite = {
      name = "parent",
      status = "passed",
      tests = {},
      suites = {
        {
          tests = { { status = "passed" }, { status = "failed" } },
          suites = {},
        },
      },
    }
    local widget = BC.SuiteDetails(suite)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ 󰙅 parent (1 passed, 1 failed)" }, lines)
  end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: FAIL with "attempt to call field 'SuiteDetails' (a nil value)"

**Step 3: Write minimal implementation**

Add to `DetailsPanel.lua`:

```lua
---@param suite SuiteNode
---@return C.Widget
function M.SuiteDetails(suite)
  local icon = ICONS[suite.status] or "?"
  local passed, failed = count_tests(suite.tests, suite.suites)
  local text = string.format("%s 󰙅 %s (%d passed, %d failed)", icon, suite.name, passed, failed)
  return C.Highlight(HL_GROUPS[suite.status], C.Text(text))
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua
git commit -m "feat(DetailsPanel): add SuiteDetails component"
```

---

### Task 6: Update DetailsPanel Dispatch

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua`

**Step 1: Write the failing tests**

Replace existing DetailsPanel tests in `DetailsPanel_spec.lua`:

```lua
describe("DetailsPanel", function()
  before_each(reset_editor)

  it("renders test details with header, logs and failure", function()
    local node = {
      type = "test",
      node = {
        full_name = "suite > test",
        status = "failed",
        logs = { "log1" },
        failure = { message = "error msg" },
      },
    }
    local widget = BC.DetailsPanel(node)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({
      "✗ suite > test",
      "",
      "Logs:",
      "  log1",
      "Error:",
      "  error msg",
      "",
    }, lines)
  end)

  it("renders file details", function()
    local node = {
      type = "file",
      node = {
        path = "test.lua",
        status = "passed",
        tests = { { status = "passed" } },
        suites = {},
      },
    }
    local widget = BC.DetailsPanel(node)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ 󰈙 test.lua (1 passed, 0 failed)" }, lines)
  end)

  it("renders suite details", function()
    local node = {
      type = "suite",
      node = {
        name = "my suite",
        status = "passed",
        tests = { { status = "passed" } },
        suites = {},
      },
    }
    local widget = BC.DetailsPanel(node)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "✓ 󰙅 my suite (1 passed, 0 failed)" }, lines)
  end)

  it("renders empty when no node", function()
    local widget = BC.DetailsPanel(nil)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "" }, lines)
  end)

  it("renders empty for header node type", function()
    local node = { type = "header", node = {} }
    local widget = BC.DetailsPanel(node)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.same({ "" }, lines)
  end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: FAIL (signature mismatch - old code expects 3 params)

**Step 3: Write minimal implementation**

Replace the existing `M.DetailsPanel` function in `DetailsPanel.lua`:

```lua
---@param node TreeNode|nil
---@return C.Widget
function M.DetailsPanel(node)
  local widgets = {}

  if node then
    if node.type == "test" and node.node then
      table.insert(widgets, M.TestHeader(node.node))
      table.insert(widgets, C.Text(""))
      table.insert(widgets, M.Logs(node.node.logs))
      if node.node.failure then
        table.insert(widgets, M.Failure(node.node.failure))
      end
    elseif node.type == "file" and node.node then
      table.insert(widgets, M.FileDetails(node.node))
    elseif node.type == "suite" and node.node then
      table.insert(widgets, M.SuiteDetails(node.node))
    end
  end

  if #widgets == 0 then
    table.insert(widgets, C.Text(""))
  end

  return C.Stack(widgets)
end
```

Also remove the `require` for TestDetailsFormatter at the top of the file.

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua
git commit -m "refactor(DetailsPanel): use new components in dispatch"
```

---

### Task 7: Update WindowConsumer Call Site

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/init.lua`

**Step 1: Update the call**

In `lua/nope/consumers/WindowConsumer/init.lua`, line 78, change:

```lua
local content = DetailsPanel.DetailsPanel(state.selected_node, state.summary, state.duration_ms)
```

to:

```lua
local content = DetailsPanel.DetailsPanel(state.selected_node)
```

**Step 2: Run all tests**

Run: `make test`
Expected: PASS

**Step 3: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/init.lua
git commit -m "refactor(WindowConsumer): update DetailsPanel call"
```

---

### Task 8: Clean Up DetailsService

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Details/state/DetailsService.lua`

**Step 1: Remove dead fields**

In `DetailsService.lua`:

1. Update `DetailsServiceState` class annotation (lines 1-5):
```lua
---@class DetailsServiceState
---@field selected_node TreeNode|nil
---@field scroll_offset number
```

2. Update initial state in `DetailsService.new()` (lines 14-22):
```lua
function DetailsService.new()
  local self = setmetatable({
    state = {
      selected_node = nil,
      scroll_offset = 0,
    },
    subscribers = {},
  }, DetailsService)
  return self
end
```

3. Update `update_from_navigation` (lines 36-58):
```lua
function DetailsService:update_from_navigation(nav_state)
  if self.state.selected_node ~= nav_state.selected_node then
    self.state.selected_node = nav_state.selected_node
    self.state.scroll_offset = 0
    self:_notify()
  end
end
```

**Step 2: Run all tests**

Run: `make test`
Expected: PASS

**Step 3: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Details/state/DetailsService.lua
git commit -m "refactor(DetailsService): remove dead summary/duration fields"
```

---

### Task 9: Delete TestDetailsFormatter

**Files:**
- Delete: `lua/nope/consumers/WindowConsumer/Details/ui/TestDetailsFormatter.lua`
- Delete: `lua/nope/consumers/WindowConsumer/Details/ui/TestDetailsFormatter_spec.lua`

**Step 1: Delete the files**

```bash
rm lua/nope/consumers/WindowConsumer/Details/ui/TestDetailsFormatter.lua
rm lua/nope/consumers/WindowConsumer/Details/ui/TestDetailsFormatter_spec.lua
```

**Step 2: Run all tests**

Run: `make test`
Expected: PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "refactor(DetailsPanel): remove TestDetailsFormatter"
```

---

### Task 10: Final Cleanup and Verification

**Step 1: Run full test suite**

Run: `make test`
Expected: All tests pass

**Step 2: Check for any remaining references**

Run: `grep -r "TestDetailsFormatter" lua/`
Expected: No output (no remaining references)

**Step 3: Verify no unused code**

Check that ICONS and HL_GROUPS are used, strip_ansi is used, count_tests is used.
