This repository is a template for Neovim plugins written in Lua.

The intention is that you use this template to create a new repository where you then adapt this readme and add your plugin code.
The template includes the following:

- GitHub workflows and configurations to run linters and tests
- Packaging of tagged releases and upload to [LuaRocks][luarocks]
  if a [`LUAROCKS_API_KEY`][luarocks-api-key] is added
  to the [GitHub Actions secrets][gh-actions-secrets]
- Minimal test setup:
  - A `scm` [rockspec][rockspec-format], `nvim-lua-plugin-scm-1.rockspec`
  - A `.busted` file
- EditorConfig
- A .luacheckrc


To get started writing a Lua plugin, I recommend reading `:help lua-guide` and
`:help write-plugin`.

## Development

### Using Lua
```bash
hererocks lua53 -l5.3 -rlatest      # Install Lua 5.3 with latest LuaRocks into 'lua53' directory.
source lua53/bin/activate           # Run activation script, adding 'lua53/bin' to $PATH.
lua -v                              # Lua, LuaRocks, and programs
luarocks install luacheck           # installed using LuaRocks
luacheck --version                  # can now be used.
deactivate-lua                      # Remove 'lua53/bin' from $PATH.
lua53/bin/lua -v                    # All the binaries can still be used directly.# nvim-lua-plugin-template
```

### Run tests

The easiest way to run tests is using the provided Makefile, which automatically sets up Lua 5.1.1 if needed:

```bash
# Run all tests once (automatically sets up Lua 5.1.1 if needed)
make test

# Watch all *_spec.lua files and run tests on changes
make test-watch

# Watch *_spec.lua files under a specific path
make test-watch-path PATH=lua/

# Clean up local Lua installation
make clean
```

#### Manual Testing

Alternatively, you can run tests manually. This requires either [luarocks][luarocks] or [busted][busted] and [nlua][nlua] to be installed[^1].

[^1]: The test suite assumes that `nlua` has been installed using luarocks into `~/.luarocks/bin/`.

```bash
luarocks test --local
# or
busted
```

Or if you want to run a single test file:

```bash
luarocks test spec/path_to_file.lua --local
# or
busted spec/path_to_file.lua
```

If you see an error like `module 'busted.runner' not found`:

```bash
eval $(luarocks path --no-bin)
```

This command configures the Lua path to include luarocks directories so that busted can find the required modules.

For this to work you need to have Lua 5.1 set as your default version for
luarocks. If that's not the case you can pass `--lua-version 5.1` to all the
luarocks commands above.

[rockspec-format]: https://github.com/luarocks/luarocks/wiki/Rockspec-format
[luarocks]: https://luarocks.org
[luarocks-api-key]: https://luarocks.org/settings/api-keys
[gh-actions-secrets]: https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository
[busted]: https://lunarmodules.github.io/busted/
[nlua]: https://github.com/mfussenegger/nlua
[use-this-template]: https://github.com/new?template_name=nvim-lua-plugin-template&template_owner=nvim-lua



-----
Random readings:
https://mrcjkb.dev/posts/2023-06-06-luarocks-test.html

