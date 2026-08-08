# Neovim Configuration

A personal Neovim configuration with comprehensive testing setup for Lua plugins.

## Testing

This project uses a complete Lua testing environment for developing and testing Neovim plugins. The testing setup is managed through a Makefile that automatically handles all dependencies.

### Quick Start

Run all tests once:
```bash
make test
```

Watch for changes and auto-run tests:
```bash
make test-watch
```

Watch tests in a specific directory:
```bash
make test-watch-path PATH=lua/some/path/
```

Clean up test environment:
```bash
make clean
```

### Testing Tools

The testing setup uses three key tools that work together to provide a complete Neovim Lua testing environment:

#### hererocks

**What it does:** A tool for installing and managing multiple versions of Lua and LuaRocks in isolated environments.

**Why we use it:** 
- Neovim requires Lua 5.1 compatibility, but your system might have a different version
- Creates an isolated environment that doesn't interfere with system Lua
- Bundles LuaRocks for easy dependency management

**Manual installation (if needed):**
```bash
pip3 install hererocks
```

**Usage in this project:**
The Makefile automatically installs hererocks and uses it to create a local Lua 5.1.1 environment in the `__lua__/` directory.

#### nlua

**What it does:** A Neovim Lua runner that provides access to Neovim's API and vim module outside of Neovim itself.

**Why we use it:**
- Enables testing of Neovim plugins without running a full Neovim instance
- Provides the `vim` global and Neovim API functions in test environment
- Essential for testing any code that uses `vim.api.*` or other Neovim-specific functions

**Manual installation (if needed):**
```bash
luarocks install nlua
```

**Usage in this project:**
The `.busted` configuration file tells busted to use `nlua` as the Lua interpreter, making Neovim APIs available in tests.

#### busted

**What it does:** A unit testing framework for Lua with a behavior-driven development (BDD) style syntax.

**Why we use it:**
- Provides `describe()`, `it()`, `test()`, and assertion functions
- Excellent error reporting and test organization
- Standard choice for Lua testing, widely adopted in the Lua community
- Integrates well with LuaRocks project structure

**Manual installation (if needed):**
```bash
luarocks install busted
```

**Usage in this project:**
- Test files use `*_spec.lua` naming convention
- Tests are written using busted's BDD syntax with `describe()` and `test()` blocks
- The rockspec file specifies `test = { type = "busted" }` to integrate with LuaRocks

### Test Structure

```
lua/
├── example_spec.lua    # Test files (must end in _spec.lua)
├── nope.lua           # Source files being tested
└── ...other lua files
```

### Configuration Files

- **`nvim-lua-plugin-scm-1.rockspec`**: LuaRocks project specification with test configuration
- **`.busted`**: Busted configuration specifying nlua usage and Lua paths
- **`Makefile`**: Automated setup and test running

### How It All Works Together

1. **hererocks** creates an isolated Lua 5.1.1 environment
2. **LuaRocks** (installed by hererocks) manages Lua dependencies
3. **nlua** and **busted** are installed as dependencies via LuaRocks
4. **busted** runs tests using **nlua** as the interpreter
5. **nlua** provides Neovim API access during testing
6. The **rockspec** tells LuaRocks how to run tests
7. The **Makefile** orchestrates the entire process

This setup ensures your Neovim Lua plugins can be tested reliably with full access to Neovim APIs, regardless of your system's Lua configuration.
