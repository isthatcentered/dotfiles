---@class PlenaryOutputParser
---@field private state TestRunState
---@field private current_file FileNode?
---@field private current_test_name string?
---@field private collecting_error boolean
---@field private error_lines string[]
---@field private pending_logs string[]
local M = {}
M.__index = M

---Strip ANSI color codes from string
---@param str string
---@return string
local function strip_ansi(str)
  local result = str:gsub("\027%[[%d;]*m", "")
  return result
end

---Extract line number from error message
---Example: "...nope.nvim/lua/nope/fixtures/other_spec.lua:17: Expected..."
---@param error_msg string
---@return number?
local function extract_line_number(error_msg)
  local line = error_msg:match(":(%d+):")
  return line and tonumber(line) or nil
end

---Create initial empty state
---@return TestRunState
local function make_initial_state()
  return {
    status = "idle",
    duration_ms = 0,
    files = {},
    summary = {
      total = 0,
      passed = 0,
      failed = 0,
      skipped = 0,
    },
  }
end

---@return PlenaryOutputParser
function M.new()
  return setmetatable({
    state = make_initial_state(),
    current_file = nil,
    current_test_name = nil,
    collecting_error = false,
    error_lines = {},
    pending_logs = {},
  }, M)
end

---@return TestRunState
function M:get_state()
  return self.state
end

---Reset parser state for new run
function M:reset()
  self.state = make_initial_state()
  self.current_file = nil
  self.current_test_name = nil
  self.collecting_error = false
  self.error_lines = {}
  self.pending_logs = {}
end

---Finalize error collection for current failed test
function M:finalize_error()
  if not self.collecting_error or not self.current_file or not self.current_test_name then
    return
  end

  local error_msg = table.concat(self.error_lines, "\n")
  local line_num = extract_line_number(error_msg)

  -- Find the test and update its failure info
  for _, test in ipairs(self.current_file.tests) do
    if test.name == self.current_test_name then
      test.failure = {
        message = error_msg,
      }
      if line_num then
        test.location = { line = line_num, column = 1 }
      end
      break
    end
  end

  self.collecting_error = false
  self.error_lines = {}
  self.current_test_name = nil
end

---Parse a single line of output
---@param line string
function M:parse_line(line)
  local clean = strip_ansi(line)

  -- Skip empty lines
  if clean:match("^%s*$") then
    return
  end

  -- Check for file header: "Testing: \t/path/to/file_spec.lua\t"
  local file_path = clean:match("^Testing:%s*(.+)%s*$")
  if file_path then
    self:finalize_error()
    -- Clear pending logs when starting a new file
    self.pending_logs = {}
    file_path = vim.trim(file_path)
    -- Look for existing pending file from Scheduling: line
    -- Scheduling uses relative paths, Testing uses absolute paths
    for _, file in ipairs(self.state.files) do
      if file.path == file_path or file_path:match(vim.pesc(file.path) .. "$") then
        self.current_file = file
        self.current_file.path = file_path -- Update to absolute path
        self.current_file.id = "file:" .. file_path
        return
      end
    end
    -- Fallback: create new file if not found (shouldn't happen normally)
    self.current_file = {
      id = "file:" .. file_path,
      path = file_path,
      status = "pending",
      suites = {},
      tests = {},
    }
    table.insert(self.state.files, self.current_file)
    self.state.status = "pending"
    return
  end

  -- Check for success result: "Success\t||\tTest Name"
  local success_name = clean:match("^Success%s*||%s*(.+)$")
  if success_name and self.current_file then
    self:finalize_error()
    success_name = vim.trim(success_name)
    local test_node = {
      id = "test:" .. success_name,
      name = success_name,
      full_name = success_name,
      status = "passed",
    }
    -- Attach pending logs to this test
    if #self.pending_logs > 0 then
      test_node.logs = self.pending_logs
      self.pending_logs = {}
    end
    table.insert(self.current_file.tests, test_node)
    self.state.summary.passed = self.state.summary.passed + 1
    self.state.summary.total = self.state.summary.total + 1
    return
  end

  -- Check for fail result: "Fail\t||\tTest Name"
  local fail_name = clean:match("^Fail%s*||%s*(.+)$")
  if fail_name and self.current_file then
    self:finalize_error()
    fail_name = vim.trim(fail_name)
    local test_node = {
      id = "test:" .. fail_name,
      name = fail_name,
      full_name = fail_name,
      status = "failed",
    }
    -- Attach pending logs to this test
    if #self.pending_logs > 0 then
      test_node.logs = self.pending_logs
      self.pending_logs = {}
    end
    table.insert(self.current_file.tests, test_node)
    self.state.summary.failed = self.state.summary.failed + 1
    self.state.summary.total = self.state.summary.total + 1
    self.current_test_name = fail_name
    self.collecting_error = true
    self.error_lines = {}
    return
  end

  -- Check for summary lines (end of file block)
  if clean:match("^Success:%s*%d+") then
    self:finalize_error()
    if self.current_file then
      -- Determine file status based on tests
      local has_failed = false
      for _, test in ipairs(self.current_file.tests) do
        if test.status == "failed" then
          has_failed = true
          break
        end
      end
      self.current_file.status = has_failed and "failed" or "passed"
    end
    return
  end

  if clean:match("^Failed%s*:%s*%d+") or clean:match("^Errors%s*:%s*%d+") then
    self:finalize_error()
    return
  end

  -- Check for separator (end of file block)
  if clean:match("^=+$") then
    self:finalize_error()
    return
  end

  -- Check for scheduling lines (initial output) - create pending file entries
  -- Note: First scheduling line may have "Starting..." prefix
  local scheduled_path = clean:match("Scheduling:%s*(.+)$")
  if scheduled_path then
    scheduled_path = vim.trim(scheduled_path)
    local file_node = {
      id = "file:" .. scheduled_path,
      path = scheduled_path,
      status = "pending",
      suites = {},
      tests = {},
    }
    table.insert(self.state.files, file_node)
    self.state.status = "pending"
    return
  end

  -- Check for "Tests Failed. Exit:" line
  if clean:match("^Tests Failed%. Exit:") then
    return
  end

  -- Check for unexpected error block
  if clean:match("^We had an unexpected error:") then
    self:finalize_error()
    -- Mark current file as having errors
    if self.current_file then
      self.current_file.status = "failed"
    end
    return
  end

  -- If collecting error, accumulate lines
  if self.collecting_error then
    -- Skip empty indentation-only lines at the start
    if #self.error_lines > 0 or not clean:match("^%s*$") then
      table.insert(self.error_lines, vim.trim(clean))
    end
    return
  end

  -- If we're in a file context and not collecting errors, treat unrecognized lines as logs
  if self.current_file then
    table.insert(self.pending_logs, vim.trim(clean))
  end
end

---Mark run as complete
function M:complete()
  self:finalize_error()
  self.state.status = "done"
end

return M
