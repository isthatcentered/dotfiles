local Array = require("scoped.Array")
local EventEmitter = require("scoped.EventEmitter")

---@class Registry.List
---@field name string
---@field files string[] Relative paths
---@field last_opened string? Relative path of last opened file

---@class Registry
---@field lists Registry.List[]
---@field window_bindings table<integer, string> window_id -> list_name
---@field id string
---@field private emitter EventEmitter
local M = {}
M.__index = M

---@param id string
---@return Registry
function M.new(id)
  return setmetatable({
    lists = {},
    window_bindings = {},
    id = id,
    emitter = EventEmitter.new(),
  }, M)
end

---@param callback fun(event: Event): nil
---@return Unsubscribe
function M:listen(callback)
  return self.emitter:listen(callback)
end

---@param list_name string
---@return boolean -- true if created, false if name already exists or invalid
function M:create_list(list_name)
  if not list_name or list_name == "" then
    return false
  end

  local exists = Array.some(function(list)
    ---@cast list Registry.List
    return list.name == list_name
  end, self.lists)

  if exists then
    return false
  end

  table.insert(self.lists, {
    name = list_name,
    files = {},
    last_opened = nil,
  })

  self.emitter:emit({ kind = "list_created", payload = { list_name = list_name } })
  return true
end

---@param list_name string
---@return boolean -- true if removed, false if not found
function M:remove_list(list_name)
  local index = Array.index_of(function(list)
    ---@cast list Registry.List
    return list.name == list_name
  end, self.lists)

  if not index then
    return false
  end

  table.remove(self.lists, index)

  -- Remove any window bindings to this list
  for window_id, bound_name in pairs(self.window_bindings) do
    if bound_name == list_name then
      self.window_bindings[window_id] = nil
    end
  end

  self.emitter:emit({ kind = "list_removed", payload = { list_name = list_name } })
  return true
end

---@param list_name string
---@param file_path string
---@return boolean -- true if added, false if list missing or already present
function M:add_file_to_list(list_name, file_path)
  if not file_path or file_path == "" then
    return false
  end

  local list = self:_get_list_by_name(list_name)
  if not list then
    return false
  end

  -- Normalize path to relative
  local rel_path = vim.fn.fnamemodify(file_path, ':.')

  -- Check if already present
  if Array.some(function(f) return f == rel_path end, list.files) then
    return false
  end

  table.insert(list.files, rel_path)
  self.emitter:emit({ kind = "file_added", payload = { list_name = list_name, file_path = rel_path } })
  return true
end

---@param list_name string
---@param file_path string
---@return boolean -- true if removed, false if list missing or file not in list
function M:remove_file_from_list(list_name, file_path)
  local list = self:_get_list_by_name(list_name)
  if not list then
    return false
  end

  -- Normalize path
  local rel_path = vim.fn.fnamemodify(file_path, ':.')

  local index = Array.index_of(function(f) return f == rel_path end, list.files)
  if not index then
    return false
  end

  table.remove(list.files, index)

  -- Clear last_opened if it was this file
  if list.last_opened == rel_path then
    list.last_opened = nil
  end

  self.emitter:emit({ kind = "file_removed", payload = { list_name = list_name, file_path = rel_path } })
  return true
end

---@param file_path string
function M:file_opened(file_path)
  local rel_path = vim.fn.fnamemodify(file_path, ':.')

  for _, list in ipairs(self.lists) do
    if Array.some(function(f) return f == rel_path end, list.files) then
      list.last_opened = rel_path
    end
  end
end

---@param path string -- relative path
---@param window_id integer
function M:file_opened_in_window(path, window_id)
  local list_name = self:get_bound_list(window_id)
  if not list_name then return end

  local list = self:_get_list_by_name(list_name)
  if not list then return end

  if Array.some(function(f) return f == path end, list.files) then
    list.last_opened = path
  end
end

---@param list_name string
---@return string? -- relative file path or nil if list empty or missing
function M:next_file_in_list(list_name)
  local list = self:_get_list_by_name(list_name)
  if not list or #list.files == 0 then
    return nil
  end

  local current_index = list.last_opened and Array.index_of(function(f) return f == list.last_opened end, list.files) or 0
  local next_index = current_index + 1
  if next_index > #list.files then
    next_index = 1
  end

  local next_file = list.files[next_index]
  list.last_opened = next_file
  return next_file
end

