local C = require("nope.ui2")

local M = {}

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

---@param suite SuiteNode
---@return C.Widget
function M.SuiteDetails(suite)
  local icon = ICONS[suite.status] or "?"
  local passed, failed = count_tests(suite.tests, suite.suites)
  local text = string.format("%s 󰙅 %s (%d passed, %d failed)", icon, suite.name, passed, failed)
  return C.Highlight(HL_GROUPS[suite.status], C.Text(text))
end

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

return M
