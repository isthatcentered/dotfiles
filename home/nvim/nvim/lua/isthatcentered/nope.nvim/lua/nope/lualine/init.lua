local M = require("lualine.component"):extend()

local HIGHLIGHTS = {
  passing = "IsThatCenteredLualineNeotestPasing",
  failing = "IsThatCenteredLualineNeotestFailing",
  pending = "IsThatCenteredLualineNeotestPending",
}

-- Module state: file_path -> {timestamp, run_key, summary, status}
local file_results = {}
local listener_setup = false

---Count tests recursively in suites
---@param suites SuiteNode[]|nil
---@return number
local function count_tests_in_suites(suites)
  local count = 0
  for _, suite in ipairs(suites or {}) do
    count = count + #(suite.tests or {})
    count = count + count_tests_in_suites(suite.suites)
  end
  return count
end

---Count tests by status recursively in suites
---@param suites SuiteNode[]|nil
---@param status TestStatus
---@return number
local function count_by_status_in_suites(suites, status)
  local count = 0
  for _, suite in ipairs(suites or {}) do
    for _, test in ipairs(suite.tests or {}) do
      if test.status == status then
        count = count + 1
      end
    end
    count = count + count_by_status_in_suites(suite.suites, status)
  end
  return count
end

---Compute per-file summary from FileNode
---@param file FileNode
---@return TestRunSummary
local function compute_file_summary(file)
  local total = #(file.tests or {}) + count_tests_in_suites(file.suites)

  local passed, failed, skipped = 0, 0, 0
  for _, test in ipairs(file.tests or {}) do
    if test.status == "passed" then
      passed = passed + 1
    elseif test.status == "failed" then
      failed = failed + 1
    elseif test.status == "skipped" then
      skipped = skipped + 1
    end
  end
  passed = passed + count_by_status_in_suites(file.suites, "passed")
  failed = failed + count_by_status_in_suites(file.suites, "failed")
  skipped = skipped + count_by_status_in_suites(file.suites, "skipped")

  return { total = total, passed = passed, failed = failed, skipped = skipped }
end

local function setup_listener()
  if listener_setup then
    return
  end
  listener_setup = true

  vim.api.nvim_create_autocmd("User", {
    pattern = { "NopeTestRunResults" },
    callback = function(args)
      local payload = args.data
      local timestamp = vim.loop.now()
      for _, file in ipairs(payload.results.files or {}) do
        file_results[file.path] = {
          timestamp = timestamp,
          run_key = payload.key,
          summary = compute_file_summary(file),
          status = payload.results.status,
        }
      end
    end,
  })
end

---@param str string
---@param hl string
---@return string
function M:apply_highlight(str, hl)
  return string.format("%%#%s#%s%%*", hl, str)
end

function M:init(options)
  M.super.init(self, options)
  setup_listener()
end

function M:update_status()
  local bufname = vim.api.nvim_buf_get_name(0)
  local result = file_results[bufname]

  if not result then
    return ""
  end

  local s = result.summary

  if result.status == "pending" then
    return self:apply_highlight(string.format("PENDING (%d/%d)", s.passed, s.total), HIGHLIGHTS.pending)
  end

  if s.failed > 0 then
    return self:apply_highlight(string.format("FAIL (%d/%d)", s.failed, s.total), HIGHLIGHTS.failing)
  end

  return self:apply_highlight(string.format("PASS (%d/%d)", s.passed, s.total), HIGHLIGHTS.passing)
end

return M
