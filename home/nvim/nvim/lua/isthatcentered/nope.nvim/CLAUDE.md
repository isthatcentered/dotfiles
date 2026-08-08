# Agent Guidelines for nope.nvim

- In all interactions, be extremely concise and sacrifice grammar for the sake of conscision.
- At the end of each plan, give me a list of unsanswered questions to answer, if any.
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

## Code Style

- **TypeScript**: Strict mode, no semicolons, single quotes, trailing commas (ES5), explicit return types, ES module imports
- **Lua**: snake_case for functions/variables, PascalCase for classes, LuaDoc annotations required, `local M = {}` module pattern
- **Naming**: PascalCase for class filenames, camelCase for TS, snake_case for Lua
- **Error handling**: TS throws Error(), Lua uses vim.notify() with log levels
- **Files**: Tests end in \_spec.lua or .test.ts, co-located with source
- **Imports**: External deps first, then internal modules

## Skills

- **Testing**: Use `testing` skill for writing tests - covers spies, mocks, assertions, async patterns
- **Architecture**: Use `nope-architecture` skill for design decisions - covers services, events, UI components
