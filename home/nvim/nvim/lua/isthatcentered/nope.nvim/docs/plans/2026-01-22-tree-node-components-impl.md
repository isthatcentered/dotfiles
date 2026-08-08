# Tree Node Components Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor TreeNodeFormatter from data-returning formatters to C.Widget components in NavigationPanel.lua

**Architecture:** Delete TreeNodeFormatter, add Header/FileName/SuiteName/TestName components to NavigationPanel, update loop to dispatch directly with C.Padding for indent. Each component handles its own selection highlight.

**Tech Stack:** Lua, nope.ui2 widget system, Plenary test runner

---

### Task 1: Add Header Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua`

**Step 1: Write the failing tests**

Add to NavigationPanel_spec.lua after the existing requires:

```lua
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
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: FAIL - Header function doesn't exist

**Step 3: Write the implementation**

Add to NavigationPanel.lua after the INDENT constant (around line 6), add these constants:

```lua
local ICONS = {
  passed = "✓",
  failed = "✗",
  pending = "◌",
  skipped = "○",
  file = "󰈙",
  suite = "󰙅",
}

local HL_GROUPS = {
  passed = "DiagnosticOk",
  failed = "DiagnosticError",
  pending = "DiagnosticHint",
  skipped = "Comment",
}
```

Add the Header function after the constants:

```lua
---@param state {status: string, summary: {total: number, passed: number, failed: number, skipped: number}, duration_ms: number|nil}
---@param is_selected boolean
---@param show_only_failures boolean|nil
---@return C.Widget
function M.Header(state, is_selected, show_only_failures)
  local s = state.summary
  local status = state.status
  local text, hl_group

  local filter_indicator = show_only_failures and " [󰈲 failures only]" or ""

  if status == "pending" then
    local completed = s.passed + s.failed + s.skipped
    text = string.format("◌ Running... %d/%d%s", completed, s.total, filter_indicator)
    hl_group = HL_GROUPS.pending
  elseif status == "done" then
    local duration = state.duration_ms and string.format(" (%.2fs)", state.duration_ms / 1000) or ""
    if s.failed > 0 then
      text = string.format("%s %d total, %d passed, %d failed%s%s", ICONS.failed, s.total, s.passed, s.failed, duration, filter_indicator)
      hl_group = HL_GROUPS.failed
    else
      text = string.format("%s %d total, %d passed%s%s", ICONS.passed, s.total, s.passed, duration, filter_indicator)
      hl_group = HL_GROUPS.passed
    end
  elseif status == "cancelled" then
    text = "○ Cancelled" .. filter_indicator
    hl_group = HL_GROUPS.skipped
  else
    text = "○ Idle" .. filter_indicator
    hl_group = HL_GROUPS.skipped
  end

  local widget = C.Highlight(hl_group, C.Text(text))
  if is_selected then
    widget = C.Highlight("Visual", C.Flex(1, widget))
  end
  return widget
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: Header tests PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua
git commit -m "feat(NavigationPanel): add Header component"
```

---

### Task 2: Add FileName Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua`

**Step 1: Write the failing tests**

Add to NavigationPanel_spec.lua:

```lua
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
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: FAIL - FileName function doesn't exist

**Step 3: Write the implementation**

Add to NavigationPanel.lua after the Header function:

```lua
---@param file FileNode
---@param is_selected boolean
---@return C.Widget
function M.FileName(file, is_selected)
  local filename = file.path:match("([^/]+)$") or file.path
  local icon = ICONS[file.status] or "?"
  local text = string.format("%s %s %s", icon, ICONS.file, filename)

  local widget = C.Highlight(HL_GROUPS[file.status], C.Text(text))
  if is_selected then
    widget = C.Highlight("Visual", C.Flex(1, widget))
  end
  return widget
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: FileName tests PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua
git commit -m "feat(NavigationPanel): add FileName component"
```

---

### Task 3: Add SuiteName Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua`

**Step 1: Write the failing tests**

Add to NavigationPanel_spec.lua:

