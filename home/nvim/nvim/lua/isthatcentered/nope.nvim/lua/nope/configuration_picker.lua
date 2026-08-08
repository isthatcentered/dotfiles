---@class ConfigurationPicker
---@field strategy FindFileStrategy
local ConfigurationPicker = {}
ConfigurationPicker.__index = ConfigurationPicker

---Create a new ConfigurationPicker instance
---@param strategy FindFileStrategy Strategy for finding files
---@return ConfigurationPicker
function ConfigurationPicker.new(strategy)
  if not strategy then
    error("ConfigurationPicker requires a FindFileStrategy")
  end

  local instance = setmetatable({}, ConfigurationPicker)
  instance.strategy = strategy
  return instance
end

---Open file picker with glob filter
---@param on_selection fun(selected: string?) Callback when file is selected or the select is closed
---@param filter string Glob pattern (e.g., "**/vitest*")
---@return nil
function ConfigurationPicker:open(on_selection, filter)
  -- Find files using strategy
  local files = self.strategy:find(filter)

  -- If no matches and filter was provided, retry without filter
  if #files == 0 and filter ~= nil and filter ~= "" then
    vim.notify(string.format("No files matching '%s' found. Showing all files...", filter), vim.log.levels.WARN)
    files = self.strategy:find("")
  end

  -- If still no files, show error
  if #files == 0 then
    vim.notify("No files found in current directory", vim.log.levels.ERROR)
    return
  end

  -- Show picker
  vim.ui.select(files, {
    prompt = "Select configuration file:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    on_selection(choice)
  end)
end

return ConfigurationPicker
