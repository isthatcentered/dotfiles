-- This is a file to manually explore the plugin
vim.opt.rtp:append(vim.env.PWD)

local fresh = true
local function require_fresh(module)
  if fresh then
    package.loaded[module] = nil
    return require(module)
  end
  return require(module)
end

local ListsEditor = require_fresh("scoped.ListsEditor")
local ValidatePathStrategy = require_fresh("scoped.ValidatePathStrategy")
local Registry = require_fresh("scoped.Registry")
local Scoped = require_fresh("scoped.Scoped")

-- Create registry and populate with sample data
local registry = Registry.new()
registry:create_list("My Projects")
registry:add_file_to_list("My Projects", "scoped.nvim")
registry:add_file_to_list("My Projects", "my-awesome-app")
registry:create_list("Documentation")
registry:add_file_to_list("Documentation", "Neovim docs")
registry:create_list("Empty List")

local function on_close(final_lists)
  registry:set_lists(final_lists)
end

local function on_open(list_id, bookmark_id)
  print("Selected:")
  vim.print({
    "List ID:",
    list_id,
    "File:",
    bookmark_id or "nil (list header)",
  })
end

local editor = ListsEditor.new(ValidatePathStrategy.FileExistsPathValidationStrategy)

-- [PASS] Toggle the editor
-- [PASS] Bind a list to a window
-- [PASS] Add a file to the current list
-- [PASS] Add another file to the current list
-- [PASS] Open a file from the list
-- [PASS] Different lists with different files in windows
-- [FAIL] Adding the same file to multiple lists highlight the correct list file on open
-- [PASS] Go to prev
-- [PASS] Go to next
-- [PASS] Go to next/prev when current file is in the list and theoriticalyy next/prev in line
-- [PASS] Go to prev/next from a non listed file
-- [PASS] Remove a file from the current list
-- [PASS] Temp lists
-- [PASS] Persistence
-- [ ] Show a file as bound to the current list in status bar
-- [ ] Notifications
-- [ ] Handle invalid file paths
-- [ ] Have window height match lists height on startup. Also, the window is too wide
-- [ ] Add integration tests and start the cleanup (DDD + tests)
-- [ ] Change folding styles

-- Set up keymaps for manual testing
local scoped = Scoped.new()

vim.keymap.set("n", "<leader><leader>", function()
  scoped:toggle()
end, { desc = "Open ListsEditor" })

vim.keymap.set("n", "<C-j>", function()

  scoped:next_in_current_window()
end, { desc = "Go to next file in lit" })

vim.keymap.set("n", "<C-k>", function()
  scoped:previous_in_current_window()
end, { desc = "Go to prev in current window" })

vim.keymap.set("n", "sfa", function()
  scoped:add_current_file_to_current_list()
end, { desc = "Add current file to current list" })

vim.keymap.set("n", "sfr", function()
  scoped:remove_current_file_from_current_list()
end, { desc = "Remove current file from current list" })

vim.keymap.set("n", "sff", function()
  if scoped:has_bound_list(vim.api.nvim_get_current_win()) then
    scoped:add_current_file_to_current_list()
    return
  end

  local list_name = scoped:generate_scratch_name("scratch_list")
  scoped:create_list(list_name)
  scoped:bind_current_window_to_list(list_name)
  scoped:add_current_file_to_current_list()
end, { desc = "Add the current file to the current list. If there is not current list, create one" })

vim.keymap.set("n", "slr", function()
  scoped:unbind_current_list_from_current_window()
end, { desc = "Unbind the list associated to the window" })

vim.keymap.set("n", "sa", function()
  scoped:add_current_file_to_current_list()
end, { desc = "Add current file to current list" })

-- Expose for manual testing
_G.ListsEditor = ListsEditor
_G.editor = editor
_G.Registry = Registry
_G.registry = registry
