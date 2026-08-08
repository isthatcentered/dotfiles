local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"
local treesitter_dir = os.getenv("NVIM_TREESITTER_DIR") or "/tmp/nvim-treesitter"
local site_dir = vim.fn.stdpath("data") .. "/site"

local function ensure_repo(path, url, label, marker)
	if vim.fn.filereadable(path .. "/" .. marker) == 1 then
		return
	end

	if vim.fn.isdirectory(path) == 1 then
		vim.fn.delete(path, "rf")
	end

	local result = vim.fn.system({
		"git",
		"clone",
		"--depth",
		"1",
		url,
		path,
	})
	if vim.v.shell_error ~= 0 then
		print(("Failed to clone %s: %s"):format(label, result))
		os.exit(1)
	end
end

ensure_repo(plenary_dir, "https://github.com/nvim-lua/plenary.nvim", "plenary", "lua/plenary/busted.lua")
ensure_repo(treesitter_dir, "https://github.com/nvim-treesitter/nvim-treesitter", "nvim-treesitter", "lua/nvim-treesitter/init.lua")

-- Disable netrw before it loads (we don't need file browser in tests,
-- and it errors when packpath is empty)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Reset runtimepath to only essentials
vim.opt.rtp = {
	vim.env.VIMRUNTIME, -- Neovim's core runtime
	site_dir, -- Parser install location
	plenary_dir, -- Plenary for testing
	treesitter_dir, -- Tree-sitter parser installer
	".", -- This plugin
}

vim.opt.packpath = {} -- Disable all packages
vim.opt.swapfile = false

local ok, nvim_treesitter = pcall(require, "nvim-treesitter")
if not ok then
	print("Failed to load nvim-treesitter")
	os.exit(1)
end

local install = nvim_treesitter.install({ "typescript", "tsx" })
install:wait(300000)

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")
