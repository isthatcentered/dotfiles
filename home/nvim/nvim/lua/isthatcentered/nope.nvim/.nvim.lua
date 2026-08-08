local nope = require("nope")
local RunConfiguration = require("nope.RunConfiguration")

vim.keymap.set("n", "<leader>nv", function()
  local file_path = vim.fn.expand("%")
  local file_name = vim.fn.expand("%:t")

  nope.start_run(RunConfiguration.new("Vitest", {
    label = file_name,
    watch = true,
    configuration_path = "vitest.config.ts",
    file_path = file_path,
  }))
end, { desc = "Run single vitest test" })

vim.keymap.set("n", "<leader>nf", function()
  local file_path = vim.fn.expand("%")
  local file_name = vim.fn.expand("%:t")

  nope.start_run(RunConfiguration.new("Plenary", {
    label = file_name,
    watch = true,
    configuration_path = "scripts/minimal_init.vim",
    file_path = file_path,
  }))
end, { desc = "Run single file Plenary test" })
