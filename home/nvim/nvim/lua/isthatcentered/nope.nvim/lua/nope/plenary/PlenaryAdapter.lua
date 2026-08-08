local PlenaryRunner = require("nope.plenary.PlenaryRunner")
local WatchController = require("nope.plenary.WatchController")

---@class PlenaryAdapter: FrameworkAdapter
local PlenaryAdapter = {}
PlenaryAdapter.__index = PlenaryAdapter

---@return PlenaryAdapter
function PlenaryAdapter.new()
  return setmetatable({
    name = "Plenary",
    config_glob_pattern = "**/*.vim",
  }, PlenaryAdapter)
end

---@param configuration RunConfiguration
---@return Runner
function PlenaryAdapter:get_runner(configuration)
  local config_path = configuration.configuration_path or "scripts/minimal_init.vim"
  local file_path = configuration.file_path
  local directory_path = configuration.directory_path

  local command
  if file_path then
    -- Run single file
    command = {
      "nvim",
      "--headless",
      "--noplugin",
      "--clean",
      "-u",
      config_path,
      "-c",
      "PlenaryBustedFile " .. file_path,
    }
  else
    -- Run directory (specific or default)
    local scope = directory_path or "lua/"
    local plenary_opts = "{minimal_init = '" .. config_path .. "'}"
    local plenary_cmd = "PlenaryBustedDirectory " .. scope .. " " .. plenary_opts

    command = {
      "nvim",
      "--headless",
      "--noplugin",
      "--clean",
      "-u",
      config_path,
      "-c",
      plenary_cmd,
    }
  end

  local runner = PlenaryRunner.new(command)
  if configuration.watch then
    return WatchController.new(runner)
  end
  return runner
end

---@param buffer_id integer
---@return boolean
function PlenaryAdapter:is_test_file(buffer_id)
  local name = vim.api.nvim_buf_get_name(buffer_id)
  return name:match("_spec%.lua$") ~= nil
end

return PlenaryAdapter