---@param list_name string
---@return string? -- relative file path or nil if list empty or missing
function M:previous_file_in_list(list_name)
  local list = self:_get_list_by_name(list_name)
  if not list or #list.files == 0 then
    return nil
  end

  local current_index = list.last_opened and Array.index_of(function(f) return f == list.last_opened end, list.files) or (#list.files + 1)
  local prev_index = current_index - 1
  if prev_index < 1 then
    prev_index = #list.files
  end

   local prev_file = list.files[prev_index]
   list.last_opened = prev_file
   return prev_file
end

---@param window_id integer
---@return string? -- relative file path or nil
function M:next_file_in_window(window_id)
  local list_name = self:get_bound_list(window_id)
  if not list_name then return nil end
  return self:next_file_in_list(list_name)
end

---@param window_id integer
---@return string? -- relative file path or nil
function M:previous_file_in_window(window_id)
  local list_name = self:get_bound_list(window_id)
  if not list_name then return nil end
  return self:previous_file_in_list(list_name)
end

---@param lists {name: string, files: string[]}[]
function M:set_lists(lists)
  local new_lists = {}
  local name_count = {} -- name -> count

  for _, list_data in ipairs(lists) do
    local name = list_data.name
    if name and name ~= "" then
      -- Handle duplicates by appending _new
      while name_count[name] do
        name = name .. "_new"
      end
      name_count[name] = (name_count[name] or 0) + 1

      local files = {}
      local seen = {}
      for _, file in ipairs(list_data.files) do
        if file and file ~= "" then
          local rel_path = vim.fn.fnamemodify(file, ':.')
          if not seen[rel_path] then
            seen[rel_path] = true
            table.insert(files, rel_path)
          end
        end
      end

      table.insert(new_lists, {
        name = name,
        files = files,
        last_opened = nil,
      })
    end
  end

  -- Preserve last_opened from old lists by name
  local old_by_name = {}
  for _, old_list in ipairs(self.lists) do
    old_by_name[old_list.name] = old_list.last_opened
  end

  for _, new_list in ipairs(new_lists) do
    local old_last = old_by_name[new_list.name]
    if old_last and Array.some(function(f) return f == old_last end, new_list.files) then
      new_list.last_opened = old_last
    end
  end

  self.lists = new_lists

  -- Clean up window bindings for non-existent lists
  for window_id, bound_name in pairs(self.window_bindings) do
    local exists = Array.some(function(list)
      ---@cast list Registry.List
      return list.name == bound_name
    end, self.lists)
    if not exists then
      self.window_bindings[window_id] = nil
    end
  end

  self.emitter:emit({ kind = "lists_changed", payload = { lists = self.lists } })
end

---@param list_name string
---@param window_id integer
---@return boolean -- true if bound, false if list missing or invalid window
function M:bind_list_to_window(list_name, window_id)
  if not vim.api.nvim_win_is_valid(window_id) then
    return false
  end

  local list = self:_get_list_by_name(list_name)
  if not list then
    return false
  end

  self.window_bindings[window_id] = list_name
  self.emitter:emit({ kind = "list_bound", payload = { list_name = list_name, window_id = window_id } })
  return true
end

---@param list_name string
---@param window_id integer
---@return boolean -- true if unbound, false if not bound
function M:unbind_list_from_window(list_name, window_id)
  if self.window_bindings[window_id] == list_name then
    self.window_bindings[window_id] = nil
    self.emitter:emit({ kind = "list_unbound", payload = { list_name = list_name, window_id = window_id } })
    return true
  end
  return false
end

---@param window_id integer
---@return string? -- list_name or nil if not bound or invalid window
function M:get_bound_list(window_id)
  if not vim.api.nvim_win_is_valid(window_id) then
    return nil
  end
  return self.window_bindings[window_id]
end

---@param window_id integer
---@return boolean
function M:has_bound_list(window_id)
  return self:get_bound_list(window_id) ~= nil
end

---@private
---@param list_name string
---@return Registry.List?
function M:_get_list_by_name(list_name)
  return Array.first(function(list)
    ---@cast list Registry.List
    return list.name == list_name
  end, self.lists)
end

---@return table[]
function M:get_lists_for_editor()
  if not self.lists then
    return {}
  end
  return vim.tbl_map(function(list)
    return { name = list.name, files = list.files }
  end, self.lists)
end

---@return table
function M:serialize()
  -- Convert integer keys to strings for JSON compatibility
  local bindings = {}
  for win_id, list_name in pairs(self.window_bindings) do
    bindings[tostring(win_id)] = list_name
  end
  return {
    lists = self.lists,
    window_bindings = bindings,
  }
end

---@param data table
function M:deserialize(data)
  self.lists = data.lists or {}
  -- Convert string keys back to integers (JSON encodes integer keys as strings)
  self.window_bindings = {}
  if data.window_bindings then
    for win_id, list_name in pairs(data.window_bindings) do
      self.window_bindings[tonumber(win_id)] = list_name
    end
  end
  self.emitter:emit({ kind = "deserialized", payload = { lists = self.lists } })
end

---@param list_name string
---@param file_path string
---@return boolean
function M:is_file_bound_to_list(list_name, file_path)
  if not file_path or file_path == "" then
    return false
  end

  local list = self:_get_list_by_name(list_name)
  if not list then
    return false
  end

  local rel_path = vim.fn.fnamemodify(file_path, ':.')

  return Array.some(function(f) return f == rel_path end, list.files)
end

return M
