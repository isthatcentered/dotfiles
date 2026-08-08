# AGENTS.md - Neovim Scoped Plugin
- In all interactions, be extremely concise and sacrifice grammar for the sake of conscision.
- After you are done with a change, commit the changes with a concise description of what was achieved. If there were already pending changes commit those before doing any work

## Project
lua/scoped/Scoped/init.lua is the main interface of the plugin I am creating. The plugin allows you to create file lists and navigate between the files in your lists.
Lists and files can be visually managed using the ListsEditor lua/scoped/ListsEditor/init.lua .
The list editor communicates with the Registry lua/scoped/Registry/init.lua that acts as the backend to the lists/files/etc management.

## Commands
- **Run all tests**: `make test` (auto-sets up Lua 5.1.1)
- **Run single test file**: `nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedFile lua/scoped/Brain_spec.lua"`
- **Watch tests**: `make test-watch` or `make test-watch-file lua/scoped/Brain_spec.lua`
- **Lint**: `luacheck lua/` (configured via .luacheckrc)

## Architecture
- **Neovim plugin** written in Lua 5.1 for bookmark/file management
- **Core modules** (in `lua/scoped/`): `Brain` (main controller), `List` (collection manager), `File` (file wrapper), `Scoped` (public API), `Picker` (UI), `Components` (UI components)
- **Test framework**: Busted + Plenary with nlua (test files: `*_spec.lua`)
- **Fixtures**: Test files in `lua/scoped/fixtures/`

## Code Style
- **Imports**: Use `local Module = require("scoped.Module")` at top of file
- **Types**: Use LuaLS annotations (`---@class`, `---@param`, `---@return`, `---@field`)
- **Naming**: PascalCase for classes/modules, snake_case for functions/variables, UPPERCASE for constants
- **Error handling**: Use `assert(condition, "Error message")` or `error("Error message")`
- **Comments**: Avoid unless code is complex; explanation goes in commit messages/docs, not code

## Test Guidelines
- **Structure**: Group tests by method using `describe("method_name", function() ... end)`
- **Naming**: Use assertive test names, never use "should" (e.g., "Adding a file to a non existing list fails")
- **Instances**: Create a new module instance for each test (e.g., `EventBus.new()`)
- **Organization**: Error cases first, then success cases
- **One behavior per test**: Each `it(...)` asserts a single outcome.
- **Flow**: Keep structure simple: setup → action → assertion
- **Assertions**: Use `assert.same()` for equality checks
- **Variables**: Use descriptive local variable names
- **Helpers**: Define helper functions at the top of the file when needed
- **Errors**: Use `assert.has_error(function() ... end)` for error checks
- **Spies**: Use `spy = require("luassert.spy")` for tracking function calls
- **Neovim/editor isolation**: For tests that touch buffers/windows/UI, include `before_each(function() test_utils.reset_editor() end)`.

## Task Focus
It is very important to stick to the current task. If a test is failing and, after investigations it has nothing to do with the current task, then leave it.

## Agent Insights
- **Project Structure and Architecture**: The plugin manages file lists via a Registry (backend for lists/files/window bindings), ListsEditor (UI for editing lists), and Scoped (main interface). Methods in Scoped delegate to Registry for core operations like binding/unbinding lists to windows.
- **Code Conventions**: Follow LuaLS annotations for classes/fields/parameters/returns. Use PascalCase for modules/classes, snake_case for functions/variables. Error handling via `assert()` or `error()`. Avoid comments; commit messages/docs handle explanations. Imports like `local Module = require("scoped.Module")`.
- **Testing Practices**: Use Busted + Plenary for tests in `*_spec.lua` files. Group by method, error cases first, success cases last. Use descriptive test names without "should". Create new instances per test, use helpers at file top, assert with `assert.same()`, spies for function calls, and editor reset helpers for UI tests. One behavior per test.
- **Commands and Verification**: Run all tests with `make test` (sets up Lua 5.1.1). Lint with `luacheck lua/`. Implement features by adding methods to Scoped, validate inputs (e.g., window validity, list names), delegate to Registry, and run tests to ensure no regressions.
- **Implementation Patterns**: When exposing Registry features through Scoped, validate parameters (e.g., window IDs, list names), check existence/error appropriately, and handle silent skips (e.g., duplicate files). Use relative paths and validate file buffers with the project's ValidatePathStrategy. Test edge cases like invalid inputs or missing resources.
