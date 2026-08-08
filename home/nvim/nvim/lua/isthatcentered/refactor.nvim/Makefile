PLENARY_DIR ?= /tmp/plenary.nvim

.PHONY: test test-file lint format check

test:
	nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "PlenaryBustedDirectory lua/ {minimal_init = 'scripts/minimal_init.lua'}"

test-file:
	nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

lint:
	luacheck lua/ plugin/
	stylua lua/ plugin/
	./scripts/lint-assertions.sh

format:
	stylua lua/ plugin/

check: lint test
