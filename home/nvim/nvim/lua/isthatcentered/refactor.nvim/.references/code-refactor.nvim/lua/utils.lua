local M = {}

M.table_keys = function(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

M.filter_table = function(t, filterIter)
  local out = {}

  for k, v in pairs(t) do
    if filterIter(v, k, t) then
      out[k] = v
    end
  end

  return out
end

return M
