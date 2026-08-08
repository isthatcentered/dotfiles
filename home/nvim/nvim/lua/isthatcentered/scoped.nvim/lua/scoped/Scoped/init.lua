local Array = require("scoped.Array")
local ListsEditor = require("scoped.ListsEditor")
local ValidatePathStrategy = require("scoped.ValidatePathStrategy")
local Registry = require("scoped.Registry")
local Persistence = require("scoped.Persistence")

---@class Scoped
---@field editor ListsEditor
---@field registry Registry
---@field validate_path_strategy ValidatePathStrategy
---@field editor_opened boolean
local M = {}
M.__index = M

---@return Scoped
function M.new()
  local validate_path_strategy = ValidatePathStrategy.FileExistsPathValidationStrategy
  local registry = Registry.new(vim.fn.sha256(vim.loop.cwd()))
  local persistence = Persistence.new({ path = vim.fs.joinpath(vim.fn.stdpath("data"), "scoped") })
  local loaded_data = persistence:load(registry.id)
  if loaded_data then
    registry:deserialize(loaded_data)
  end
  local editor

  registry:listen(function()
    persistence:save(registry)
  end)

  local function on_open_file(list_name, file_path)
    if not file_path then
      editor:close()
      local window_id = vim.api.nvim_get_current_win()
      assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
      if not registry:bind_list_to_window(list_name, window_id) then
        error("List '" .. list_name .. "' does not exist")
      end
    else
      local window_id = vim.api.nvim_get_current_win()
      assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
      local full_path = vim.fn.fnamemodify(file_path, ":p")
      local uri = vim.uri_from_fname(full_path)
      local buf_id = vim.uri_to_bufnr(uri)
      vim.api.nvim_win_set_buf(window_id, buf_id)
    end
  end

  local function on_change_editor(lists)
    registry:set_lists(lists)
  end

  local function get_snapshot()
    local origin_win = vim.api.nvim_get_current_win()

    return {
      lists = registry:get_lists_for_editor() or {},
      active_list = registry:get_bound_list(origin_win),
      active_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(origin_win)), ":."),
    }
  end

  editor = ListsEditor.new(validate_path_strategy, on_open_file, on_change_editor, get_snapshot)

  local scoped_instance = {
    registry = registry,
    editor = editor,
    validate_path_strategy = validate_path_strategy,
    persistence = persistence,
  }

  -- Register autocommand to track file opens in windows
  local augroup = vim.api.nvim_create_augroup("Scoped", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      local window_id = vim.api.nvim_get_current_win()
      local buf_id = vim.api.nvim_win_get_buf(window_id)
      local file_path = vim.api.nvim_buf_get_name(buf_id)
      if file_path and file_path ~= "" then
        local rel_path = vim.fn.fnamemodify(file_path, ":.")
        if scoped_instance.validate_path_strategy.validate(rel_path) then
          scoped_instance.registry:file_opened_in_window(rel_path, window_id)
        end
      end
    end,
  })

  return setmetatable(scoped_instance, M)
end

function M:toggle()
  self.editor:toggle()
end

---@param list_name string
function M:bind_current_window_to_list(list_name)
  if not list_name or list_name == "" then
    error("List name cannot be empty")
  end
  local window_id = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
  if not self.registry:bind_list_to_window(list_name, window_id) then
    error("List '" .. list_name .. "' does not exist")
  end

  -- Update last_opened if current buffer is a file in the list
  local current_file = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window_id))
  if current_file and current_file ~= "" then
    local rel_path = vim.fn.fnamemodify(current_file, ":.")
    if self.validate_path_strategy.validate(rel_path) then
      self.registry:file_opened_in_window(rel_path, window_id)
    end
  end
end

function M:unbind_current_list_from_window()
  local window_id = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
  local current_list = self.registry:get_bound_list(window_id)
  if current_list then
    self.registry:unbind_list_from_window(current_list, window_id)
  end
end

