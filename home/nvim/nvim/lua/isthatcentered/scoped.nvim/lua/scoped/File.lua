---@class File
---@field absolute_path string
local File = {}
File.__index = File

---@private
---@param params {  absolute_path: string}
---@return File
function File.new(params)
  return setmetatable({
    absolute_path = params.absolute_path,
  }, File)
end

---@param params { absolute_path: string}
---@return File?
function File.from_absolute_path_safe(params)
  local filetype = vim.fn.getftype(params.absolute_path)

  if filetype ~= "file" then
    return nil
  end

  return File.new({
    absolute_path = params.absolute_path,
  })
end

---@param params { absolute_path: string}
---@return File
function File.from_absolute_path(params)
  local filetype = vim.fn.getftype(params.absolute_path)

  if filetype ~= "file" then
    error('No actual file at given path: "' .. params.absolute_path .. '"')
  end

  --- TODO: validate path
  return File.new({
    absolute_path = params.absolute_path,
  })
end

local i = 1
---@return File
function File.random()
  local chars = "ABCDEFG"
  local id = chars.sub(chars, i, i)

  local file = File.new({
    absolute_path = "file/path/" .. id .. ".extension",
  })

  i = i + 1

  return file
end

---@param file File
---@return boolean
function File:eq(file)
  return self.absolute_path == file.absolute_path
end


return File
