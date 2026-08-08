# Testing Guide: nope/fake Library

## Core Concept

Fake generates random test data lazily. Compose fakes, then call `:run()` to execute.

```lua
local F = require('nope.fake')
local user = F.struct({ name = F.word, age = F.int }):run()
```

---

## Pattern 1: Basic Struct Generation

Generate objects with random fields.

### Do

```lua
-- Define once, reuse
local DiagnosticFake = F.struct({
  message = F.word,
  severity = F.pick({ 1, 2, 3, 4 }),
  lnum = F.int_within_range(0, 100),
  col = F.int_within_range(0, 80),
})

it('processes diagnostic', function()
  local diag = DiagnosticFake:run()
  -- test with diag
end)
```

```lua
-- Nest structs for complex objects
local BufferStateFake = F.struct({
  bufnr = F.int_within_range(1, 100),
  diagnostics = F.array(DiagnosticFake, { min = 1, max = 5 }),
  is_modified = F.boolean,
})
```

```lua
-- Use pick() for enums/constants
local severity = F.pick({ vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN })
```

### Don't

```lua
-- DON'T: Inline random generation (not reproducible)
local diag = {
  message = 'test' .. math.random(100),
  severity = math.random(4),
}

-- DON'T: Hardcode values when randomness tests edge cases
local diag = { message = 'test', severity = 1, lnum = 0 }

-- DON'T: Generate inside struct (call :run() only at end)
local bad = F.struct({
  id = F.uuid:run(),  -- WRONG: runs immediately
})
```

---

## Pattern 2: Factory with Overrides

Create objects with sensible defaults, override specific fields for tests.

### Do

```lua
-- Define Fake on module
local M = {}

M.Fake = F.struct({
  id = F.uuid,
  name = F.word,
  enabled = F.boolean,
  priority = F.int_within_range(1, 10),
})

-- Factory with user-provided merge
M.make = F.factory(M.Fake, function(gen, overrides)
  return vim.tbl_extend('force', gen, overrides)
end)

return M
```

```lua
-- Usage: override only what matters for test
local Config = require('nope.config')

it('disabled config skips processing', function()
  local config = Config.make({ enabled = false })
  assert.is_false(config.enabled)
  -- other fields are random but irrelevant to this test
end)

it('high priority processes first', function()
  local config = Config.make({ priority = 10 })
  assert.equals(10, config.priority)
end)
```

```lua
-- Custom merge for nested objects
M.make = F.factory(M.Fake, function(gen, overrides)
  local result = vim.tbl_extend('force', gen, overrides)
  if overrides.settings then
    result.settings = vim.tbl_extend('force', gen.settings, overrides.settings)
  end
  return result
end)
```

### Don't

```lua
-- DON'T: Recreate entire object when testing one field
it('test priority', function()
  local config = {
    id = 'test-id',
    name = 'test',
    enabled = true,
    priority = 10,  -- only this matters
  }
end)

-- DON'T: Use factory without merge function for complex objects
M.make = function(overrides)
  return vim.tbl_extend('force', M.Fake:run(), overrides or {})
end  -- Works but F.factory is cleaner

-- DON'T: Forget overrides are shallow-merged by default
M.make({ nested = { one_field = 1 } })  -- Replaces entire nested object
```

---

## Pattern 3: Collections and Relationships

Generate arrays and related objects.

### Do

```lua
-- Fixed-size array
local three_items = F.array_n(F.word, 3)

-- Variable-size with bounds
local some_items = F.array(F.word, { min = 1, max = 5 })

-- Non-empty guarantee
local at_least_one = F.non_empty_array(F.word)
```

```lua
-- Parent-child relationships via chain
local WindowWithBuffersFake = F.int_within_range(1, 10):chain(function(win_id)
  return F.struct({
    id = F.always(win_id),
    buffers = F.array(F.struct({
      bufnr = F.int,
      win_id = F.always(win_id),  -- Reference parent
    }), { min = 1, max = 3 }),
  })
end)
```

```lua
-- Zip for combining independent fakes
local pair = F.struct({ user = UserFake }):zip(F.struct({ org = OrgFake }))
  :map(function(tuple)
    local user_data, org_data = tuple[1], tuple[2]
    return { user = user_data.user, org = org_data.org }
  end)
```

### Don't

```lua
-- DON'T: Manually loop when array functions exist
local items = {}
for i = 1, 5 do
  items[i] = F.word:run()  -- Use F.array_n(F.word, 5) instead
end

-- DON'T: Forget relationships between parent/child
local win = F.int:run()
local buf = F.struct({ win_id = F.int }):run()  -- win_id won't match!

-- DON'T: Use array for guaranteed non-empty (might return {})
local items = F.array(F.word):run()
assert(#items > 0)  -- May fail! Use non_empty_array
```

---

## Pattern 4: Conditional and Variant Generation

Handle unions, optionals, and conditional types.

### Do

```lua
-- Optional fields
local MaybeMessageFake = F.struct({
  required_field = F.word,
  optional_field = F.word:nullable(),
})

-- Union types via or_else
local StatusFake = F.always('pending')
  :or_else(F.always('running'))
  :or_else(F.always('done'))

-- Weighted selection
local ResultFake = F.pick({ 'success', 'success', 'success', 'error' })  -- 75% success
```

```lua
-- Variant based on type field
local EventFake = F.pick({ 'click', 'hover', 'scroll' }):chain(function(type)
  if type == 'click' then
    return F.struct({ type = F.always(type), x = F.int, y = F.int })
  elseif type == 'hover' then
    return F.struct({ type = F.always(type), element = F.word })
  else
    return F.struct({ type = F.always(type), delta = F.int })
  end
end)
```

```lua
-- Polymorphic variant (like TS tagged unions)
local Node = {}
Node.LeafFake = F.struct({ tag = F.always('leaf'), value = F.word })
Node.BranchFake = F.struct({ tag = F.always('branch'), children = F.array(F.word) })
Node.Fake = Node.LeafFake:or_else(Node.BranchFake)
```

### Don't

```lua
-- DON'T: Use nil directly (not composable)
local bad = F.struct({
  field = nil,  -- Not a Fake!
})

-- DON'T: Generate all variants then pick (wasteful)
local all = { F.struct({...}):run(), F.struct({...}):run() }
local one = all[math.random(#all)]  -- Generated both, used one

-- DON'T: Forget to use F.always() for constants
local bad = F.struct({
  type = 'constant',  -- Error: string is not a Fake
})
```

---

## Quick Reference

| Function | Purpose | Example |
|----------|---------|---------|
| `F.struct({})` | Object with fields | `F.struct({ a = F.int })` |
| `F.array(fake, {min, max})` | Variable array | `F.array(F.word, {min=1})` |
| `F.array_n(fake, n)` | Fixed array | `F.array_n(F.int, 3)` |
| `F.non_empty_array(fake)` | Guaranteed 1+ | `F.non_empty_array(F.word)` |
| `F.pick(array)` | Random element | `F.pick({'a','b','c'})` |
| `F.always(val)` | Constant | `F.always('fixed')` |
| `:map(fn)` | Transform | `F.int:map(tostring)` |
| `:chain(fn)` | Dependent fake | `F.int:chain(fn_returning_fake)` |
| `:zip(other)` | Combine as tuple | `F.int:zip(F.word)` |
| `:or_else(other)` | Random choice | `F.always(1):or_else(F.always(2))` |
| `:nullable()` | Maybe nil | `F.word:nullable()` |
| `F.factory(fake, merge)` | Make with overrides | `F.factory(UserFake, vim.tbl_extend)` |