function M:add_current_file_to_current_list()
  local window_id = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
  local current_list = self.registry:get_bound_list(window_id)
  if not current_list then
    error("No current list bound to the window")
  end
  local current_file = vim.api.nvim_buf_get_name(0)
  if not current_file or current_file == "" then
    error("No current file in buffer")
  end
  local rel_path = vim.fn.fnamemodify(current_file, ":.")
  local validation_error = self.validate_path_strategy.validate(rel_path)
  if validation_error then
    error("Buffer is not a file buffer: " .. validation_error)
  end
  self.registry:add_file_to_list(current_list, rel_path)
end

function M:remove_current_file_from_current_list()
  local window_id = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
  local current_list = self.registry:get_bound_list(window_id)
  if not current_list then
    error("No current list bound to the window")
  end
  local current_file = vim.api.nvim_buf_get_name(0)
  if not current_file or current_file == "" then
    error("No current file in buffer")
  end
  local rel_path = vim.fn.fnamemodify(current_file, ":.")
  local validation_error = self.validate_path_strategy.validate(rel_path)
  if validation_error then
    error("Buffer is not a file buffer: " .. validation_error)
  end
  self.registry:remove_file_from_list(current_list, rel_path)
end

---@param name string
function M:create_list(name)
  if not name or name == "" then
    error("List name cannot be empty")
  end
  local success = self.registry:create_list(name)
  if not success then
    error("List already exists")
  end
end

---@private
---@param name string
---@return boolean
function M:_list_exists(name)
  return Array.some(function(list)
    return list.name == name
  end, self.registry.lists)
end

---@param base_name string
---@return string
function M:generate_scratch_name(base_name)
  if not base_name or vim.trim(base_name) == "" then
    base_name = "Scratch list"
  end
  if not self:_list_exists(base_name) then
    return base_name
  end
  local i = 1
  while true do
    local candidate = string.format("%s_%02d", base_name, i)
    if not self:_list_exists(candidate) then
      return candidate
    end
    i = i + 1
  end
end

---@param window_id integer
---@return boolean
function M:has_bound_list(window_id)
  if window_id == 0 then
    window_id = vim.api.nvim_get_current_win()
  end
  return self.registry:has_bound_list(window_id)
end

---@return boolean
function M:is_current_file_bound_to_current_list()
  local window_id = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(window_id) then
    return false
  end

  local list_name = self.registry:get_bound_list(window_id)
  if not list_name then
    return false
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  if not current_file or current_file == "" then
    return false
  end

  local rel_path = vim.fn.fnamemodify(current_file, ":.")

  return self.registry:is_file_bound_to_list(list_name, rel_path)
end

---@param window_id integer
---@return string?
function M:get_bound_list_name(window_id)
  if window_id == 0 then
    window_id = vim.api.nvim_get_current_win()
  end
  return self.registry:get_bound_list(window_id)
end

function M:next_in_current_window()
  local window_id = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
  local current_list = self.registry:get_bound_list(window_id)
  if not current_list then
    error("No bound list for the current window")
  end
  local file_path = self.registry:next_file_in_window(window_id)
  if file_path then
    local full_path = vim.fn.fnamemodify(file_path, ":p")
    local uri = vim.uri_from_fname(full_path)
    local buf_id = vim.uri_to_bufnr(uri)
    vim.api.nvim_win_set_buf(window_id, buf_id)
  end
end

function M:previous_in_current_window()
  local window_id = vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_is_valid(window_id), "Invalid current window")
  local current_list = self.registry:get_bound_list(window_id)
  if not current_list then
    error("No bound list for the current window")
  end
  local file_path = self.registry:previous_file_in_window(window_id)
  if file_path then
    local full_path = vim.fn.fnamemodify(file_path, ":p")
    local uri = vim.uri_from_fname(full_path)
    local buf_id = vim.uri_to_bufnr(uri)
    vim.api.nvim_win_set_buf(window_id, buf_id)
  end
end

return M
