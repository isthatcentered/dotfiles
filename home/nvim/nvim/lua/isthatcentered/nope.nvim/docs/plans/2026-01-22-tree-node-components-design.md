# Tree Node Components Design

## Overview

Refactor `TreeNodeFormatter` from data-returning formatters to component functions that return `C.Widget` directly. Components move into `NavigationPanel.lua`.

## Architecture

**What changes:**
- `TreeNodeFormatter.lua` deleted
- `TreeNodeRow` deleted
- Four new components in `NavigationPanel.lua`: `Header`, `FileName`, `SuiteName`, `TestName`
- Each component: takes node + `is_selected`, returns `C.Widget`
- `NavigationPanel` loop dispatches based on `node.type`, wraps with `C.Padding` for indent

**What stays:**
- `TestDetailsFormatter` unchanged (used by DetailsPanel directly)
- All other NavigationPanel components (`TabBar`, `Footer`, `Breadcrumb`, etc.)

## Component Signatures

```lua
function M.Header(state, is_selected, show_only_failures)
  -- state: {status, summary, duration_ms}
  -- Returns: icon + summary text, status-based highlight
end

function M.FileName(file, is_selected)
  -- file: FileNode {path, status}
  -- Returns: status_icon + file_icon + basename
end

function M.SuiteName(suite, is_selected)
  -- suite: SuiteNode {name, status}
  -- Returns: status_icon + suite_icon + name
end

function M.TestName(test, is_selected)
  -- test: TestNode {name, status}
  -- Returns: status_icon + name (no extra icon)
end
```

**Shared pattern inside each component:**
```lua
local widget = C.Highlight(HL_GROUPS[status], C.Text(text))
if is_selected then
  widget = C.Highlight("Visual", C.Flex(1, widget))
end
return widget
```

## NavigationPanel Loop

```lua
function M.NavigationPanel(props)
  -- ... existing setup ...

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

    -- Apply indentation
    if depth > 0 then
      component = C.Padding({ left = depth * 2 }, component)
    end

    table.insert(children, component)
  end

  -- ... rest unchanged ...
end
```

## Testing Approach

Tests render components to buffer, assert on exact output:

```lua
local C = require("nope.ui2")
local NavigationPanel = require("nope.consumers.WindowConsumer.Navigation.ui.NavigationPanel")

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

describe("Header", function()
  before_each(reset_editor)

  it("shows running state with progress", function()
    local state = { status = "pending", summary = { total = 10, passed = 3, failed = 0, skipped = 0 } }
    local widget = NavigationPanel.Header(state, false, false)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    assert.same({ "◌ Running... 3/10" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)
end)
```

**Test coverage:**
- Each component: text output for each status (passed/failed/pending/skipped)
- Selection highlight applied correctly (Visual)
- Icons present

## Files Changed

**Deleted:**
- `lua/nope/consumers/WindowConsumer/Navigation/ui/TreeNodeFormatter.lua`
- `lua/nope/consumers/WindowConsumer/Navigation/ui/TreeNodeFormatter_spec.lua`

**Modified:**
- `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel.lua` - add components, update loop
- `lua/nope/consumers/WindowConsumer/Navigation/ui/NavigationPanel_spec.lua` - add component tests

**Unchanged:**
- `TestDetailsFormatter.lua` (used by DetailsPanel directly)
- `DetailsPanel.lua`
