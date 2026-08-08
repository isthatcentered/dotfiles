---@diagnostic disable: undefined-field
local F = require('nope.fake')


---@param values number[]
---@return fun(): number
function barrel_random(values)
  local index = 0
  return function()
    index = (index % #values) + 1
    return values[index]
  end
end

---@param value number
---@return fun(): number
function fixed_random(value)
  return function()
    return value
  end
end



describe('nope.fake', function()
  describe('always', function()
    it('returns the constant value', function()
      local fa = F.always(42)
      assert.same(42, fa:run())
    end)

    it('works with any type', function()
      local str = F.always('hello')
      local tbl = F.always({ a = 1 })
      assert.same('hello', str:run())
      assert.same({ a = 1 }, tbl:run())
    end)
  end)

  describe('Fake:gen', function()
    it('uses provided random function', function()
      local fa = F.always(99)
      local random = fixed_random(0.5)
      assert.same(99, fa:gen(random))
    end)
  end)

  describe('int_within_range', function()
    it('returns min when random is 0', function()
      local fa = F.int_within_range(10, 20)
      local random = fixed_random(0)
      assert.same(10, fa:gen(random))
    end)

    it('returns max when random is ~1', function()
      local fa = F.int_within_range(10, 20)
      local random = fixed_random(0.9999)
      assert.same(20, fa:gen(random))
    end)

    it('returns value in middle of range', function()
      local fa = F.int_within_range(0, 10)
      local random = fixed_random(0.5)
      assert.same(5, fa:gen(random))
    end)
  end)

  describe('int', function()
    it('returns integer between 0 and 1e9', function()
      local fa = F.int
      local random = fixed_random(0.5)
      local result = fa:gen(random)
      assert.is_true(result >= 0)
      assert.is_true(result <= 1e9)
      assert.same(math.floor(result), result)
    end)
  end)

  describe('boolean', function()
    it('returns true when random >= 0.5', function()
      local fa = F.boolean
      local random = fixed_random(0.5)
      assert.same(true, fa:gen(random))
    end)

    it('returns false when random < 0.5', function()
      local fa = F.boolean
      local random = fixed_random(0.4)
      assert.same(false, fa:gen(random))
    end)
  end)

  describe('pick', function()
    it('picks first element when random is 0', function()
      local fa = F.pick({ 'a', 'b', 'c' })
      local random = fixed_random(0)
      assert.same('a', fa:gen(random))
    end)

    it('picks last element when random is ~1', function()
      local fa = F.pick({ 'a', 'b', 'c' })
      local random = fixed_random(0.9999)
      assert.same('c', fa:gen(random))
    end)

    it('picks middle element when random is ~0.5', function()
      local fa = F.pick({ 'a', 'b', 'c' })
      local random = fixed_random(0.5)
      assert.same('b', fa:gen(random))
    end)
  end)

  describe(':map', function()
    it('transforms the value', function()
      local fa = F.always(5):map(function(n)
        return n * 2
      end)
      assert.same(10, fa:run())
    end)

    it('chains multiple maps', function()
      local fa = F.always(2)
        :map(function(n)
          return n + 1
        end)
        :map(function(n)
          return n * 3
        end)
      assert.same(9, fa:run())
    end)
  end)

  describe(':chain', function()
    it('flatMaps to another Fake', function()
      local fa = F.always(10):chain(function(n)
        return F.always(n + 5)
      end)
      assert.same(15, fa:run())
    end)

    it('passes random through to inner Fake', function()
      local fa = F.always(0):chain(function()
        return F.int_within_range(0, 10)
      end)
      local random = fixed_random(0.5)
      assert.same(5, fa:gen(random))
    end)
  end)

  describe(':zip', function()
    it('combines two Fakes into tuple', function()
      local fa = F.always('a'):zip(F.always('b'))
      assert.same({ 'a', 'b' }, fa:run())
    end)

    it('uses same random for both', function()
      local fa = F.int_within_range(0, 10):zip(F.int_within_range(0, 10))
      local random = barrel_random({ 0.5, 0.2 })
      assert.same({ 5, 2 }, fa:gen(random))
    end)
  end)

  describe(':or_else', function()
    it('picks first when random < 0.5', function()
      local fa = F.always('a'):or_else(F.always('b'))
      local random = barrel_random({ 0.3, 0 })
      assert.same('a', fa:gen(random))
    end)

    it('picks second when random >= 0.5', function()
      local fa = F.always('a'):or_else(F.always('b'))
      local random = barrel_random({ 0.7, 0 })
      assert.same('b', fa:gen(random))
    end)
  end)

  describe('sequence', function()
    it('combines fakes into array', function()
      local fa = F.sequence(F.always('a'), F.always('b'), F.always('c'))
      assert.same({ 'a', 'b', 'c' }, fa:run())
    end)

    it('uses same random for all', function()
      local fa = F.sequence(
        F.int_within_range(0, 10),
        F.int_within_range(0, 10),
        F.int_within_range(0, 10)
      )
      local random = barrel_random({ 0.1, 0.5, 0.9 })
      assert.same({ 1, 5, 9 }, fa:gen(random))
    end)
  end)

  describe('struct', function()
    it('combines fakes into table with keys', function()
      local fa = F.struct({
        name = F.always('alice'),
        age = F.always(30),
      })
      assert.same({ name = 'alice', age = 30 }, fa:run())
    end)

    it('uses same random for all fields', function()
      local fa = F.struct({
        a = F.int_within_range(0, 10),
        b = F.int_within_range(0, 10),
      })
      local random = barrel_random({ 0.2, 0.8 })
      local result = fa:gen(random)
      -- pairs() order is non-deterministic, so just check values are from range
      assert.is_true(result.a >= 0 and result.a <= 10)
      assert.is_true(result.b >= 0 and result.b <= 10)
      -- ensure both consume from random
      assert.is_true(result.a ~= result.b or (result.a == 2 and result.b == 2))
    end)
  end)

  describe('array_n', function()
    it('generates fixed-size array', function()
      local fa = F.array_n(F.always('x'), 3)
      assert.same({ 'x', 'x', 'x' }, fa:run())
    end)

    it('uses same random for each element', function()
      local fa = F.array_n(F.int_within_range(0, 10), 3)
      local random = barrel_random({ 0.1, 0.5, 0.9 })
      assert.same({ 1, 5, 9 }, fa:gen(random))
    end)
  end)

  describe('array', function()
    it('generates variable-size array with defaults', function()
      local fa = F.array(F.always('x'))
      local random = barrel_random({ 0.5 }) -- mid-range = ~5 elements
      local result = fa:gen(random)
      assert.is_true(#result >= 0 and #result <= 10)
    end)

    it('respects min/max params', function()
      local fa = F.array(F.always('x'), { min = 2, max = 4 })
      local random = barrel_random({ 0, 0, 0, 0, 0 })
      local result = fa:gen(random)
      assert.same(2, #result)
    end)
  end)

  describe(':nullable', function()
    it('returns nil when random < 0.5', function()
      local fa = F.always('value'):nullable()
      local random = barrel_random({ 0.3 })
      assert.same(nil, fa:gen(random))
    end)

    it('returns value when random >= 0.5', function()
      local fa = F.always('value'):nullable()
      local random = barrel_random({ 0.7, 0 })
      assert.same('value', fa:gen(random))
    end)
  end)

  describe('record', function()
    it('generates table with random keys and values', function()
      local fa = F.record(F.always('key'), F.always('val'))
      local random = barrel_random({ 0.5 }) -- ~5 entries
      local result = fa:gen(random)
      assert.same('val', result['key'])
    end)

    it('respects count param', function()
      local i = 0
      local key_fake = F.Fake.new(function()
        i = i + 1
        return 'key' .. i
      end)
      local fa = F.record(key_fake, F.always(1), { count = 2 })
      local result = fa:run()
      local count = 0
      for _ in pairs(result) do
        count = count + 1
      end
      assert.same(2, count)
    end)
  end)

  describe('non_empty_array', function()
    it('generates array with at least one element', function()
      local fa = F.non_empty_array(F.always('x'))
      local random = barrel_random({ 0 }) -- min would be 0, but non_empty ensures 1+
      local result = fa:gen(random)
      assert.is_true(#result >= 1)
    end)

    it('respects max param', function()
      local fa = F.non_empty_array(F.always('x'), { max = 3 })
      local random = barrel_random({ 0.9999 })
      local result = fa:gen(random)
      assert.is_true(#result <= 3)
    end)
  end)

  describe('not_', function()
    it('retries until value does not match reject predicate', function()
      local calls = 0
      local values = { 1, 2, 3, 10 }
      local fa = F.Fake.new(function()
        calls = calls + 1
        return values[calls]
      end)
      local result = F.not_(fa, function(n)
        return n < 10
      end):run()
      assert.same(10, result)
    end)

    it('errors when max attempts exceeded', function()
      local fa = F.always(5)
      local ok, err = pcall(function()
        F.not_(fa, function()
          return true
        end):run()
      end)
      assert.is_false(ok)
      assert.is_truthy(err:match('max attempts exceeded'))
    end)
  end)

  describe('string_int', function()
    it('returns integer as string', function()
      local fa = F.string_int
      local random = fixed_random(0.5)
      local result = fa:gen(random)
      assert.is_string(result)
      assert.is_true(tonumber(result) ~= nil)
    end)
  end)

  describe('uuid', function()
    it('returns string matching uuid pattern', function()
      local fa = F.uuid
      local result = fa:run()
      assert.is_string(result)
      assert.same(36, #result)
      assert.is_truthy(result:match('^%x+%-%x+%-%x+%-%x+%-%x+$'))
    end)
  end)

  describe('uppercase_letter', function()
    it('returns single uppercase letter', function()
      local fa = F.uppercase_letter
      local result = fa:run()
      assert.same(1, #result)
      assert.is_truthy(result:match('^[A-Z]$'))
    end)
  end)

  describe('lowercase_letter', function()
    it('returns single lowercase letter', function()
      local fa = F.lowercase_letter
      local result = fa:run()
      assert.same(1, #result)
      assert.is_truthy(result:match('^[a-z]$'))
    end)
  end)

  describe('word', function()
    it('returns lowercase word', function()
      local fa = F.word
      local result = fa:run()
      assert.is_string(result)
      assert.is_true(#result >= 1)
      assert.is_truthy(result:match('^[a-z]+$'))
    end)
  end)

  describe('string', function()
    it('returns string with letters and digits', function()
      local fa = F.string
      local result = fa:run()
      assert.is_string(result)
      assert.is_true(#result >= 1)
    end)
  end)

  describe('factory', function()
    it('returns function that generates from fake', function()
      local fake = F.struct({
        name = F.always('test'),
        value = F.always(42),
      })
      local make = F.factory(fake, function(gen, overrides)
        return vim.tbl_extend('force', gen, overrides)
      end)
      local result = make()
      assert.same({ name = 'test', value = 42 }, result)
    end)

    it('applies overrides via merge function', function()
      local fake = F.struct({
        name = F.always('default'),
        enabled = F.always(true),
      })
      local make = F.factory(fake, function(gen, overrides)
        return vim.tbl_extend('force', gen, overrides)
      end)
      local result = make({ name = 'overridden' })
      assert.same('overridden', result.name)
      assert.same(true, result.enabled)
    end)

    it('returns generated value when no overrides', function()
      local fake = F.struct({ id = F.always('abc') })
      local make = F.factory(fake, function(gen, overrides)
        return vim.tbl_extend('force', gen, overrides)
      end)
      local result = make()
      assert.same({ id = 'abc' }, result)
    end)

    it('supports custom merge for nested objects', function()
      local fake = F.struct({
        outer = F.always('outer'),
        nested = F.struct({
          a = F.always(1),
          b = F.always(2),
        }),
      })
      local make = F.factory(fake, function(gen, overrides)
        local result = vim.tbl_extend('force', gen, overrides)
        if overrides.nested then
          result.nested = vim.tbl_extend('force', gen.nested, overrides.nested)
        end
        return result
      end)
      local result = make({ nested = { a = 99 } })
      assert.same(99, result.nested.a)
      assert.same(2, result.nested.b)
    end)
  end)

  describe('validation errors', function()
    it('Fake.new errors on nil', function()
      local ok, err = pcall(function()
        F.Fake.new(nil)
      end)
      assert.is_false(ok)
      assert.is_truthy(err:match('expected function'))
    end)

    it('Fake.new errors on string', function()
      local ok, err = pcall(function()
        F.Fake.new('not a function')
      end)
      assert.is_false(ok)
      assert.is_truthy(err:match('expected function'))
    end)

    it('int_within_range errors when min > max', function()
      local ok, err = pcall(function()
        F.int_within_range(10, 5)
      end)
      assert.is_false(ok)
      assert.is_truthy(err:match('min.*>.*max'))
    end)

    it('int_within_range errors on non-number', function()
      local ok, err = pcall(function()
        F.int_within_range('a', 5)
      end)
      assert.is_false(ok)
      assert.is_truthy(err:match('must be numbers'))
    end)

    it('pick errors on empty array', function()
      local ok, err = pcall(function()
        F.pick({})
      end)
      assert.is_false(ok)
      assert.is_truthy(err:match('non%-empty array'))
    end)

    it('pick errors on non-table', function()
      local ok, err = pcall(function()
        F.pick('not an array')
      end)
      assert.is_false(ok)
      assert.is_truthy(err:match('non%-empty array'))
    end)
  end)
end)
