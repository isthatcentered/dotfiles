---nope.ui - React-style component library for Neovim buffers
---
---Usage:
---  local ui = require('nope.ui')
---  local Text, Stack, Array = ui.Text, ui.Stack, ui.Array
---  local use_state, use_mount, use_unmount = ui.use_state, ui.use_mount, ui.use_unmount
---
---  local function MyComponent(props)
---    local count, set_count = use_state(0)
---
---    use_mount(function()
---      print("mounted")
---    end)
---
---    return Stack({}, {
---      Text({ text = "Count: " .. count }),
---      Keybind({ key = "<CR>", on_press = function() set_count(count + 1) end }, {
---        Text({ text = "Increment" })
---      })
---    })
---  end
---
---  local root = ui.create_root(buf)
---  root:render(function()
---    return MyComponent({ data = some_data })
---  end)

local hooks = require('nope.ui.hooks')
local Root = require('nope.ui.Root')

local M = {}

-- Components
M.Text = require('nope.ui.nodes.Text')
M.Stack = require('nope.ui.nodes.Stack')
M.Array = require('nope.ui.nodes.Array')
M.Padding = require('nope.ui.nodes.Padding')
M.Extmark = require('nope.ui.nodes.Extmark')
M.Keybind = require('nope.ui.nodes.Keybind')

-- Hooks
M.use_state = hooks.use_state
M.use_mount = hooks.use_mount
M.use_unmount = hooks.use_unmount

---Create a new root attached to a buffer
---@param buf number
---@return Root
function M.create_root(buf)
  return Root.new(buf)
end

return M
