local M = {}

---Pads string at the end to reach target length
---@param str string
---@param len number
---@param char? string defaults to space
---@return string
function M.pad_end(str, len, char)
  char = char or ' '
  return str .. string.rep(char, len - #str)
end

---Pads string at the start to reach target length
---@param str string
---@param len number
---@param char? string defaults to space
---@return string
function M.pad_start(str, len, char)
  char = char or ' '
  return string.rep(char, len - #str) .. str
end

---Splits a string into chunks of specified length
---@param str string
---@param length number
---@return string[]
function M.split(str, length)
  if str == '' then
    return {}
  end

  local result = {}
  for i = 1, #str, length do
    table.insert(result, str:sub(i, i + length - 1))
  end
  return result
end

---Removes leading and trailing whitespace from string
---@param str string
---@return string
function M.trim(str)
  return str:match('^%s*(.-)%s*$')
end

---Crops string to specified length
---@param str string
---@param len number
---@return string
function M.crop(str, len)
  if #str <= len then
    return str
  end
  return str:sub(1, len)
end

return M
