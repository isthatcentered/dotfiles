# Agent Guidelines for nope.nvim

- In all interactions, be extremely concise and sacrifice grammar for the sake of conscision.
- After you are done with a change, commit the changes with a concise description of what was achieved. If there were already pending changes commit those before doing any work

## Build/Test/Lint Commands

- **Lua tests (all)**: `make test` - Runs all \*\_spec.lua files using Plenary test runner
- **Lua test (single)**: `nvim --headless --noplugin --clean -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/path/to/file_spec.lua"`
- **TypeScript tests (all)**: `npm test` or `vitest run`
- **TypeScript test (single)**: `vitest run src/path/to/file.test.ts` - Use file path to run specific test
- **Build**: `npm run build` - Compiles TypeScript to dist/
- **Lint TypeScript**: `npm run lint` - Runs tsc --noEmit for type checking
- **Lint Lua**: `luacheck lua/` - Runs luacheck on Lua files
- **Format**: `npm run format` - Prettier with single quotes, no semicolons, 2-space indent

## Testing Framework

- **Test Runner**: Lua tests use Plenary test runner (plenary.nvim)
- **Assertions**: Use luassert for all assertions. Favor assert.same for every assertion when possible
- **Test Structure**: Use `describe()` and `it()` blocks for organizing tests
- **Spies/Mocks**: Use luassert spy library for mocking functions

  ```lua
  local spy = require('luassert.spy')
  local match = require('luassert.match')

  -- Create a spy
  local s = spy.new(function() end)
  s('foo')
  s(1)
  s({}, 'bar')

  -- Assert spy was called
  assert.spy(s).was.called()
  assert.spy(s).was.called_with('foo')
  assert.spy(s).was.called_with(match.is_string())
  assert.spy(s).was.called_with(match.is_number())
  assert.spy(s).was.called_with(match.is_table(), match.is_string())
  assert.spy(s).was_not.called_with('baz')
  ```

- **TypeScript tests**: Use Vitest with built-in mocking and assertions
- **Vim APIs in Lua tests**: Tests run in real Neovim instance - use actual vim APIs (`vim.diagnostic.*`, `vim.api.*`, etc.) instead of mocking. Only mock for spy/callback testing.
- **Test fixtures**: Place fixture files in `lua/nope/fixtures/`

## Code Style

- **TypeScript**: Strict mode enabled (noImplicitAny, strictNullChecks, etc.), no semicolons, single quotes, trailing commas (ES5), arrow functions prefer no parens for single arg, explicit return types required, use ES module imports
- **Lua**: snake_case for functions/variables, PascalCase for classes, always use LuaDoc annotations (`---@param`, `---@return`, `---@class`), local M = {} module pattern, use vim.notify() for errors with log levels (ERROR, WARN, INFO)
- **Naming**: use PascalCase for class filenames, camelCase for TS functions/variables, snake_case for Lua, PascalCase for classes in both languages
- **Error handling**: TypeScript throws Error() with descriptive messages, Lua uses vim.notify() with appropriate log levels
- **Files**: Test files end in \_spec.lua (Lua) or .test.ts (TypeScript), put tests in same directory as source
- **Imports**: Group by external deps first, then internal modules, no unused imports
