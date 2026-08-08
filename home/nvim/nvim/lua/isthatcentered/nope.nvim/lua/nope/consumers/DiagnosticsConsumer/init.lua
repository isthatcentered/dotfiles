---@alias DiagnosticsConsumer.OnEvent fun(callback: fun(event: NopeEvent)): fun()

---@class DiagnosticsConsumer
---@field private ns_id number
---@field private run_files table<string, string[]> -- run_key -> list of file paths with diagnostics
local DiagnosticsConsumer = {}
DiagnosticsConsumer.__index = DiagnosticsConsumer

---Constructor for DiagnosticsConsumer
---@param on_event DiagnosticsConsumer.OnEvent
---@return DiagnosticsConsumer
function DiagnosticsConsumer.new(on_event)
  local self = setmetatable({
    ns_id = vim.api.nvim_create_namespace("nope"),
    run_files = {},
  }, DiagnosticsConsumer)

  on_event(function(event)
    if event.type == "NopeTestRunStarted" then
      local key = event.payload.key
      if key then
        self:_clear_run_diagnostics(key)
        self.run_files[key] = {}
      end
    elseif event.type == "NopeTestRunResults" then
      local key = event.payload.key
      self:_update(event.payload.results, key)
    end
  end)

  return self
end

---Collect all failed tests from a file node
---@private
---@param file FileNode
---@return {test: TestNode, file_path: string}[]
function DiagnosticsConsumer:_collect_failed_tests(file)
  local failed = {}

  ---@param tests TestNode[]
  ---@param file_path string
  local function collect_from_tests(tests, file_path)
    for _, test in ipairs(tests) do
      if test.status == "failed" and test.location then
        table.insert(failed, { test = test, file_path = file_path })
      end
    end
  end

  ---@param suites SuiteNode[]
  ---@param file_path string
  local function collect_from_suites(suites, file_path)
    for _, suite in ipairs(suites) do
      collect_from_tests(suite.tests, file_path)
      collect_from_suites(suite.suites, file_path)
    end
  end

  collect_from_tests(file.tests, file.path)
  collect_from_suites(file.suites, file.path)

  return failed
end

---Get first line of error message
---@private
---@param message string
---@return string
function DiagnosticsConsumer:_get_first_line(message)
  local first_line = message:match("^[^\n]+")
  return first_line or message
end

---Clear diagnostics for a specific run's files
---@private
---@param run_key string
function DiagnosticsConsumer:_clear_run_diagnostics(run_key)
  local files = self.run_files[run_key]
  if not files then
    return
  end

  for _, file_path in ipairs(files) do
    local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(file_path))
    vim.diagnostic.set(self.ns_id, bufnr, {})
  end
end

---Update diagnostics based on test run state
---@private
---@param state TestRunState
---@param run_key string|nil
---@return nil
function DiagnosticsConsumer:_update(state, run_key)
  local file_paths = {}

  -- Update diagnostics per-file (allows incremental updates without clearing other files)
  for _, file in ipairs(state.files) do
    table.insert(file_paths, file.path)

    local failed_tests = self:_collect_failed_tests(file)
    local diagnostics = {}

    for _, item in ipairs(failed_tests) do
      local test = item.test
      local message = test.failure and test.failure.message or "Test failed"

      table.insert(diagnostics, {
        lnum = test.location.line - 1, -- 0-indexed
        col = test.location.column - 1, -- 0-indexed
        message = self:_get_first_line(message),
        severity = vim.diagnostic.severity.ERROR,
        source = "nope",
      })
    end

    -- Set diagnostics for this file (replaces existing ones for this file only)
    local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(file.path))
    vim.diagnostic.set(self.ns_id, bufnr, diagnostics)
  end

  -- Track which files belong to this run
  if run_key then
    self.run_files[run_key] = file_paths
  end
end

local M = {}
M.new = DiagnosticsConsumer.new
return M
