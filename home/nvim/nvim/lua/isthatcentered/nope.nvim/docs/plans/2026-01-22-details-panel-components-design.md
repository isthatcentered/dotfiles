# Details Panel Components Design

## Overview

Refactor `TestDetailsFormatter` from data-returning formatter to component functions that return `C.Widget` directly. Components move into `DetailsPanel.lua`. Also add support for file/suite details.

## Architecture

**What changes:**
- `TestDetailsFormatter.lua` deleted
- Five new components in `DetailsPanel.lua`: `TestHeader`, `Logs`, `Failure`, `FileDetails`, `SuiteDetails`
- Each component: takes node data, returns `C.Widget`
- `DetailsPanel` signature simplified: `(node)` instead of `(node, summary, duration_ms)`
- `DetailsService` cleaned up: remove dead `summary` and `duration_ms` fields

**What stays:**
- Basic DetailsPanel structure (returns `C.Stack`)

## Component Signatures

```lua
function M.TestHeader(test)
  -- test: TestNode {full_name, status, duration_ms?, location?}
  -- Returns: icon + full_name, duration line, location line
end

function M.Logs(logs)
  -- logs: string[]|nil
  -- Returns: "Logs:" header + log lines or "(none)"
end

function M.Failure(failure)
  -- failure: {message?, diff?, stack?}
  -- Returns: "Error:" + message, "Diff:" + diff lines, "Stack trace:" + stack
end

function M.FileDetails(file)
  -- file: FileNode {path, status, children}
  -- Returns: "✓ 󰈙 filename.lua (5 passed, 2 failed)"
end

function M.SuiteDetails(suite)
  -- suite: SuiteNode {name, status, children}
  -- Returns: "✓ 󰙅 suite name (3 passed, 1 failed)"
end
```

## DetailsPanel Dispatch

```lua
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

## Testing Approach

Tests render components to buffer, assert on exact output:

```lua
local C = require("nope.ui2")
local DetailsPanel = require("nope.consumers.WindowConsumer.Details.ui.DetailsPanel")

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

  it("shows icon and full name", function()
    local test = { full_name = "suite > test", status = "passed" }
    local widget = DetailsPanel.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    assert.same({ "✓ suite > test" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  end)
end)
```

**Test coverage:**
- `TestHeader`: status icons, duration, location
- `Logs`: with logs, without logs ("(none)")
- `Failure`: message, diff highlighting (+/-), stack trace, ANSI stripping
- `FileDetails`: icon + name + counts
- `SuiteDetails`: icon + name + counts
- `DetailsPanel`: dispatch for each node type

## Files Changed

**Deleted:**
- `lua/nope/consumers/WindowConsumer/Details/ui/TestDetailsFormatter.lua`
- `lua/nope/consumers/WindowConsumer/Details/ui/TestDetailsFormatter_spec.lua`

**Modified:**
- `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel.lua` - add components, simplify signature
- `lua/nope/consumers/WindowConsumer/Details/ui/DetailsPanel_spec.lua` - add component tests
- `lua/nope/consumers/WindowConsumer/Details/state/DetailsService.lua` - remove dead summary/duration fields
- `lua/nope/consumers/WindowConsumer/init.lua` - update DetailsPanel call
