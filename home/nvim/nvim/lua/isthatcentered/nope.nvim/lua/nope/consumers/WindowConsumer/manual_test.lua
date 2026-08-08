-- Manual test for WindowConsumer
-- Run with: :luafile lua/nope/consumers/WindowConsumer/manual_test.lua

vim.opt.rtp:append(vim.env.PWD)

-- Reload modules
for key in pairs(package.loaded) do
  if key == "nope" or key:match("^nope%.") then
    package.loaded[key] = nil
  end
end

local Service = require("nope.consumers.WindowConsumer.Navigation.state.NavigationService")
local WindowConsumer = require("nope.consumers.WindowConsumer")

-- Create service with mock send_command
local service = Service.new(function(cmd)
  print("Command sent:", vim.inspect(cmd))
end)

-- Create consumer
local consumer = WindowConsumer.new(service)

-- Simulate some test run events
service:handle_event({
  type = "NopeTestRunStarted",
  payload = { key = "run1", configuration = { label = "unit" } },
})

-- Simulate test results
service:handle_event({
  type = "NopeTestRunResults",
  payload = {
    key = "run1",
    results = {
      status = "done",
      duration_ms = 1234,
      summary = { total = 5, passed = 3, failed = 2, skipped = 0 },
      files = {
        {
          id = "f1",
          path = "lua/nope/test_spec.lua",
          status = "failed",
          tests = {
            {
              id = "t1",
              name = "should pass",
              full_name = "my suite > should pass",
              status = "passed",
              duration_ms = 10,
              location = { line = 5, column = 1 },
            },
            {
              id = "t2",
              name = "should fail",
              full_name = "my suite > should fail",
              status = "failed",
              duration_ms = 20,
              location = { line = 10, column = 1 },
              failure = {
                message = "Expected 1 but got 2",
              },
            },
          },
          suites = {},
        },
      },
    },
  },
})

service:handle_event({
  type = "NopeTestRunEnded",
  payload = { key = "run1" },
})

-- Add a second run
service:handle_event({
  type = "NopeTestRunStarted",
  payload = { key = "run2", configuration = { label = "integration" } },
})

-- Open the consumer
consumer:open()

print("WindowConsumer opened. Try these keybinds:")
print("  <C-n>/<C-p>  Navigate")
print("  H/L          Switch tabs")
print("  g?           Toggle help")
print("  ff           Toggle failures filter")
print("  q            Close")
