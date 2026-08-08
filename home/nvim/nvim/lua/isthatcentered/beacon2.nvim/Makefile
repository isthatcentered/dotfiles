.PHONY: test test-watch test-watch-path setup-lua clean

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
	nvim --headless --noplugin -u scripts/minimal.vim -c "PlenaryBustedDirectory lua/ {minimal_init = 'scripts/minimal.vim'}"

# Watch lua folder and run tests on changes
test-watch: setup-lua
	find lua/ -name "*.lua" | entr -s 'nvim --headless --noplugin -u scripts/minimal.vim -c "PlenaryBustedDirectory lua/ {minimal_init = '\''scripts/minimal.vim'\''}"'

# Clean up the local Lua installation
clean:
	rm -rf $(LUA_DIR)
