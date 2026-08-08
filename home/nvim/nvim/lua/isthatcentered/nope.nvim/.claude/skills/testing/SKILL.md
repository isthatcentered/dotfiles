---
name: testing
description: Guidelines for writing tests in this codebase. Use this skill when adding new tests, refactoring existing tests, planning test implementation, reviewing test code, or working with *_spec.lua files.
---

# Testing Skill

Guidelines for writing tests in nope.nvim. After reading this, you should produce consistent, maintainable tests.

## Framework & Location

- **Framework**: Plenary test runner (plenary.nvim) with busted syntax
- **Location**: Co-located with source files in `lua/nope/`
- **Pattern**: `*_spec.lua`
- **Run all**: `make test`
- **Run single**: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/path/to/file_spec.lua"`

## File Structure

```lua
-- 1. Test framework requires
local spy = require('luassert.spy')
local match = require('luassert.match')

-- 2. Module under test
local Signal = require('nope.Signal')

-- 3. Internal dependencies
local EventBus = require('nope.EventBus')

-- 4. Mock implementations (classes)
---@class MockRunner
local MockRunner = {}
MockRunner.__index = MockRunner

function MockRunner.new()
  return setmetatable({
    started = false,
    stopped = false,
  }, MockRunner)
end

function MockRunner:start()
  self.started = true
end

-- 5. Factory functions
local function make_state(overrides)
  return vim.tbl_deep_extend('force', {
    status = 'idle',
    summary = { total = 0, passed = 0, failed = 0, skipped = 0 },
    files = {},
  }, overrides or {})
end

-- 6. Tests
describe('Signal', function()
  describe('new', function()
    it('creates empty signal', function()
      -- test here
    end)
  end)
end)
```

## Test Naming Convention

Use **Verb + outcome** style:

```lua
-- GOOD
it('returns empty array when no versions exist', ...)
it('creates runner with generated id', ...)
it('fails with error for invalid input', ...)
it('groups items by category', ...)

-- BAD
it('test signal', ...)
it('should work', ...)
it('runner test', ...)
```

## Mocking

### Manual Mocks for Interfaces

Create mock objects implementing the expected interface:

```lua
-- GOOD - Manual mock implementing interface
---@class MockRepository
local MockRepository = {}
MockRepository.__index = MockRepository

function MockRepository.new()
  return setmetatable({
    calls = {},
  }, MockRepository)
end

function MockRepository:get_all()
  table.insert(self.calls, 'get_all')
  return { { id = 'test_item_1' }, { id = 'test_item_2' } }
end

function MockRepository:save(item)
  table.insert(self.calls, { 'save', item })
end
```

### Vim APIs - Use Real Neovim Instance

Tests run in a real Neovim instance. Use actual vim APIs (`vim.diagnostic.*`, `vim.api.*`, etc.) instead of mocking. Only mock for spy/callback testing.

```lua
-- GOOD - Use real vim APIs
it('creates diagnostic for failed test', function()
  local diagnostics = vim.diagnostic.get(0)
  assert.same(1, #diagnostics)
end)

-- BAD - Mocking vim APIs unnecessarily
it('creates diagnostic for failed test', function()
  local mock_diagnostic = { get = spy.new(function() return {} end) }
  -- Don't do this
end)
```

### Spies for Callback Tracking

Use `luassert.spy` for tracking function calls:

```lua
local spy = require('luassert.spy')
local match = require('luassert.match')

it('calls listener with emitted value', function()
  local signal = Signal.new()
  local listener = spy.new(function() end)
  signal:listen(listener)

  signal:emit('test_value')

  assert.spy(listener).was.called()
  assert.spy(listener).was.called_with('test_value')
end)

it('supports flexible matching', function()
  local s = spy.new(function() end)
  s({ name = 'test', count = 42 })

  assert.spy(s).was.called_with(match.is_table())
  assert.spy(s).was.called_with({
    name = match.is_string(),
    count = match.is_number(),
  })
end)
```

## Test Structure - Arrange/Act/Assert

Structure tests with AAA pattern. Sections should be self-evident from whitespace separation - **don't add comments**.

```lua
it('returns items for all categories', function()
  local repository = MockRepository.new()
  local service = Service.new(repository)

  local items = service:get_all()

  assert.same(2, #items)
  assert.same('test_item_1', items[1].id)
end)
```

## Assertions - Use assert.same

Use `assert.same()` for most assertions (deep equality):

```lua
-- GOOD - Single assertion on whole structure
assert.same({
  status = 'done',
  count = 3,
  items = { 'a', 'b', 'c' },
}, result)

-- BAD - Multiple individual assertions
assert.same('done', result.status)
assert.same(3, result.count)
assert.same(3, #result.items)
```

### Available Assertions

