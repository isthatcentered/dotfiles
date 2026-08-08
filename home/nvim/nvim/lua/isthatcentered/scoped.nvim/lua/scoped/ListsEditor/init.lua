local ScratchWindow = require("scoped.ScratchWindow")
local CenteredToBufferPositionStrategy = require("scoped.ScratchWindow.CenteredToBufferPositionStrategy")

--TODO: the goal of the list editor is to display the lists and add the interactivity.
-- (folds, on_change, on_selected)
-- Turning the lines into a list and validating each line shoul be the responsibility of the controller/something else

---@class ListsEditor.PositionStrategy : ScratchWindow.PositionStrategy

---@class ListsEditor.List
---@field name string
---@field files string[]

---@class ListsEditor
---@field scratch_window ScratchWindow
---@field buffer_id integer?
---@field lists ListsEditor.List[]
---@field line_to_target table<integer, {list_id: string, file: string?}>
---@field validate_path_strategy ValidatePathStrategy
---@field on_open_file fun(list_id: string, file: string?)?
---@field on_change fun(lists: ListsEditor.List[])?
---@field get_snapshot fun(): {lists: ListsEditor.List[], active_list: string?, active_file: string?}
---@field validation_ns integer
local M = {}
M.__index = M

---@param validate_path_strategy ValidatePathStrategy
---@param on_open_file fun(list_id: string, file: string?)?
---@param on_change fun(lists: ListsEditor.List[])?
---@param get_snapshot fun(): {lists: ListsEditor.List[], active_list: string?, active_file: string?}
---@return ListsEditor
function M.new(validate_path_strategy, on_open_file, on_change, get_snapshot)
   return setmetatable({
     scratch_window = nil,
     buffer_id = nil,
     lists = nil,
     line_to_target = {},
     fold_ranges = {},
     line_to_fold_count = {},
     validate_path_strategy = validate_path_strategy,
     on_open_file = on_open_file,
     on_change = on_change,
     get_snapshot = get_snapshot,
     validation_ns = vim.api.nvim_create_namespace("ScopedListsValidation"),
     highlight_ns = vim.api.nvim_create_namespace("ScopedHighlight"),
   }, M)
end

