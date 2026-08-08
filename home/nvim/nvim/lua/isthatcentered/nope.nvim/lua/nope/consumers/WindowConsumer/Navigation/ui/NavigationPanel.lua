local C = require("nope.ui2")

local M = {}

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

-- Status icons for tabs
local TAB_STATUS_ICONS = {
  running = "◌",
  done_passed = "✓",
  done_failed = "✗",
  cancelled = "○",
}

---@param status string
---@param has_failures boolean
---@return string
local function get_tab_icon(status, has_failures)
  if status == "running" then
    return TAB_STATUS_ICONS.running
  elseif status == "cancelled" then
    return TAB_STATUS_ICONS.cancelled
  elseif has_failures then
    return TAB_STATUS_ICONS.done_failed
  else
    return TAB_STATUS_ICONS.done_passed
  end
end

---@param tabs TabInfo[]
---@param active_key string|nil
---@return C.Widget
function M.TabBar(tabs, active_key)
  if #tabs == 0 then
    return C.Text("")
  end

  local parts = {}
  for i, tab in ipairs(tabs) do
    local is_active = tab.key == active_key
    local icon = get_tab_icon(tab.status, tab.has_failures)

    local tab_text
    if is_active then
      tab_text = string.format("[%s %s]", icon, tab.label)
    else
      tab_text = string.format(" %s %s ", icon, tab.label)
    end

    table.insert(parts, C.Text(tab_text))

    -- Add separator between tabs
    if i < #tabs then
      table.insert(parts, C.Text("│"))
    end
  end

  return C.Array(parts)
end

---@class FooterProps
---@field filter_active boolean|nil
---@field scope_filter_id string|nil

---@param props FooterProps|nil
---@return C.Widget
function M.Footer(props)
  props = props or {}
  local parts = {}

  table.insert(parts, "g? help")

  if props.filter_active then
    table.insert(parts, "ff clear failures")
  end

  if props.scope_filter_id then
    table.insert(parts, "fc clear scope")
  end

  return C.Highlight("Comment", C.Text(table.concat(parts, " | ")))
end

---@param breadcrumb string[]|nil
---@return C.Widget
function M.Breadcrumb(breadcrumb)
  if not breadcrumb or #breadcrumb == 0 then
    return C.Text("")
  end

  local text = table.concat(breadcrumb, " > ")
  return C.Highlight("Comment", C.Text("󰈲 " .. text))
end

---@return C.Widget
function M.EmptyState()
  return C.Center(
    C.Stack({
      C.Highlight("Comment", C.Text("○ No test run active")),
      C.Highlight("Comment", C.Text("Run tests to see results")),
    })
  )
end

-- Help shortcuts
local SHORTCUTS = {
  { key = "<C-n>/<C-p>", desc = "Navigate up/down" },
  { key = "<CR>", desc = "Scope to selection" },
  { key = "gf", desc = "Go to file" },
  { key = "ff", desc = "Toggle failures only" },
  { key = "fc", desc = "Clear scope filter" },
  { key = "H/[", desc = "Previous tab" },
  { key = "L/]", desc = "Next tab" },
  { key = "1-9", desc = "Jump to tab" },
  { key = "s", desc = "Stop test run" },
  { key = "x", desc = "Close tab" },
  { key = "q", desc = "Close window" },
  { key = "g?", desc = "Show/hide help" },
}

---@return C.Widget
function M.HelpOverlay()
  local lines = {}

  table.insert(lines, C.Highlight("Title", C.Text("Keyboard Shortcuts")))
  table.insert(lines, C.Text(string.rep("─", 40)))

  for _, shortcut in ipairs(SHORTCUTS) do
    local line = string.format("%-12s %s", shortcut.key, shortcut.desc)
    table.insert(lines, C.Text(line))
  end

  return C.Stack(lines)
end

---@class NavigationPanelProps
---@field tabs TabInfo[]
---@field active_tab_key string|nil
---@field nodes TreeNode[]
---@field selected_id string|nil
---@field showing_help boolean
---@field filter_active boolean|nil
---@field scope_filter_id string|nil
---@field scope_breadcrumb string[]|nil

---@param props NavigationPanelProps
---@return C.Widget
function M.NavigationPanel(props)
  if props.showing_help then
    return M.HelpOverlay()
  end

  local children = {}

  if #props.nodes == 0 then
    table.insert(children, M.EmptyState())
  else
    if #props.tabs > 0 then
      table.insert(children, M.TabBar(props.tabs, props.active_tab_key))
    end
    -- Add breadcrumb if scope filter is active
    if props.scope_breadcrumb then
      table.insert(children, M.Breadcrumb(props.scope_breadcrumb))
    end
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
  end

  table.insert(children, M.Footer({
    filter_active = props.filter_active,
    scope_filter_id = props.scope_filter_id,
  }))

  return C.Stack(children)
end

return M