| Assertion | Use Case |
|-----------|----------|
| `assert.same(expected, actual)` | Deep equality (most common) |
| `assert.is_true(value)` | Boolean true |
| `assert.is_false(value)` | Boolean false |
| `assert.is_nil(value)` | Nil check |
| `assert.is_not_nil(value)` | Non-nil check |
| `assert.is_table(value)` | Type check |
| `assert.is_string(value)` | Type check |
| `assert.has_error(fn)` | Expects error |
| `assert.has_no.errors(fn)` | No error |

### Arrays - Assert on the Whole Array

```lua
-- GOOD - single assertion on whole array
assert.same({ { id = 1 }, { id = 2 } }, captured_calls)

-- BAD - separate length check + item assertions
assert.same(2, #captured_calls)
assert.same({ id = 1 }, captured_calls[1])
assert.same({ id = 2 }, captured_calls[2])
```

## Test Data Factories

Use `nope.fake` library for generating test data. See `lua/nope/fake/GUIDE.md` for comprehensive patterns.

### Basic Usage

```lua
local F = require('nope.fake')

-- Define reusable fakes
local StateFake = F.struct({
  status = F.pick({ 'idle', 'running', 'done' }),
  summary = F.struct({
    total = F.int_within_range(0, 100),
    passed = F.int_within_range(0, 50),
    failed = F.int_within_range(0, 10),
  }),
})

it('handles state', function()
  local state = StateFake:run()
  -- test with random state
end)
```

### Factory with Overrides

```lua
-- Module pattern with factory
local M = {}

M.Fake = F.struct({
  id = F.uuid,
  path = F.word,
  status = F.pick({ 'pending', 'passed', 'failed' }),
})

M.make = F.factory(M.Fake, function(gen, overrides)
  return vim.tbl_extend('force', gen, overrides)
end)

-- Usage: override only relevant fields
it('handles passed status', function()
  local file = FileFake.make({ status = 'passed' })
  assert.same('passed', file.status)
end)
```

### When to Use Each

| Scenario | Approach |
|----------|----------|
| Random test data | `Fake:run()` |
| Override specific fields | `F.factory()` with merge |
| Simple constant | `F.always(value)` |

## Async Testing

### With Coroutines

```lua
it('receives stdout from job', function()
  local co = coroutine.running()
  local stdout = {}

  local job = Job.new(
    { 'echo', 'test_value' },
    function(out) table.insert(stdout, out) end,
    function() end,
    function() coroutine.resume(co) end
  )

  job:start()
  coroutine.yield()

  assert.same({ { 'test_value' } }, stdout)
end)
```

### With vim.wait

```lua
it('calls function after delay', function()
  local called = false
  local debounced = debounce(function()
    called = true
  end, 50)

  debounced()
  assert.is_false(called)

  vim.wait(100, function() return called end)

  assert.is_true(called)
end)
```

## Setup/Teardown

```lua
describe('Service', function()
  local service
  local mock_repo

  before_each(function()
    mock_repo = MockRepository.new()
    service = Service.new(mock_repo)
  end)

  after_each(function()
    if service then
      pcall(function() service:close() end)
    end
  end)

  it('does something', function()
    -- service and mock_repo are fresh
  end)
end)
```

## Edge Case Testing

Focus on edge cases in business logic:

```lua
describe('edge cases', function()
  it('handles empty input gracefully', function()
    local result = process({})
    assert.same({}, result)
  end)

  it('propagates listener errors', function()
    local signal = Signal.new()
    signal:listen(function()
      error('listener error')
    end)

    assert.has_error(function()
      signal:emit('test')
    end)
  end)

  it('handles re-entrant calls', function()
    local signal = Signal.new()
    local calls = {}

    signal:listen(function(v)
      table.insert(calls, v)
      if v == 1 then
        signal:emit(2)
      end
    end)

    signal:emit(1)

    assert.same({ 1, 2 }, calls)
  end)
end)
```

## Descriptive Test Values

Use values that indicate their source/purpose:

```lua
-- GOOD - Values indicate what they represent
local mock_repo = {
  get_items = function()
    return {
      { id = 'staging_item_v1.2.3', env = 'staging' },
      { id = 'prod_item_v1.0.0', env = 'prod' },
    }
  end,
}

-- BAD - Generic values obscure meaning
local mock_repo = {
  get_items = function()
    return {
      { id = '1', env = 'a' },
      { id = '2', env = 'b' },
    }
  end,
}
```

## Checklist Before Committing Tests

- [ ] Test names follow "Verb + outcome" convention
- [ ] Arrange/Act/Assert sections are clear (whitespace separated)
- [ ] Manual mocks implement interfaces, spies used for callbacks
- [ ] Test data uses factory functions with `vim.tbl_deep_extend`
- [ ] Edge cases in business logic are covered
- [ ] Values are descriptive, not generic
- [ ] `make test` passes
