local M = {}

---@param buffer_id integer
function M.print_buffer_settings(buffer_id)
  local options = vim.api.nvim_get_all_options_info()
  local result = {}
  for name, details in pairs(options) do
    if details.scope == "buf" then
      result[name] = vim.api.nvim_get_option_value(name, {
        buf = buffer_id,
        scope = "local",
      })
    end
  end
  vim.print(result)
end

return M
