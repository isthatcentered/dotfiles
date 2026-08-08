.PHONY: test test-watch test-watch-file setup-lua clean

LUA_DIR := __lua__
LUA_ACTIVATE := $(LUA_DIR)/bin/activate
LUA_VERSION := 5.1.1

# Check if lua is available, if not set it up
setup-lua:
	@if [ ! -f "$(LUA_ACTIVATE)" ]; then \
		echo "Setting up Lua $(LUA_VERSION) with hererocks..."; \
		if ! command -v hererocks >/dev/null 2>&1; then \
			echo "Installing hererocks..."; \
			pip3 install hererocks; \
		fi; \
		hererocks $(LUA_DIR) -l$(LUA_VERSION) -rlatest; \
		echo "Lua $(LUA_VERSION) installed in $(LUA_DIR)"; \
		echo "Installing nlua and busted..."; \
		bash -c "source $(LUA_ACTIVATE) && luarocks install nlua && luarocks install busted"; \
	fi
	@if [ ! -f "$(LUA_DIR)/bin/nlua" ]; then \
		echo "Installing missing nlua..."; \
		bash -c "source $(LUA_ACTIVATE) && luarocks install nlua"; \
	fi
	@if ! bash -c "source $(LUA_ACTIVATE) && luarocks list | grep -q busted"; then \
		echo "Installing missing busted..."; \
		bash -c "source $(LUA_ACTIVATE) && luarocks install busted"; \
	fi

# Run all tests once
test: setup-lua
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/ {minimal_init = 'scripts/minimal_init.vim'}"

# Watch lua folder and run tests on changes
test-watch: setup-lua
	@trap 'exit 0' INT; \
	while true; do \
		find lua/ -name "*.lua" | entr -r sh -c 'nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/ {minimal_init = '\''scripts/minimal_init.vim'\''}" 2>&1; exit 0' || break; \
		sleep 0.1; \
	done

# Watch lua folder and run tests for a specific file
# Usage: make test-watch-file lua/scoped/init_spec.lua
test-watch-file: setup-lua
	@FILE="$(filter-out test-watch-file,$@)"; \
	if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "Error: File path required. Usage: make test-watch-file lua/path/to/test_spec.lua"; \
		exit 1; \
	fi; \
	FILE="$(word 2,$(MAKECMDGOALS))"; \
	trap 'exit 0' INT; \
	while true; do \
		find lua/ -name "*.lua" | entr -r sh -c "nvim --headless --noplugin -u scripts/minimal_init.vim -c \"PlenaryBustedFile $$FILE\" 2>&1; exit 0" || break; \
		sleep 0.1; \
	done

# Prevent make from interpreting the file path as a target
%:
	@:

# Clean up the local Lua installation
clean:
	rm -rf $(LUA_DIR)
