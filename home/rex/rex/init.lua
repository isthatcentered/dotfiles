-- Match home/tmux/.tmux.conf where Rex has a corresponding action.
-- https://www.superlogical.com/rex/docs/customize/key-sequences
local prefix = "ctrl+b>"

local function bind(key, action, args)
  rex.bind(prefix .. key, action, args)
end

-- Windows in tmux are tabs in Rex.
bind("c", "client.tab.new")
bind("n", "client.tab.next")
bind("p", "client.tab.previous")
bind(",", "client.tab.rename")
for index = 0, 9 do
  -- tmux's default base-index is 0; Rex's API counts tabs from 1.
  bind(tostring(index), "client.tab.goto", { index = index + 1 })
end

-- Shifted keys are written using their unshifted characters.
bind("shift+5", "pane.split", { direction = "right" }) -- %
bind("shift+'", "pane.split", { direction = "down" }) -- "
bind("z", "pane.zoom")
bind("x", "pane.close")
bind("o", "pane.focus_next")

local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
  bind(key, "pane.focus", { direction = direction })
  -- Rex amounts are percentages, unlike tmux's cell counts.
  bind("alt+" .. key, "pane.resize", { direction = direction, amount = 5 })
end

bind("w", "session.switch") -- Closest equivalent to tmux's window/session tree.
bind("s", "session.switch")
bind("shift+9", "session.previous") -- (
bind("shift+0", "session.next") -- )
bind("shift+4", "session.rename") -- $
bind("ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- Rex has no tmux repeat-time timer. Enter this explicit repeat mode with
-- Ctrl+B r; Escape or Enter returns to normal typing. Plain sequences above
-- always work without entering the mode.
rex.mode("tmux-repeat", { exclusive = true })
bind("r", "client.mode.enter", { name = "tmux-repeat" })
rex.bind("tmux-repeat/escape", "client.mode.exit")
rex.bind("tmux-repeat/enter", "client.mode.exit")
rex.bind("tmux-repeat/o", "pane.focus_next")
rex.bind("tmux-repeat/n", "client.tab.next")
rex.bind("tmux-repeat/p", "client.tab.previous")
rex.bind("tmux-repeat/shift+9", "session.previous")
rex.bind("tmux-repeat/shift+0", "session.next")
for key, direction in pairs(directions) do
  rex.bind("tmux-repeat/" .. key, "pane.focus", { direction = direction })
  rex.bind("tmux-repeat/alt+" .. key, "pane.resize", { direction = direction, amount = 5 })
end

-- tmux's copy-mode-vi, smart Neovim handoff, status/border styling, mouse
-- options and TPM/resurrect/continuum plugins have no direct Rex equivalent.
