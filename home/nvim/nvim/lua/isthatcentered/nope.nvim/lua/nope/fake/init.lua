---@class Fake<T>
---@field _gen fun(random: fun(): number): T
local Fake = {}
Fake.__index = Fake

---@generic T
---@param gen fun(random: fun(): number): T
---@return Fake<T>
function Fake.new(gen)
  if type(gen) ~= 'function' then
    error(string.format('Fake.new: expected function, got %s', type(gen)))
  end
  return setmetatable({ _gen = gen }, Fake)
end

---@generic T
---@param self Fake<T>
---@param random fun(): number
---@return T
function Fake:gen(random)
  return self._gen(random)
end

---@generic T
---@param self Fake<T>
---@return T
function Fake:run()
  return self:gen(math.random)
end

---@generic T, U
---@param self Fake<T>
---@param f fun(a: T): U
---@return Fake<U>
function Fake:map(f)
  local self_gen = self._gen
  return Fake.new(function(random)
    return f(self_gen(random))
  end)
end

---@generic T, U
---@param self Fake<T>
---@param f fun(a: T): Fake<U>
---@return Fake<U>
function Fake:chain(f)
  local self_gen = self._gen
  return Fake.new(function(random)
    local a = self_gen(random)
    return f(a):gen(random)
  end)
end

---@generic T, U
---@param self Fake<T>
---@param fb Fake<U>
---@return Fake<{ [1]: T, [2]: U }>
function Fake:zip(fb)
  local self_gen = self._gen
  return Fake.new(function(random)
    local a = self_gen(random)
    local b = fb:gen(random)
    return { a, b }
  end)
end

---@generic T, U
---@param self Fake<T>
---@param fb Fake<U>
---@return Fake<T|U>
function Fake:or_else(fb)
  local self_gen = self._gen
  return Fake.new(function(random)
    if random() < 0.5 then
      return self_gen(random)
    else
      return fb:gen(random)
    end
  end)
end

---@generic T
---@param self Fake<T>
---@return Fake<T?>
function Fake:nullable()
  local self_gen = self._gen
  return Fake.new(function(random)
    if random() < 0.5 then
      return nil
    else
      return self_gen(random)
    end
  end)
end

local M = {}

-- Expose Fake.new for advanced usage
M.Fake = Fake

---@generic T
---@param a T
---@return Fake<T>
function M.always(a)
  return Fake.new(function()
    return a
  end)
end

---@param min integer
---@param max integer
---@return Fake<integer>
function M.int_within_range(min, max)
  if type(min) ~= 'number' or type(max) ~= 'number' then
    error('int_within_range: min and max must be numbers')
  end
  if min > max then
    error(string.format('int_within_range: min (%d) > max (%d)', min, max))
  end
  return Fake.new(function(random)
    return math.floor(min + random() * (max - min + 1))
  end)
end

---@type Fake<integer>
M.int = M.int_within_range(0, 1e9)

---@type Fake<boolean>
M.boolean = Fake.new(function(random)
  return random() >= 0.5
end)

---@generic T
---@param array T[]
---@return Fake<T>
function M.pick(array)
  if type(array) ~= 'table' or #array == 0 then
    error('pick: expected non-empty array')
  end
  return Fake.new(function(random)
    local index = math.floor(random() * #array) + 1
    return array[index]
  end)
end

---@param ... Fake<any>
---@return Fake<any[]>
function M.sequence(...)
  local fakes = { ... }
  return Fake.new(function(random)
    local result = {}
    for i, fa in ipairs(fakes) do
      result[i] = fa:gen(random)
    end
    return result
  end)
end

---@param record table<string, Fake<any>>
---@return Fake<table>
function M.struct(record)
  return Fake.new(function(random)
    local result = {}
    for key, fa in pairs(record) do
      result[key] = fa:gen(random)
    end
    return result
  end)
end

---@generic T
---@param fa Fake<T>
---@param n integer
---@return Fake<T[]>
function M.array_n(fa, n)
  return Fake.new(function(random)
    local result = {}
    for i = 1, n do
      result[i] = fa:gen(random)
    end
    return result
  end)
end

---@generic T
---@param fa Fake<T>
---@param params? { min?: integer, max?: integer }
---@return Fake<T[]>
function M.array(fa, params)
  local min = params and params.min or 0
  local max = params and params.max or 10
  return M.int_within_range(min, max):chain(function(n)
    return M.array_n(fa, n)
  end)
end

---@generic K, V
---@param key_fake Fake<K>
---@param value_fake Fake<V>
---@param params? { count?: integer }
---@return Fake<table<K, V>>
function M.record(key_fake, value_fake, params)
  local count = params and params.count or 5
  return Fake.new(function(random)
    local result = {}
    for _ = 1, count do
      local k = key_fake:gen(random)
      local v = value_fake:gen(random)
      result[k] = v
    end
    return result
  end)
end

---@generic T
---@param fa Fake<T>
---@param params? { max?: integer }
---@return Fake<T[]>
function M.non_empty_array(fa, params)
  local max = params and params.max or 10
  return M.int_within_range(1, max):chain(function(n)
    return M.array_n(fa, n)
  end)
end

---@generic T
---@param fa Fake<T>
---@param reject fun(a: T): boolean
---@return Fake<T>
function M.not_(fa, reject)
  return Fake.new(function(random)
    local max_attempts = 1000
    for _ = 1, max_attempts do
      local value = fa:gen(random)
      if not reject(value) then
        return value
      end
    end
    error('not_: max attempts exceeded')
  end)
end

-- String constructors

---@type Fake<string>
M.string_int = M.int:map(function(n)
  return tostring(n)
end)

local hex_chars = '0123456789abcdef'

---@type Fake<string>
M.uuid = Fake.new(function(random)
  local parts = {}
  local lengths = { 8, 4, 4, 4, 12 }
  for _, len in ipairs(lengths) do
    local chars = {}
    for _ = 1, len do
      local idx = math.floor(random() * 16) + 1
      table.insert(chars, hex_chars:sub(idx, idx))
    end
    table.insert(parts, table.concat(chars))
  end
  return table.concat(parts, '-')
end)

local uppercase_letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local lowercase_letters = 'abcdefghijklmnopqrstuvwxyz'

---@type Fake<string>
M.uppercase_letter = Fake.new(function(random)
  local idx = math.floor(random() * 26) + 1
  return uppercase_letters:sub(idx, idx)
end)

---@type Fake<string>
M.lowercase_letter = Fake.new(function(random)
  local idx = math.floor(random() * 26) + 1
  return lowercase_letters:sub(idx, idx)
end)

---@type Fake<string>
M.word = M.int_within_range(3, 10):chain(function(len)
  return M.array_n(M.lowercase_letter, len):map(function(chars)
    return table.concat(chars)
  end)
end)

local alphanumeric = lowercase_letters .. uppercase_letters .. '0123456789'

---@type Fake<string>
M.string = M.int_within_range(5, 20):chain(function(len)
  return Fake.new(function(random)
    local chars = {}
    for _ = 1, len do
      local idx = math.floor(random() * #alphanumeric) + 1
      table.insert(chars, alphanumeric:sub(idx, idx))
    end
    return table.concat(chars)
  end)
end)

---@generic T
---@param fake Fake<T>
---@param merge fun(generated: T, overrides: T): T
---@return fun(overrides?: T): T
function M.factory(fake, merge)
  return function(overrides)
    local generated = fake:run()
    if overrides then
      return merge(generated, overrides)
    end
    return generated
  end
end

return M
