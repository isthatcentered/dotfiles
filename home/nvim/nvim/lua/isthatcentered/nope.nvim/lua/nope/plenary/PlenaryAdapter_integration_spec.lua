local PlenaryAdapter = require("nope.plenary.PlenaryAdapter")

---@param runner Runner
---@param timeout_ms? number
---@return TestRunState?
local function run_and_wait(runner, timeout_ms)
  timeout_ms = timeout_ms or 30000
  local final_state = nil
  local done = false

  runner:listen(function(event)
    if event.type == "results" then
      final_state = event.payload
    end
    if event.type == "process_ended" then
      done = true
    end
  end)

  runner:start()
  vim.wait(timeout_ms, function()
    return done
  end, 100)

  return final_state
end

---Find test by name in state
---@param state TestRunState
---@param test_name string
---@return TestNode?
local function find_test(state, test_name)
  for _, file in ipairs(state.files) do
    for _, test in ipairs(file.tests) do
      if test.name:match(test_name) then
        return test
      end
    end
    for _, suite in ipairs(file.suites) do
      for _, test in ipairs(suite.tests) do
        if test.name:match(test_name) then
          return test
        end
      end
    end
  end
  return nil
end

---Find file by path pattern in state
---@param state TestRunState
---@param pattern string
---@return FileNode?
local function find_file(state, pattern)
  for _, file in ipairs(state.files) do
    if file.path:match(pattern) then
      return file
    end
  end
  return nil
end

local fixtures_dir = "lua/nope/fixtures/plenary"
local config_path = "scripts/minimal_init.vim"

describe("PlenaryAdapter integration", function()
  local adapter

  before_each(function()
    adapter = PlenaryAdapter.new()
  end)

  describe("single file - passing", function()
    it("captures all passing tests", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        file_path = fixtures_dir .. "/passing_spec.lua",
      })

      local state = run_and_wait(runner)

      assert.is_not_nil(state)
      assert.are.equal("done", state.status)
      assert.are.equal(2, state.summary.total)
      assert.are.equal(2, state.summary.passed)
      assert.are.equal(0, state.summary.failed)
    end)

    it("captures test names correctly", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        file_path = fixtures_dir .. "/passing_spec.lua",
      })

      local state = run_and_wait(runner)

      local test1 = find_test(state, "first passing test")
      local test2 = find_test(state, "second passing test")

      assert.is_not_nil(test1)
      assert.is_not_nil(test2)
      assert.are.equal("passed", test1.status)
      assert.are.equal("passed", test2.status)
    end)

    it("captures logs per test", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        file_path = fixtures_dir .. "/passing_spec.lua",
      })

      local state = run_and_wait(runner)

      local test1 = find_test(state, "first passing test")
      local test2 = find_test(state, "second passing test")

      assert.is_not_nil(test1)
      assert.is_not_nil(test1.logs)
      assert.is_true(#test1.logs > 0)
      assert.is_truthy(test1.logs[1]:match("first passing test executed"))

      assert.is_not_nil(test2)
      assert.is_not_nil(test2.logs)
      assert.is_true(#test2.logs > 0)
      assert.is_truthy(test2.logs[1]:match("second passing test executed"))
    end)
  end)

  describe("single file - failing", function()
    it("captures all failing tests", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        file_path = fixtures_dir .. "/failing_spec.lua",
      })

      local state = run_and_wait(runner)

      assert.is_not_nil(state)
      assert.are.equal("done", state.status)
      assert.are.equal(2, state.summary.total)
      assert.are.equal(0, state.summary.passed)
      assert.are.equal(2, state.summary.failed)
    end)

    it("captures failure details", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        file_path = fixtures_dir .. "/failing_spec.lua",
      })

      local state = run_and_wait(runner)

      local test1 = find_test(state, "first failing test")

      assert.is_not_nil(test1)
      assert.are.equal("failed", test1.status)
      assert.is_not_nil(test1.failure)
      assert.is_not_nil(test1.failure.message)
    end)

    it("captures logs for failing tests", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        file_path = fixtures_dir .. "/failing_spec.lua",
      })

      local state = run_and_wait(runner)

      local test1 = find_test(state, "first failing test")

      assert.is_not_nil(test1)
      assert.is_not_nil(test1.logs)
      assert.is_true(#test1.logs > 0)
      assert.is_truthy(test1.logs[1]:match("first failing test executed"))
    end)
  end)

  describe("single file - mixed", function()
    it("captures mixed results correctly", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        file_path = fixtures_dir .. "/mixed_spec.lua",
      })

      local state = run_and_wait(runner)

      assert.is_not_nil(state)
      assert.are.equal("done", state.status)
      assert.are.equal(2, state.summary.total)
      assert.are.equal(1, state.summary.passed)
      assert.are.equal(1, state.summary.failed)

      local passing = find_test(state, "passing test in mixed")
      local failing = find_test(state, "failing test in mixed")

      assert.are.equal("passed", passing.status)
      assert.are.equal("failed", failing.status)
    end)
  end)

  describe("multiple files", function()
    it("captures all files", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        directory_path = fixtures_dir,
      })

      local state = run_and_wait(runner)

      assert.is_not_nil(state)
      assert.are.equal("done", state.status)
      assert.are.equal(3, #state.files)

      local passing_file = find_file(state, "passing_spec%.lua")
      local failing_file = find_file(state, "failing_spec%.lua")
      local mixed_file = find_file(state, "mixed_spec%.lua")

      assert.is_not_nil(passing_file)
      assert.is_not_nil(failing_file)
      assert.is_not_nil(mixed_file)
    end)

    it("has correct summary counts", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        directory_path = fixtures_dir,
      })

      local state = run_and_wait(runner)

      assert.is_not_nil(state)
      -- 2 passing + 2 failing + 2 mixed = 6 total
      -- 2 passed + 0 + 1 = 3 passed
      -- 0 + 2 + 1 = 3 failed
      assert.are.equal(6, state.summary.total)
      assert.are.equal(3, state.summary.passed)
      assert.are.equal(3, state.summary.failed)
    end)

    it("associates logs with correct tests across files", function()
      local runner = adapter:get_runner({
        configuration_path = config_path,
        directory_path = fixtures_dir,
      })

      local state = run_and_wait(runner)

      local test_passing = find_test(state, "first passing test")
      local test_failing = find_test(state, "first failing test")
      local test_mixed_pass = find_test(state, "passing test in mixed")

      assert.is_not_nil(test_passing, "test_passing should exist")
      assert.is_not_nil(test_passing.logs, "test_passing.logs should exist")
      assert.is_true(#test_passing.logs > 0, "test_passing.logs should have entries")
      assert.is_truthy(test_passing.logs[1]:match("first passing test executed"))

      assert.is_not_nil(test_failing, "test_failing should exist")
      assert.is_not_nil(test_failing.logs, "test_failing.logs should exist")
      assert.is_true(#test_failing.logs > 0, "test_failing.logs should have entries")
      assert.is_truthy(test_failing.logs[1]:match("first failing test executed"))

      assert.is_not_nil(test_mixed_pass, "test_mixed_pass should exist")
      assert.is_not_nil(test_mixed_pass.logs, "test_mixed_pass.logs should exist")
      assert.is_true(#test_mixed_pass.logs > 0, "test_mixed_pass.logs should have entries")
      assert.is_truthy(test_mixed_pass.logs[1]:match("passing test in mixed executed"))
    end)
  end)
end)
