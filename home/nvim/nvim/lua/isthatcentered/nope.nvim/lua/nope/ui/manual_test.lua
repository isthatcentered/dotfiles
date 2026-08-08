---Manual test for nope.ui component library
---Run with: :luafile lua/nope/ui/manual_test.lua

local ui = require('nope.ui')
local Text, Stack, Keybind, Padding, Extmark, Array = ui.Text, ui.Stack, ui.Keybind, ui.Padding, ui.Extmark, ui.Array
local use_state, use_mount, use_unmount = ui.use_state, ui.use_mount, ui.use_unmount

---@class TestItem
---@field id string
---@field name string
---@field passed boolean

local function Counter()
  local count, set_count = use_state(0)

  use_mount(function()
    print('[Counter] mounted')
  end)

  use_unmount(function()
    print('[Counter] unmounted')
  end)

  return Stack({}, {
    Text({ text = 'Count: ' .. count, hl = 'Title' }),
    Keybind({ key = '<CR>', on_press = function() set_count(count + 1) end }, {
      Text({ text = '  [Press Enter to increment]', hl = 'Comment' })
    }),
  })
end

local function TestListItem(props)
  local expanded, set_expanded = use_state(false)
  local test = props.test

  return Keybind({ key = 'o', on_press = function() set_expanded(not expanded) end }, {
    Stack({}, vim.tbl_filter(function(c) return c end, {
      Extmark({ sign_text = test.passed and '✓' or '✗', sign_hl = test.passed and 'DiagnosticOk' or 'DiagnosticError' }, {
        Text({ text = test.name }),
      }),
      expanded and Padding({ left = 4 }, {
        Text({ text = 'ID: ' .. test.id, hl = 'Comment' }),
        Text({ text = 'Status: ' .. (test.passed and 'PASSED' or 'FAILED'), hl = test.passed and 'DiagnosticOk' or 'DiagnosticError' }),
      }) or nil,
    }))
  })
end

local function TestList(props)
  return Stack({}, {
    Text({ text = 'Test Results:', hl = 'Title' }),
    Text({ text = '' }),
    Array({
      items = props.tests,
      key = function(t) return t.id end,
      render = function(test)
        return TestListItem({ test = test })
      end,
    }),
    Text({ text = '' }),
    Text({ text = 'Press "o" on a test to toggle details', hl = 'Comment' }),
  })
end

local function App()
  local tests = {
    { id = '1', name = 'test_addition', passed = true },
    { id = '2', name = 'test_subtraction', passed = true },
    { id = '3', name = 'test_division_by_zero', passed = false },
    { id = '4', name = 'test_multiplication', passed = true },
  }

  return Stack({}, {
    Counter(),
    Text({ text = '' }),
    Text({ text = string.rep('─', 40) }),
    Text({ text = '' }),
    TestList({ tests = tests }),
  })
end

-- Create buffer and window
local buf = vim.api.nvim_create_buf(false, true)
vim.bo[buf].bufhidden = 'wipe'
vim.bo[buf].filetype = 'nope-ui-test'

local win = vim.api.nvim_open_win(buf, true, {
  split = 'below',
  height = 20,
})

-- Render
local root = ui.create_root(buf)
root:render(App)

-- Cleanup on buffer delete
vim.api.nvim_create_autocmd('BufWipeout', {
  buffer = buf,
  callback = function()
    root:unmount()
  end,
})

print('nope.ui manual test loaded. Press Enter to increment counter, "o" to toggle test details.')
