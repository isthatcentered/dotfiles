local C = require("nope.ui2")
local NavigationPanel = require("nope.consumers.WindowConsumer.Navigation.ui.NavigationPanel")
local DetailsPanel = require("nope.consumers.WindowConsumer.Details.ui.DetailsPanel")
local DetailsService = require("nope.consumers.WindowConsumer.Details.state.DetailsService")

---@class WindowConsumer
---@field private service NavigationService
---@field private details_service DetailsService
---@field private tree_buffer number|nil
---@field private tree_window number|nil
---@field private details_buffer number|nil
---@field private details_window number|nil
---@field private unsubscribe fun()|nil
local WindowConsumer = {}
WindowConsumer.__index = WindowConsumer

---@param service NavigationService
---@return WindowConsumer
function WindowConsumer.new(service)
  local details_service = DetailsService.new()
  local self = setmetatable({
    service = service,
    details_service = details_service,
    tree_buffer = nil,
    tree_window = nil,
    details_buffer = nil,
    details_window = nil,
    unsubscribe = nil,
  }, WindowConsumer)
  return self
end

---@private
---@return number
function WindowConsumer:_create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "nope", { buf = buf })
  return buf
end

---@private
---@param state NavigationServiceState
function WindowConsumer:_render_tree(state)
  if not self.tree_buffer or not vim.api.nvim_buf_is_valid(self.tree_buffer) then
    return
  end

  local content = NavigationPanel.NavigationPanel({
    tabs = state.tabs,
    nodes = state.nodes,
    selected_id = state.selected_id,
    active_tab_key = state.active_tab_key,
    showing_help = state.showing_help,
    filter_active = state.filter_active,
    scope_filter_id = state.scope_filter_id,
    scope_breadcrumb = state.scope_breadcrumb,
  })

  local win = self.tree_window
  local width = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_width(win) or 40

  C.render(self.tree_buffer, content, {
    max_width = width,
    min_width = 0,
  })
end

---@private
function WindowConsumer:_render_details()
  if not self.details_buffer or not vim.api.nvim_buf_is_valid(self.details_buffer) then
    return
  end

  local state = self.details_service:get_state()
  local content = DetailsPanel.DetailsPanel(state.selected_node)

  local win = self.details_window
  local width = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_width(win) or 60

  C.render(self.details_buffer, content, {
    max_width = width,
    min_width = 0,
  })
end

---@private
---Jump to test file/line
function WindowConsumer:_goto_test()
  local state = self.service:get_state()
  local node = state.selected_node
  if not node or not node.file_path then
    return
  end

  local file_path = node.file_path
  local line = 1

  if node.type == "test" and node.node and node.node.location then
    line = node.node.location.line
  end

  -- Find a non-consumer window to open the file in
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= self.tree_window and win ~= self.details_window then
      vim.api.nvim_set_current_win(win)
      break
    end
  end

  vim.cmd(string.format("edit +%d %s", line, vim.fn.fnameescape(file_path)))
end

---@private
---@param direction "up"|"down"
function WindowConsumer:_scroll_details(direction)
  if not self.details_window or not vim.api.nvim_win_is_valid(self.details_window) then
    return
  end
  local scroll = vim.wo[self.details_window].scroll
  if scroll == 0 then
    scroll = math.floor(vim.api.nvim_win_get_height(self.details_window) / 2)
  end
  local key = direction == "down" and "<C-e>" or "<C-y>"
  local keys = vim.api.nvim_replace_termcodes(scroll .. key, true, false, true)
  vim.api.nvim_win_call(self.details_window, function()
    vim.api.nvim_feedkeys(keys, "nx", false)
  end)
end

---@private
function WindowConsumer:_setup_keymaps()
  local buf = self.tree_buffer
  if not buf then
    return
  end

  local opts = { buffer = buf, noremap = true, silent = true }

  -- Disable hjkl navigation
  for _, key in ipairs({ "h", "j", "k", "l" }) do
    vim.keymap.set("n", key, function() end, opts)
  end

  -- Navigation
  vim.keymap.set("n", "<C-n>", function()
    self.service:move_selection(1)
  end, opts)
  vim.keymap.set("n", "<C-p>", function()
    self.service:move_selection(-1)
  end, opts)

  -- Details scrolling
  vim.keymap.set("n", "<C-d>", function()
    self:_scroll_details("down")
  end, opts)
  vim.keymap.set("n", "<C-u>", function()
    self:_scroll_details("up")
  end, opts)

  -- Tab switching
  vim.keymap.set("n", "H", function()
    self.service:switch_tab(-1)
  end, opts)
  vim.keymap.set("n", "L", function()
    self.service:switch_tab(1)
  end, opts)
  vim.keymap.set("n", "[", function()
    self.service:switch_tab(-1)
  end, opts)
  vim.keymap.set("n", "]", function()
    self.service:switch_tab(1)
  end, opts)

  -- Number keys for direct tab switching
  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      self.service:switch_to_tab(i)
    end, opts)
  end

  -- Go to file
  vim.keymap.set("n", "gf", function()
    self:_goto_test()
  end, opts)

  -- Actions
  vim.keymap.set("n", "x", function()
    self.service:close_tab()
  end, opts)
  vim.keymap.set("n", "s", function()
    self.service:stop_run()
  end, opts)
  vim.keymap.set("n", "ff", function()
    self.service:toggle_failures_filter()
  end, opts)
  vim.keymap.set("n", "fc", function()
    self.service:clear_scope_filter()
  end, opts)
  vim.keymap.set("n", "<CR>", function()
    local state = self.service:get_state()
    if state.selected_id then
      self.service:toggle_scope_filter(state.selected_id)
    end
  end, opts)

  -- Help
  vim.keymap.set("n", "g?", function()
    self.service:toggle_help()
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    local state = self.service:get_state()
    if state.showing_help then
      self.service:toggle_help()
    end
  end, opts)

  -- Close
  vim.keymap.set("n", "q", function()
    self:close()
  end, opts)