```lua
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
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: FAIL - SuiteName function doesn't exist

**Step 3: Write the implementation**

Add to NavigationPanel.lua after the FileName function:

```lua
---@param suite SuiteNode
---@param is_selected boolean
---@return C.Widget
function M.SuiteName(suite, is_selected)
  local icon = ICONS[suite.status] or "?"
  local text = string.format("%s %s %s", icon, ICONS.suite, suite.name)

  local widget = C.Highlight(HL_GROUPS[suite.status], C.Text(text))
  if is_selected then
    widget = C.Highlight("Visual", C.Flex(1, widget))
  end
  return widget
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: SuiteName tests PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua
git commit -m "feat(NavigationPanel): add SuiteName component"
```

---

### Task 4: Add TestName Component

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua`

**Step 1: Write the failing tests**

Add to NavigationPanel_spec.lua:

```lua
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
```

**Step 2: Run tests to verify they fail**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: FAIL - TestName function doesn't exist

**Step 3: Write the implementation**

Add to NavigationPanel.lua after the SuiteName function:

```lua
---@param test TestNode
---@param is_selected boolean
---@return C.Widget
function M.TestName(test, is_selected)
  local icon = ICONS[test.status] or "?"
  local text = string.format("%s %s", icon, test.name)

  local widget = C.Highlight(HL_GROUPS[test.status], C.Text(text))
  if is_selected then
    widget = C.Highlight("Visual", C.Flex(1, widget))
  end
  return widget
end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: TestName tests PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua
git commit -m "feat(NavigationPanel): add TestName component"
```

---

### Task 5: Update NavigationPanel Loop to Use New Components

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua`

**Step 1: Update existing NavigationPanel tests**

In NavigationPanel_spec.lua, update the test "highlights selected node with is_selected=true" to check for Visual instead of CursorLine:

```lua
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
```

**Step 2: Run tests to verify they still pass with current code**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: Some tests fail (CursorLine vs Visual)

**Step 3: Update the NavigationPanel function**

Replace the loop in NavigationPanel function (lines 191-194) with:

```lua
    for _, node in ipairs(props.nodes) do
      local is_selected = node.id == props.selected_id
      local depth = node._depth or 0

      local component
      if node.type == "header" then
        component = M.Header(node.node, is_selected, props.filter_active)
      elseif node.type == "file" then
        component = M.FileName(node.node, is_selected)
      elseif node.type == "suite" then
        component = M.SuiteName(node.node, is_selected)
      elseif node.type == "test" then
        component = M.TestName(node.node, is_selected)
      end

      if depth > 0 then
        component = C.Padding({ left = depth * 2 }, component)
      end

      table.insert(children, component)
    end
```

**Step 4: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: PASS

**Step 5: Commit**

```bash
git add lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua
git commit -m "refactor(NavigationPanel): use new components in loop"
```

---

### Task 6: Remove TreeNodeRow and TreeNodeFormatter

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua`
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua`
- Delete: `lua/nope/consumers/WindowConsumer/Navigation/ui/TreeNodeFormatter.lua`
- Delete: `lua/nope/consumers/WindowConsumer/Navigation/ui/TreeNodeFormatter_spec.lua`

**Step 1: Remove TreeNodeRow function and tests**

In NavigationPanel.lua:
- Remove the `require` for TreeNodeFormatter (line 2)
- Remove the INDENT constant (line 6)
- Remove the TreeNodeRow function (lines 8-31)

In NavigationPanel_spec.lua:
- Remove the entire `describe("TreeNodeRow", ...)` block (lines 13-82)

**Step 2: Run tests to verify they pass**

Run: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua"`

Expected: PASS

**Step 3: Delete TreeNodeFormatter files**

```bash
rm lua/nope/consumers/WindowConsumer/Navigation/ui/TreeNodeFormatter.lua
rm lua/nope/consumers/WindowConsumer/Navigation/ui/TreeNodeFormatter_spec.lua
```

**Step 4: Run all tests to verify nothing broke**

Run: `make test`

Expected: All tests PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(NavigationPanel): remove TreeNodeFormatter and TreeNodeRow

BREAKING: TreeNodeFormatter module deleted, replaced by component functions"
```

---

### Task 7: Final Cleanup

**Files:**
- Modify: `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua`

**Step 1: Update unconstrained helper if needed**

The unconstrained() helper can stay as-is since it's still used by other tests.

**Step 2: Run full test suite**

Run: `make test`

Expected: All tests PASS

**Step 3: Commit if any changes**

```bash
git add -A
git commit -m "chore: cleanup after TreeNodeFormatter refactor"
```
