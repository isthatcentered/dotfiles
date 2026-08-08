---@class FindFileStrategy
---@field find fun(self: FindFileStrategy, glob: string): string[]
local FindFileStrategy = {}

---Find files matching glob pattern
---@param glob string Glob pattern (e.g., "**/vitest*")
---@return string[] Array of matching file paths (relative), sorted
function FindFileStrategy:find(glob)
  return {}
end

---@class LocalProjectFileStrategy : FindFileStrategy
---@field cwd string Current working directory
local LocalProjectFileStrategy = {}
LocalProjectFileStrategy.__index = LocalProjectFileStrategy
setmetatable(LocalProjectFileStrategy, { __index = FindFileStrategy })

---Create new LocalProjectFileStrategy
---@param cwd string|nil Current working directory (defaults to vim.fn.getcwd())
---@return LocalProjectFileStrategy
function LocalProjectFileStrategy.new(cwd)
  local instance = setmetatable({}, LocalProjectFileStrategy)
  instance.cwd = cwd or vim.fn.getcwd()
  return instance
end

---Convert glob pattern to Lua pattern
---@param glob string Glob pattern (e.g., "**/vitest*")
---@return string Lua pattern
---@private
function LocalProjectFileStrategy:_glob_to_pattern(glob)
  local pattern = glob

  -- Convert glob wildcards to Lua patterns FIRST, before escaping
  -- Handle **/ specially - zero or more path segments
  -- Use unique placeholders that won't appear in filenames
  pattern = pattern:gsub("%*%*/", "___RECURSIVE___")
  -- Handle ** at end - matches anything
  pattern = pattern:gsub("%*%*", "___ANYCHAR___")

  -- Handle single * (match anything except /) BEFORE escaping
  pattern = pattern:gsub("%*", "___STAR___")

  -- Handle ? (match single character) BEFORE escaping
  pattern = pattern:gsub("%?", "___QUESTION___")

  -- Escape special Lua pattern characters
  pattern = pattern:gsub("([%.%+%-%^%$%(%)%%])", "%%%1")

  -- Now replace placeholders with actual Lua patterns
  pattern = pattern:gsub("___RECURSIVE___", ".*")
  pattern = pattern:gsub("___ANYCHAR___", ".*")
  pattern = pattern:gsub("___STAR___", "[^/]*")
  pattern = pattern:gsub("___QUESTION___", ".")

  return "^" .. pattern .. "$"
end

---Recursively scan directory for files
---@param dir string Directory to scan
---@param matches string[] Array to collect matches
---@param pattern string|nil Lua pattern to match against
---@param base_dir string Base directory for relative paths
---@private
function LocalProjectFileStrategy:_scan_recursive(dir, matches, pattern, base_dir)
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    return
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    -- Skip hidden files and directories (starting with .)
    if not name:match("^%.") then
      local path = dir .. "/" .. name
      local rel_path = path:sub(#base_dir + 2) -- Remove base_dir prefix and leading /

      if type == "directory" then
        -- Recursively scan subdirectories
        self:_scan_recursive(path, matches, pattern, base_dir)
      elseif type == "file" then
        -- Check if file matches pattern
        if pattern == nil or rel_path:match(pattern) then
          table.insert(matches, rel_path)
        end
      end
    end
  end
end

---Calculate path depth (number of / characters)
---@param path string File path
---@return number Depth count
---@private
function LocalProjectFileStrategy:_path_depth(path)
  local _, count = path:gsub("/", "")
  return count
end

---Sort files by depth (shallowest first), then alphabetically
---@param files string[] Array of file paths
---@return string[] Sorted array
---@private
function LocalProjectFileStrategy:_sort_files(files)
  table.sort(files, function(a, b)
    local depth_a = self:_path_depth(a)
    local depth_b = self:_path_depth(b)

    if depth_a ~= depth_b then
      return depth_a < depth_b -- Shallowest first
    else
      return a < b -- Alphabetically
    end
  end)

  return files
end

---Find files matching the glob pattern
---@param glob string Glob pattern or empty string for all files
---@return string[] Array of matching file paths (relative to cwd), sorted
function LocalProjectFileStrategy:find(glob)
  local matches = {}
  local pattern = nil

  if glob ~= nil and glob ~= "" then
    pattern = self:_glob_to_pattern(glob)
  end

  self:_scan_recursive(self.cwd, matches, pattern, self.cwd)
  self:_sort_files(matches)

  return matches
end

return {
  FindFileStrategy = FindFileStrategy,
  LocalProjectFileStrategy = LocalProjectFileStrategy,
}
