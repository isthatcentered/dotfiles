
local getCurrentDirectory = function ()
  -- See h: expand
  return vim.fn.expand("%:p:h")
end




---@class Event
---@field blah number
---@field indeed string


---@param event Event
function blah(event)
  vim.print(event.indeed)
end

-- TODO: display file icon
-- TODO: display current folder content 
local function createInputWindow() 
  local input_buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local height = 1
  local row = 2
  local col = math.floor((vim.o.columns - width) / 2)

  -- Input Window
  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_set_option(input_buf, "buftype", "prompt")
  vim.fn.prompt_setprompt(input_buf, "New file: ")
  vim.api.nvim_buf_set_option(input_buf, "filetype", "newfileprompt")
  vim.api.nvim_buf_set_option(input_buf, "completefunc", "v:lua.__new_file_complete")

vim.fn.prompt_setcallback(input_buf, function(input)
  vim.print("Input done!" .. math.random())
  vim.api.nvim_win_close(input_win, true)
  end)

  vim.cmd("startinsert")
end

local function create_input_win(base_dir)
  local input_buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.6)
  local height = 1
  local row = 2
  local col = math.floor((vim.o.columns - width) / 2)

  -- Input Window
  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  -- Initialize prompt and options
  vim.api.nvim_buf_set_option(input_buf, "buftype", "prompt")
  vim.fn.prompt_setprompt(input_buf, "New file: ")
  vim.api.nvim_buf_set_option(input_buf, "filetype", "newfileprompt")
  vim.api.nvim_buf_set_option(input_buf, "completefunc", "v:lua.__new_file_complete")

  -- Setup autocompletion (completion func defined below)
  local function update_preview(input)
    local full_path = vim.fn.fnamemodify(base_dir .. "/" .. input, ":p")
    local lines = {
      "Full path:",
      full_path,
      "",
      "Files in " .. base_dir .. ":",
    }
    vim.list_extend(lines, list_files(base_dir))
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
  end

  -- Hook into input changes
  local ns = vim.api.nvim_create_namespace("new_file_preview")
  vim.api.nvim_buf_attach(input_buf, false, {
    on_lines = function(_, _, _, _, _, _)
      local input = vim.trim(vim.fn.getline(1))
      update_preview(input)
    end,
  })

  -- Accept on <CR>
  vim.fn.prompt_setcallback(input_buf, function(input)
    if input == nil or input == "" then
      vim.api.nvim_win_close(input_win, true)
      vim.api.nvim_win_close(preview_win, true)
      return
    end
    local full_path = vim.fn.fnamemodify(base_dir .. "/" .. input, ":p")
    vim.api.nvim_command("edit " .. vim.fn.fnameescape(full_path))
    vim.api.nvim_win_close(input_win, true)
    vim.api.nvim_win_close(preview_win, true)
  end)

  vim.cmd("startinsert")
end

createInputWindow(getCurrentDirectory())
