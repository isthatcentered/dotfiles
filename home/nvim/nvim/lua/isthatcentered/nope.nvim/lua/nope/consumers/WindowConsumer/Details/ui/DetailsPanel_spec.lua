local C = require("nope.ui2")
local BC = require("nope.consumers.WindowConsumer.Details.ui.DetailsPanel")

---@return C.BoxConstraints
local function unconstrained()
  return {
    max_width = math.huge,
    min_width = 0,
  }
end

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

---Trim trailing whitespace from each line (render pads lines)
---@param lines string[]
---@return string[]
local function trim_lines(lines)
  local result = {}
  for _, line in ipairs(lines) do
    local trimmed = line:gsub("%s+$", "")
    result[#result + 1] = trimmed
  end
  return result
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
    assert.equals(2, #lines)
    assert.is_true(vim.trim(lines[1]) == "✓ test")
    assert.is_true(vim.trim(lines[2]) == "Duration: 123.45ms")
  end)

  it("shows location when present", function()
    local test = { full_name = "test", status = "passed", location = { line = 10, column = 5 } }
    local widget = BC.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(2, #lines)
    assert.is_true(vim.trim(lines[1]) == "✓ test")
    assert.is_true(vim.trim(lines[2]) == "Location: line 10, col 5")
  end)

  it("shows both duration and location when present", function()
    local test = { full_name = "test", status = "passed", duration_ms = 50, location = { line = 5, column = 1 } }
    local widget = BC.TestHeader(test)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(3, #lines)
    assert.is_true(vim.trim(lines[1]) == "✓ test")
    assert.is_true(vim.trim(lines[2]) == "Duration: 50.00ms")
    assert.is_true(vim.trim(lines[3]) == "Location: line 5, col 1")
  end)
end)

describe("Logs", function()
  before_each(reset_editor)

  it("shows logs header and content", function()
    local widget = BC.Logs({ "log line 1", "log line 2" })

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(3, #lines)
    assert.equals("Logs:", vim.trim(lines[1]))
    assert.equals("log line 1", vim.trim(lines[2]))
    assert.equals("log line 2", vim.trim(lines[3]))
  end)

  it("shows (none) when no logs", function()
    local widget = BC.Logs(nil)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(2, #lines)
    assert.equals("Logs:", vim.trim(lines[1]))
    assert.equals("(none)", vim.trim(lines[2]))
  end)

  it("shows (none) when empty logs array", function()
    local widget = BC.Logs({})

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(2, #lines)
    assert.equals("Logs:", vim.trim(lines[1]))
    assert.equals("(none)", vim.trim(lines[2]))
  end)

  it("splits multiline logs", function()
    local widget = BC.Logs({ "line1\nline2" })

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(3, #lines)
    assert.equals("Logs:", vim.trim(lines[1]))
    assert.equals("line1", vim.trim(lines[2]))
    assert.equals("line2", vim.trim(lines[3]))
  end)

  it("strips ANSI codes from logs", function()
    local widget = BC.Logs({ "\027[31mred text\027[0m" })

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.equals(2, #lines)
    assert.equals("Logs:", vim.trim(lines[1]))
    assert.equals("red text", vim.trim(lines[2]))
  end)
end)

describe("Failure", function()
  before_each(reset_editor)

  it("shows error message", function()
    local failure = { message = "Expected true but got false" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = trim_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.same({ "Error:", "  Expected true but got false", "" }, lines)
  end)

  it("shows multiline error message", function()
    local failure = { message = "line1\nline2" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = trim_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.same({ "Error:", "  line1", "  line2", "" }, lines)
  end)

  it("shows diff section", function()
    local failure = { diff = "+added\n-removed\n unchanged" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = trim_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.same({ "Diff:", "+added", "-removed", " unchanged", "" }, lines)
  end)

  it("shows stack trace", function()
    local failure = { stack = "at file.lua:10\nat other.lua:20" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = trim_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.same({ "Stack trace:", "  at file.lua:10", "  at other.lua:20" }, lines)
  end)

  it("shows all sections when present", function()
    local failure = { message = "error", diff = "+a\n-b", stack = "at x:1" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = trim_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.same({ "Error:", "  error", "", "Diff:", "+a", "-b", "", "Stack trace:", "  at x:1" }, lines)
  end)

  it("strips ANSI codes from all sections", function()
    local failure = { message = "\027[31mred\027[0m" }
    local widget = BC.Failure(failure)

    local buf = vim.api.nvim_create_buf(false, true)
    C.render(buf, widget, { max_width = 80, min_width = 0 })

    local lines = trim_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.same({ "Error:", "  red", "" }, lines)
  end)
end)

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

    local lines = trim_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
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
