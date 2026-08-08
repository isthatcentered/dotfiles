# AGENTS.md

## Build/Lint/Test Commands
- **Lint**: `stylua --check lua/` (check formatting) or `stylua lua/` (format)
- **Test all**: `make test`
- **Test watch**: `make test-watch`
- **Test single file**: `busted lua/path/to/file_spec.lua`
- **Test directory**: `make test-watch-path PATH=lua/some/dir/`

## Code Style Guidelines
- **Language**: Lua 5.1 (Neovim compatible)
- **Formatting**: 2 spaces indent, 160 column width, Unix line endings, auto single quotes (stylua)
- **Naming**: snake_case for functions/variables, PascalCase for modules/classes
- **Imports**: `require 'module'` or `require('module')`
- **Types**: EmmyLua annotations (e.g., `---@return table?`)
- **Error handling**: Use `assert` for preconditions, return `nil` or `false` for failures
- **Comments**: `--` for single line, `---` for doc comments
- **Structure**: Functions first, then locals, avoid globals except vim
- **Testing**: BDD style with `describe`/`it`, files end in `_spec.lua`