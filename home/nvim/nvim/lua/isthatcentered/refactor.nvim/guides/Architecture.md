# Architecture

## Overview

The plugin is Lua-first.

It does not register built-in refactor commands. Users call refactors through the
plugin namespace and can create their own mappings or commands on top of that.

Current public entrypoints:

- `require("refactor")`
- `require("refactor.context")`
- `require("refactor.typescript")`

## Public API

The root module lives in `lua/refactor/init.lua`.

It exposes:

- language namespaces such as `Refactor.typescript`
- `Refactor.context()` as a convenience helper for the current editor state

Example:

```lua
local Refactor = require("refactor")

vim.keymap.set("n", "<leader>grq", function()
	Refactor.typescript.replace_with_template_string(Refactor.context())
end, { desc = "Replace with template string" })
```

`require("refactor.context")` exposes `current()` and returns:

```lua
{
	buffer_id = 0,
	cursor_position = {
		line = 0,
		column = 0,
	},
}
```

Context rules:

- `buffer_id` may be `0` for the current buffer
- `cursor_position.line` is 0-based
- `cursor_position.column` is 0-based
- refactors raise `Refactor: ...` errors on failure
- successful refactors apply edits directly and return nothing

## Module Layout

Each language gets a namespace module:

- `lua/refactor/typescript/init.lua`

Each refactor gets its own implementation module:

- `lua/refactor/typescript/replace_with_template_string.lua`

The public language namespace is a thin wrapper over the implementation module.

Implementation modules expose `run(...)`:

- `run(context)` for refactors without custom options
- `run(options, context)` for refactors with custom options

That keeps the public API ergonomic while giving each refactor a single internal
entrypoint.

## Adding a New Refactor

For a new TypeScript refactor named `flip_if_else`:

1. Create `lua/refactor/typescript/flip_if_else.lua`.
2. Export a module table with `run(context)` or `run(options, context)`.
3. Validate context at the module boundary and raise `Refactor: ...` on invalid input.
4. Resolve `buffer_id = 0` to the current buffer if needed.
5. Apply the edit directly inside `run(...)`.
6. Add a thin wrapper in `lua/refactor/typescript/init.lua`.
7. Add focused tests for the implementation module.
8. Add or update a small public API smoke test if the namespace changed.

Example skeleton:

```lua
local M = {}

function M.run(context)
	-- validate context
	-- inspect buffer state
	-- apply edits
end

return M
```

Namespace wrapper:

```lua
local flip_if_else = require("refactor.typescript.flip_if_else")

local M = {}

function M.flip_if_else(context)
	return flip_if_else.run(context)
end

return M
```

## Testing

Tests should primarily target the implementation module directly, for example:

- `require("refactor.typescript.replace_with_template_string")`

Keep tests shaped around the full observable result:

- final buffer lines
- final cursor position when relevant
- normalized error message on failure

Also keep lightweight smoke coverage for the public namespace when adding new
exports so the root and language modules do not drift from the implementation
modules.
