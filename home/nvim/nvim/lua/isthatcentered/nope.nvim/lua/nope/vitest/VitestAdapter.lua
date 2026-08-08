local VitestRunner = require("nope.vitest.VitestRunner")

---@class VitestAdapter: FrameworkAdapter
local VitestAdapter = {}
VitestAdapter.__index = VitestAdapter

--- Get the plugin's root directory by walking up from this file's location
---@return string
local function get_plugin_root()
  local info = debug.getinfo(1, "S")
  local script_path = info.source:sub(2) -- remove leading '@'
  -- script is at <root>/lua/nope/vitest/VitestAdapter.lua
  -- go up 4 levels: vitest/ -> nope/ -> lua/ -> root/
  return vim.fn.fnamemodify(script_path, ":h:h:h:h")
end

---@return VitestAdapter
function VitestAdapter.new()
  return setmetatable({
    name = "Vitest",
    config_glob_pattern = "**/*vitest*",
  }, VitestAdapter)
end

---@param configuration RunConfiguration
---@return Runner
function VitestAdapter:get_runner(configuration)
  local reporter_path = get_plugin_root() .. "/src/reporter.ts"
  local command = {
    "npx",
    "vitest",
    "--reporter",
    reporter_path,
    "--includeTaskLocation",
  }

  if configuration.watch then
    table.insert(command, "--watch")
  end

  if configuration.configuration_path then
    table.insert(command, "--config")
    table.insert(command, configuration.configuration_path)
  end

  if configuration.directory_path then
    table.insert(command, "--dir")
    table.insert(command, configuration.directory_path)
  end

  if configuration.file_path then
    table.insert(command, configuration.file_path)
  end

  return VitestRunner.new(command)
end

---@param buffer_id integer
---@return boolean
function VitestAdapter:is_test_file(buffer_id) -- luacheck: ignore
  return true
end

return VitestAdapter
