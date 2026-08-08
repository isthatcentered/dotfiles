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

local RunConfiguration = require("nope.RunConfiguration")
local make_default_label = require("nope.make_default_label")
local Orchestrator = require("nope.Orchestrator2")
local VitestAdapter = require("nope.vitest.VitestAdapter")
local PlenaryAdapter = require("nope.plenary.PlenaryAdapter")
local ConfigurationPicker = require("nope.configuration_picker")
local strategies = require("nope.find_file_strategy")
local WindowConsumer = require("nope.consumers.WindowConsumer")
local DiagnosticsConsumer = require("nope.consumers.DiagnosticsConsumer.init")
local EventBus = require("nope.EventBus")

local event_bus = EventBus.Autocmd.new()
local vitest_adapter = VitestAdapter.new()
local plenary_adapter = PlenaryAdapter.new()
local window_consumer = WindowConsumer.make(
  function(cb) return event_bus:listen(cb) end,
  function(cmd) event_bus:emit(cmd) end
)
-- DiagnosticsConsumer subscribes on construction
DiagnosticsConsumer.new(
  function(cb) return event_bus:listen(cb) end
)
local nope = require("nope")
nope.setup({ --
  adapters = { vitest_adapter, plenary_adapter },
})

vim.keymap.set("n", "<leader>nf", function()
  local file_path = vim.fn.expand("%")
  local file_name = vim.fn.expand("%:t")

  nope.start_run(RunConfiguration.new(plenary_adapter.name, {
    label = make_default_label(plenary_adapter.name, file_name, nil, "scripts/minimal_init.vim", true),
    watch = true,
    configuration_path = "scripts/minimal_init.vim",
    file_path = file_path,
  }))

end, { desc = "Run single file test" })


vim.keymap.set("n", "<leader>np", function()
  window_consumer:toggle()
end, { desc = "Toggle run view" })


vim.keymap.set("n", "<leader>ns", function()
  nope.stop_all()
end, { desc = "Stop all runnng tests" })

-- The config part is still messy, I'd rather pass an instace an you call link on it. Or I give you a factory but then how di i get the instace?


---Re trigger a test run (current test run? only the ui knows which one it is though) or is it last?
---Pin a test
---Pin mutltiple tests
---configuration picker
---TODO: Take a test/suite in the list and start a new watch run with it
---TODO: auto find adapter
---TODO: Pin a test result in buffer consumer
---Follow current test

---TODO: improve vitest's diffs
---TODO: status bar display
---TODO: Buffer consumer shouldn't be focusable unless you trigger a specific shortcut
---TODO: better sizing (keep the current window size or take the whole bottom), tree section should be a third

-- TODO: Display status bar of failing files in red
-- TODO: Add a Telescope searhc for failing files (that's already the diagnostics)
-- TODO: On quit nvim, quit job
-- TODO: On quit display, quit job
-- TODO: When someone tries to switch the buffer in that window, prevent it
-- TODO: On new buffer display, add extmarks
---TODO: Components library (tree, hooks)
---TODO: File test report in status bar
-- TODO: recognize a test file
-- TODO: run a single file
-- TODO: make it work for lua
-- TODO: Remember test config
-- TODO: Focus the suite and test I am working on
-- TODO: Then enjoy coding yourself.
-- TODO: Component library to help with dynamically rendering components. Check what existing plugins are doing
-- TODO: order tests?
-- TODO: Improve the diff display. Add console logs and stuff
-- TODO: Add notification on test stop/all tests stopped
--('░░░░░░', '░░░░░░', '░░░░░░', '░░░░░░', '▓░░░░░', '▒▓░░░░', '░▒▓░░░', '░░▒▓░░', '░░░▒▓░', '░░░░▒▓', '░░░░░▒');
-- Add reporter automatically
-- Have reporter send  the correct format since it is typed.
-- Should the state live in the adapter???? well, i can do it all in ts but the adapter will take the stdin and do it's parsing
-- The adapter (vitest/go/whatever) is basically an adapter stdout->test run state
