local M = {}

M.autocommands_group = vim.api.nvim_create_augroup("Scoped", { clear = true })

M.extmarks_namespace = vim.api.nvim_create_namespace("Scoped")

M.diagnostics_namespace = vim.api.nvim_create_namespace("Scoped:diagnostics")

return M