---@return boolean -- true if opened, false if already open
function M:open()
  local snapshot = self.get_snapshot()

  -- Clear stale window_id if the window is no longer valid (e.g., after reset_editor)
  if
    self.scratch_window
    and self.scratch_window.window_id
    and not vim.api.nvim_win_is_valid(self.scratch_window.window_id)
  then
    self.scratch_window.window_id = nil
  end

  if self.scratch_window and self.scratch_window:is_opened() then
    return false
  end

  -- Initialize scratch window with custom position strategy
  self.scratch_window = ScratchWindow.new({
    position_strategy = self:_make_position_strategy(),
  })

  -- Create buffer and set options
  local buffer_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer_id })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffer_id })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buffer_id })
  vim.api.nvim_set_option_value("path", vim.fn.getcwd() .. "/**", { buf = buffer_id })

  -- Store buffer_id
  self.buffer_id = buffer_id

  -- Render lists into buffer lines
  self:_render_lists(buffer_id, snapshot.lists)
  self.lists = snapshot.lists

  -- Define highlight for invalid paths
  vim.api.nvim_set_hl(0, "ScopedInvalidListItem", { link = "DiagnosticVirtualTextError" })

  -- Validate paths
  self:_validate_paths()

  -- Set buffer-local keymaps
  vim.api.nvim_buf_set_keymap(buffer_id, "n", "<CR>", "", {
    callback = function()
      local line = vim.api.nvim_win_get_cursor(0)[1]
      local target = self.line_to_target[line]
      if target then
        self.on_open_file(target.list_id, target.file)
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(buffer_id, "n", "<Esc><Esc>", "", {
    callback = function()
      self:close()
    end,
  })

  -- Store state
  self.buffer_id = buffer_id

  -- Add autocmds for editing updates
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    buffer = buffer_id,
    callback = function()
      self:_on_buffer_change()
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = buffer_id,
    callback = function()
      vim.api.nvim_buf_clear_namespace(self.buffer_id, self.validation_ns, 0, -1)
    end,
  })

  -- Open the window
  local opened = self.scratch_window:open(buffer_id)
  if opened then
    -- Set folding options on the window
    vim.wo.foldmethod = "manual"
    vim.wo.foldlevel = 0
    vim.wo.foldtext = 'v:lua.require("scoped.ListsEditor").foldtext()'
    vim.api.nvim_set_option_value("number", false, { win = self.scratch_window.window_id })
    vim.api.nvim_set_option_value("relativenumber", false, { win = self.scratch_window.window_id })

    -- Apply manual folds
    for _, range in ipairs(self.fold_ranges) do
      vim.cmd(tostring(range.start) .. "," .. tostring(range["end"]) .. "fold")
    end

    -- Handle active_list and active_file
    local active_list_index = nil
    for i, list in ipairs(snapshot.lists) do
      if list.name == snapshot.active_list then
        active_list_index = i
        break
      end
    end

    local target_line = nil
    if active_list_index then
      -- Unfold the list if active_file is provided
      if snapshot.active_file then
        local range = self.fold_ranges[active_list_index]
        if range then
          vim.cmd(tostring(range.start) .. "foldopen")
        end
      end

      -- Find target line
      if snapshot.active_file then
        -- Find the file line
        for line, target in pairs(self.line_to_target) do
          if target.list_id == snapshot.active_list and target.file == snapshot.active_file then
            target_line = line
            break
          end
        end
      end
      if not target_line then
        -- Find the list header line
        for line, target in pairs(self.line_to_target) do
          if target.list_id == snapshot.active_list and target.file == nil then
            target_line = line
            break
          end
        end
      end
    end

     -- Set cursor to target line
     if target_line then
       vim.api.nvim_win_set_cursor(self.scratch_window.window_id, { target_line, 1 })
     end

     -- Apply highlight
     vim.api.nvim_buf_clear_namespace(self.buffer_id, self.highlight_ns, 0, -1)
     if target_line then
       vim.api.nvim_buf_set_extmark(self.buffer_id, self.highlight_ns, target_line - 1, 0, {
         line_hl_group = "Visual",
       })
     end

     -- Add autocmd to update highlight on BufEnter (active path change)
     vim.api.nvim_create_autocmd("BufEnter", {
       callback = function()
         if self.scratch_window and self.scratch_window:is_opened() and vim.api.nvim_get_current_buf() ~= self.buffer_id then
           -- Update highlight
           local snapshot = self.get_snapshot()
           local active_list_index = nil
           for i, list in ipairs(self.lists) do
             if list.name == snapshot.active_list then
               active_list_index = i
               break
             end
           end
           local target_line = nil
           if active_list_index then
             local file_in_list = false
             if snapshot.active_file then
               for _, file in ipairs(self.lists[active_list_index].files) do
                 if file == snapshot.active_file then
                   file_in_list = true
                   break
                 end
               end
               if file_in_list then
                 for line, target in pairs(self.line_to_target) do
                   if target.list_id == snapshot.active_list and target.file == snapshot.active_file then
                     target_line = line
                     break
                   end
                 end
               end
             end
             if not target_line then
               for line, target in pairs(self.line_to_target) do
                 if target.list_id == snapshot.active_list and target.file == nil then
                   target_line = line
                   break
                 end
               end
             end
           end
           vim.api.nvim_buf_clear_namespace(self.buffer_id, self.highlight_ns, 0, -1)
           if target_line then
             vim.api.nvim_buf_set_extmark(self.buffer_id, self.highlight_ns, target_line - 1, 0, {
               line_hl_group = "Visual",
             })
           end
         end
       end,
       group = vim.api.nvim_create_augroup("ScopedHighlightUpdate", { clear = true }),
     })
   end
   return opened
 end

