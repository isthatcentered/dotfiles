-- This is a file to manually explore the plugin
vim.opt.rtp:append(vim.env.PWD)

local fresh = true
if fresh then
  for key in pairs(package.loaded) do
    if key == "nope" or key:match("^nope%.") then
      package.loaded[key] = nil
    end
  end
end

local S = require("nope.String")
local C = require("nope.ui2")
local buffer_id = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer_id })

local window_id = vim.api.nvim_open_win(buffer_id, true, {
  width = 50,
  height = 20,
  relative = "win",
  row = 30,
  col = 5,
})

vim.api.nvim_set_option_value("number", false, { win = window_id })
vim.api.nvim_set_option_value("relativenumber", false, { win = window_id })
vim.api.nvim_set_option_value("signcolumn", "no", { win = window_id })

local tree_panel = C.Stack({
  -- [󰈈 init_spec.lua]
  C.Text("✓ 41 total, 41 passed (0.00s)"),
  C.Text("✓ 󰈙 init_spec.lua"),
  C.Text("✓ flutter style Text No constraint takes all the necessary space"),
})



local set_app_state, on_app_state_change = C.state(0)

local App = function(state, set_state)
  return C.Stack({
    C.Text("Count: " .. tostring(state)),
    C.Actionable({
      keybind = "<CR>",
      on_triggered = function()
        set_state(state + 1)
      end,
    }, C.Text("increase")),
  })
end

local unsubscribe = on_app_state_change(function(new_state)
  C.render(buffer_id, App(new_state, set_app_state), {
    max_width = vim.api.nvim_win_get_width(window_id),
    min_width = 0,
  })
end)

vim.api.nvim_create_autocmd("WinClosed", {
  pattern = {tostring(window_id)},
  callback =  function ()
    unsubscribe()
  end
})
