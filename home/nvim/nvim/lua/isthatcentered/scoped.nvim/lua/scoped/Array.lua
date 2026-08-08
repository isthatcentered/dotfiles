local M = {}

---@generic A
---@param predicate fun(a:A): boolean
---@param array A[]
---@return A[]
function M.filter(predicate, array)
  local matches = {}
  for _, item in pairs(array) do
    if predicate(item) then
      table.insert(matches, item)
    end
  end

  return matches
end

---@generic A
---@param array A?[]
---@return A[]
function M.without_nils(array)
  local matches = {}
  for _, item in pairs(array) do
    if item ~= nil then
      table.insert(matches, item)
    end
  end

  return matches
end

---@generic A
---@param predicate fun(a:A): boolean
---@param array A[]
---@return A?
function M.first(predicate, array)
  for _, item in pairs(array) do
    if predicate(item) then
      return item
    end
  end

  return nil
end

---@generic A
---@param predicate fun(a:A): boolean
---@param array A[]
---@return boolean
function M.some(predicate, array)
  for _, item in pairs(array) do
    if predicate(item) then
      return true
    end
  end

  return false
end

---@generic A
---@param predicate fun(a:A): boolean
---@param array A[]
---@return integer?
function M.index_of(predicate, array)
  for i, item in pairs(array) do
    if predicate(item) then
      return i
    end
  end

  return nil
end

---@generic A
---@param item A
---@param eq fun(a:A, b: A): boolean
---@param array A[]
---@return boolean
function M.is_duplicate(item, eq, array)
  local found = false
  for _, v in ipairs(array) do
    if eq(item, v) then
      if found then
        return true
      end
      found = true
    end
  end
  return false
end

---@generic A, B
---@param fun fun(a:A, i:integer): B
---@param array A[]
---@return B[]
function M.map(fun, array)
  local result = {}
  for i, v in ipairs(array) do
    result[i] = fun(v, i)
  end
  return result
end

return M
