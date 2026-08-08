---@class JSONParser
---@field private skip_non_json boolean
local JSONParser = {}
JSONParser.__index = JSONParser

---Constructor for JSONParser
---@param opts? {skip_non_json?: boolean}
---@return JSONParser
function JSONParser.new(opts)
  opts = opts or {}
  return setmetatable({
    skip_non_json = opts.skip_non_json ~= false, -- default true
  }, JSONParser)
end

---Parse a single line of text as JSON
---@param line string
---@return table|nil parsed JSON object or nil if not JSON/empty
---@return string|nil error Error message if parse failed
function JSONParser:parse_line(line)
  -- Skip empty lines
  if line:match("^%s*$") then
    return nil, nil
  end

  -- Skip obvious non-JSON (doesn't start with { or [)
  if self.skip_non_json and not line:match("^%s*[%[{]") then
    return nil, nil
  end

  -- Try to parse
  local ok, result = pcall(vim.json.decode, line)
  if ok then
    return result, nil
  else
    -- Return error only if it looks like it should be JSON
    if line:match("^%s*[%[{]") then
      return nil, "JSON parse error: " .. tostring(result)
    end
    return nil, nil
  end
end

---Parse multiple lines of text as JSON
---@param lines string[]
---@return table[] parsed Array of successfully parsed JSON objects
---@return table[] errors Array of {line: string, error: string}
function JSONParser:parse_lines(lines)
  local parsed = {}
  local errors = {}

  for _, line in ipairs(lines) do
    local data, err = self:parse_line(line)
    if data then
      table.insert(parsed, data)
    elseif err then
      table.insert(errors, { line = line, error = err })
    end
    -- nil data and nil error means skip (non-JSON)
  end

  return parsed, errors
end

return JSONParser