---@private
---@return ListsEditor.List[]
function M:_parse_buffer()
  local lines = vim.api.nvim_buf_get_lines(self.buffer_id, 0, -1, false)
  local lists = {}
  local current_list = nil
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == "" then
      -- skip
    elseif trimmed:find("^%-") then
      -- file
      local path = vim.trim(trimmed:sub(2))
      if current_list then
        table.insert(current_list.files, path)
      end
    else
      -- list
      local name = vim.trim(line):gsub(" %(%d+%)$", "")
      current_list = { name = name, files = {} }
      table.insert(lists, current_list)
    end
  end
  return lists
end

---@private
---@param buffer_id integer
---@param lists ListsEditor.List[]
function M:_render_lists(buffer_id, lists)
  local lines = {}
  self.line_to_target = {}
  self.fold_ranges = {}
  self.line_to_fold_count = {}

  for _, list in ipairs(lists) do
    local list_start_line = #lines + 1
    -- Add list header line
    table.insert(lines, list.name .. " (" .. #list.files .. ")")
    self.line_to_target[#lines] = { list_id = list.name, file = nil }

    -- Add file lines with indentation
    for _, file in ipairs(list.files) do
      table.insert(lines, "  - " .. file)
      self.line_to_target[#lines] = { list_id = list.name, file = file }
    end

    local list_end_line = #lines
    -- Add fold for this list (even if empty)
    table.insert(self.fold_ranges, { start = list_start_line, ["end"] = list_end_line })
    self.line_to_fold_count[list_start_line] = #list.files

    -- Add blank line between lists (except after the last list)
    table.insert(lines, "")
  end

  -- Remove the last blank line
  if lines[#lines] == "" then
    table.remove(lines)
  end

  -- Set buffer lines
  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, lines)
end

---@private
---@return ListsEditor.PositionStrategy
function M._make_position_strategy()
  local base_strategy = CenteredToBufferPositionStrategy.new(80, 20, 1, 1)
  return {
    get_specs = function(origin_buffer_id, target_buffer)
      local specs = base_strategy.get_specs(origin_buffer_id, target_buffer)
      specs.title = "Lists"
      specs.title_pos = "center"
      return specs
    end,
  }
end

---@return string
function M.foldtext()
  local foldstart = vim.v.foldstart
  local line_text = vim.fn.getline(foldstart)
  return line_text
end

---@private
function M:_on_buffer_change()
  -- Save old state to preserve fold openness
  local old_lists = self.lists
  local old_fold_ranges = self.fold_ranges
  local unfolded_indices = {}
  for i, range in ipairs(old_fold_ranges) do
    if vim.fn.foldclosed(range.start) == -1 then
      table.insert(unfolded_indices, i)
    end
  end

  self.lists = self:_parse_buffer()

  if self.on_change then
    self.on_change(self.lists)
  end

  -- Re-render buffer lines with updated structure
  local lines = {}
  self.line_to_target = {}
  self.fold_ranges = {}
  self.line_to_fold_count = {}

  for _, list in ipairs(self.lists) do
    local list_start_line = #lines + 1
    -- Add list header line
    table.insert(lines, list.name .. " (" .. #list.files .. ")")
    self.line_to_target[#lines] = { list_id = list.name, file = nil }

    -- Add file lines with indentation
    for _, file in ipairs(list.files) do
      table.insert(lines, "  - " .. file)
      self.line_to_target[#lines] = { list_id = list.name, file = file }
    end

    local list_end_line = #lines
    -- Add fold for this list (even if empty)
    table.insert(self.fold_ranges, { start = list_start_line, ["end"] = list_end_line })
    self.line_to_fold_count[list_start_line] = #list.files

    -- Add blank line between lists (except after the last list)
    table.insert(lines, "")
  end

  -- Remove the last blank line
  if lines[#lines] == "" then
    table.remove(lines)
  end

  -- Set buffer lines
  vim.api.nvim_buf_set_lines(self.buffer_id, 0, -1, false, lines)

  -- Validate paths
  self:_validate_paths()

  -- Clear existing folds
  vim.cmd("normal! zE")

  -- Apply new folds
  for _, range in ipairs(self.fold_ranges) do
    vim.cmd(tostring(range.start) .. "," .. tostring(range["end"]) .. "fold")
  end

   -- Restore unfolded states by index
   for _, idx in ipairs(unfolded_indices) do
     local range = self.fold_ranges[idx]
     if range then
       vim.cmd(tostring(range.start) .. "foldopen")
     end
   end

   -- Reapply highlight
   local current_snapshot = self.get_snapshot()
   local active_list_index = nil
   for i, list in ipairs(self.lists) do
     if list.name == current_snapshot.active_list then
       active_list_index = i
       break
     end
   end
   local target_line = nil
   if active_list_index then
     -- Check if active_file is in the list
     local file_in_list = false
     if current_snapshot.active_file then
       for _, file in ipairs(self.lists[active_list_index].files) do
         if file == current_snapshot.active_file then
           file_in_list = true
           break
         end
       end
       -- If file is in list, highlight it; else, highlight list name
       if file_in_list then
         for line, target in pairs(self.line_to_target) do
           if target.list_id == current_snapshot.active_list and target.file == current_snapshot.active_file then
             target_line = line
             break
           end
         end
       end
     end
     if not target_line then
       -- Highlight list header (also for empty list)
       for line, target in pairs(self.line_to_target) do
         if target.list_id == current_snapshot.active_list and target.file == nil then
           target_line = line
           break
         end
       end
     end
   end
   vim.api.nvim_buf_clear_namespace(self.buffer_id, self.highlight_ns, 0, -1)
   if target_line then
     vim.api.nvim_buf_set_extmark(self.buffer_id, self.highlight_ns, target_line - 1, 0, {
       line_hl_group = "Visual",
     })
   end
 end

---@return ListsEditor.List[]
function M:get_lists()
  return self.lists
end

function M:close()
  if self.buffer_id and vim.api.nvim_buf_is_valid(self.buffer_id) then
    -- Parse final buffer content before clearing
    local final_lists = self:_parse_buffer()
    if self.on_change then
      self.on_change(final_lists)
    end
    vim.api.nvim_buf_clear_namespace(self.buffer_id, self.validation_ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(self.buffer_id, self.highlight_ns, 0, -1)
  end
  if self.scratch_window then
    self.scratch_window:close()
  end
  self.buffer_id = nil
  self.lists = nil
  self.line_to_target = {}
  self.fold_ranges = {}
  self.line_to_fold_count = {}
end

---@return boolean -- true if opened, false if closed
function M:toggle()
  -- Clear stale window_id if the window is no longer valid (e.g., after reset_editor)
  if
    self.scratch_window
    and self.scratch_window.window_id
    and not vim.api.nvim_win_is_valid(self.scratch_window.window_id)
  then
    self.scratch_window.window_id = nil
  end
  if self.scratch_window and self.scratch_window:is_opened() then
    self:close()
    return false -- closed
  else
    return self:open() -- opened
  end
end

---@private
function M:_validate_paths()
  vim.api.nvim_buf_clear_namespace(self.buffer_id, self.validation_ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(self.buffer_id, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:find("^  %- ") then
      local path = vim.trim(line:sub(4))
      local error = self.validate_path_strategy.validate(path)
      if error then
        vim.api.nvim_buf_set_extmark(self.buffer_id, self.validation_ns, i - 1, #line, {
          virt_text = { { error, "ScopedInvalidListItem" } },
          virt_text_pos = "eol",
        })
      end
    end
  end
end

return M
