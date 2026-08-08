---@class ValidatePathStrategy
---@field validate fun(value: string): string|nil

local M = {}

M.FileExistsPathValidationStrategy = {
  validate = function(path)
    if vim.fn.getftype(path) ~= "file" then
      return "Path is not a valid file"
    end
    return nil
  end
}

return M