end

---Open the buffer consumer windows
function WindowConsumer:open()
  if self.tree_window and vim.api.nvim_win_is_valid(self.tree_window) then
    return
  end

  -- Create buffers
  self.tree_buffer = self:_create_buffer()
  self.details_buffer = self:_create_buffer()

  -- Get current window dimensions
  local current_win = vim.api.nvim_get_current_win()
  local current_width = vim.api.nvim_win_get_width(current_win)
  local tree_width = math.max(30, math.floor(current_width / 3))

  -- Capture all window widths
  local win_widths = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    win_widths[win] = vim.api.nvim_win_get_width(win)
  end

  -- Create tree window (below)
  self.tree_window = vim.api.nvim_open_win(self.tree_buffer, true, {
    split = "below",
    win = current_win,
    height = 25,
  })
  vim.wo[self.tree_window].number = false
  vim.wo[self.tree_window].relativenumber = false
  vim.wo[self.tree_window].wrap = false
  vim.wo[self.tree_window].cursorline = true

  -- Create details window (right of tree)
  self.details_window = vim.api.nvim_open_win(self.details_buffer, false, {
    split = "right",
    win = self.tree_window,
  })
  vim.wo[self.details_window].number = false
  vim.wo[self.details_window].relativenumber = false
  vim.wo[self.details_window].wrap = true

  -- Restore original window widths
  for win, width in pairs(win_widths) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_width(win, width)
    end
  end
  vim.api.nvim_win_set_width(self.tree_window, tree_width)

  -- Setup keymaps
  self:_setup_keymaps()

  -- Setup autocmds for cleanup
  local GROUP = vim.api.nvim_create_augroup("WindowConsumer_" .. self.tree_buffer, { clear = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = GROUP,
    pattern = tostring(self.tree_window),
    callback = function()
      self:close()
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = GROUP,
    pattern = tostring(self.details_window),
    callback = function()
      self:close()
    end,
    once = true,
  })

  -- Prevent buffer switching in panel windows
  vim.api.nvim_create_autocmd("BufEnter", {
    group = GROUP,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if win == self.tree_window then
        local current_buf = vim.api.nvim_win_get_buf(win)
        if current_buf ~= self.tree_buffer and vim.api.nvim_buf_is_valid(self.tree_buffer) then
          vim.api.nvim_win_set_buf(win, self.tree_buffer)
        end
      elseif win == self.details_window then
        local current_buf = vim.api.nvim_win_get_buf(win)
        if current_buf ~= self.details_buffer and vim.api.nvim_buf_is_valid(self.details_buffer) then
          vim.api.nvim_win_set_buf(win, self.details_buffer)
        end
      end
    end,
  })

  -- Subscribe to state changes (must be last - callback fires immediately and may close)
  local prev_tab_count = #self.service:get_state().tabs
  self.unsubscribe = self.service:subscribe(function(state)
    local curr_tab_count = #state.tabs
    -- Close window when tabs become empty (not on initial open with 0 tabs)
    if curr_tab_count == 0 and prev_tab_count > 0 then
      self:close()
      return
    end
    prev_tab_count = curr_tab_count
    -- Feed navigation state to details service
    self.details_service:update_from_navigation(state)
    self:_render_tree(state)
    self:_render_details()
  end)
end

---Close the buffer consumer windows
function WindowConsumer:close()
  if self.unsubscribe then
    self.unsubscribe()
    self.unsubscribe = nil
  end

  if self.details_window and vim.api.nvim_win_is_valid(self.details_window) then
    vim.api.nvim_win_close(self.details_window, true)
  end
  self.details_window = nil

  if self.tree_window and vim.api.nvim_win_is_valid(self.tree_window) then
    vim.api.nvim_win_close(self.tree_window, true)
  end
  self.tree_window = nil

  -- Delete buffers (since bufhidden=hide, they won't auto-delete)
  if self.details_buffer and vim.api.nvim_buf_is_valid(self.details_buffer) then
    vim.api.nvim_buf_delete(self.details_buffer, { force = true })
  end
  self.details_buffer = nil

  if self.tree_buffer and vim.api.nvim_buf_is_valid(self.tree_buffer) then
    vim.api.nvim_buf_delete(self.tree_buffer, { force = true })
  end
  self.tree_buffer = nil
end

---Toggle the buffer consumer windows
function WindowConsumer:toggle()
  if self.tree_window and vim.api.nvim_win_is_valid(self.tree_window) then
    self:close()
  else
    self:open()
  end
end

---Adapter to match WindowConsumer API
---@param on_event fun(cb: fun(event: NopeEvent)): fun()
---@param send_command fun(command: NopeCommand): nil
---@return WindowConsumer
local function make(on_event, send_command)
  local Service = require("nope.consumers.WindowConsumer.Navigation.state.NavigationService")
  local service = Service.new(send_command)

  on_event(function(event)
    service:handle_event(event)
  end)

  return WindowConsumer.new(service)
end

return {
  new = WindowConsumer.new,
  make = make,
}
