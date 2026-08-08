vim.opt.rtp:append(vim.env.PWD)

local ScratchWindow = require("scoped.ScratchWindow")
local CenteredToBufferPositionStrategy = require("scoped.ScratchWindow.CenteredToBufferPositionStrategy")

-- Create a CenteredToBufferPositionStrategy with max width and height
local position_strategy = CenteredToBufferPositionStrategy.new(80, 20, 1, 1)

-- Create a ScratchWindow instance
local scratch_window = ScratchWindow.new({
  position_strategy = position_strategy,
})

-- Create a test buffer with some content
local buffer_id = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, {
  "This is a scratch buffer",
  "Type something here...",
  "",
  "Press :bnext or switch buffers to close the window automatically",
  "Or call scratch_window:close() manually",
  "Call scratch_window:open(test_buffer_id) again to test re-opening.",
})

-- Open the scratch window
local opened = scratch_window:open(buffer_id)
if opened then
  print("Scratch window opened successfully")
else
  print("Scratch window was already open")
end

-- Expose for manual testing
_G.scratch_window = scratch_window
_G.test_buffer_id = buffer_id
