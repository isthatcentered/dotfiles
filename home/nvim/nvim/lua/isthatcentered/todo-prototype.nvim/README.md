# To-do manager

One Kanban board: **Backlog → Active → Done**, with equal-width columns and an
optional right sidebar showing the selected task's ID, title, and description.
The preview heading is `#id - title`; IDs appear only in the preview.
The board uses Acid's purple and yellow palette, a very pale purple background,
a white focused column, rounded borders, and full-height separators.

Press `<leader>TT` (`Space`, `T`, `T` in this config) to toggle the manager,
or use `:TodoPrototype`. This is the only manager view; there are no alternate
queue, completed, or deleted-task screens.

| Key | Action |
| --- | --- |
| `h` / `l`, left / right | Select the adjacent column, starting at its first task |
| `j` / `k`, up / down | Select a task within the column |
| `gg` / `G` | First / last task |
| `H` / `L` | Move to the top of the left / right column and follow the task |
| `J` / `K` | Reorder within the column |
| `a` | Add a task at the top of the selected column |
| `e` | Edit the title and full description |
| `d` | Delete the task: retain its record, hide it from the board |
| `u` | Undo the last saved change during this opening, including deletion |
| `p` / `Enter` | Show / hide the sidebar preview (initially hidden) |
| `Ctrl-d` / `Ctrl-u` | Scroll the preview down / up |
| `?` | Show shortcuts |
| `q` / `Esc` | Close and return to your code |

The editor uses line 1 for the title and the remaining lines for the description,
with an optional blank line between them. `:w` or `Ctrl-s` saves and closes.
`:q!` or normal-mode `q` / `Esc` cancels. The former queue shortcuts `Tab`, `m`,
`x`, and `Ctrl-p` are no longer manager mappings.

Moving to an external window closes the manager and keeps focus there. Switching
buffers inside the board or preview also closes it and displays the destination
in the original window. Leaving while editing preserves the draft in memory;
reopening the same directory resumes it. Drafts and undo history do not survive
Neovim restarts. Undo history resets when the manager is reopened.

Neovim 0.11+; minimum terminal size 60 × 19. At 110 columns and above, the preview
sits beside the board; on smaller terminals it overlays the right edge. Every
column remains equal in width with or without the preview. Long descriptions can
be scrolled without leaving the selected task.

For an isolated instance, run from the dotfiles root:

```sh
nvim -u home/nvim/nvim/lua/isthatcentered/todo-prototype.nvim/scripts/minimal_init.lua
```

## Storage and migration

Opening reads or creates `todo.jsonl` in the exact current Neovim working directory
(including `:lcd` / `:tcd`). It does not search ancestors. The path stays fixed
until the manager closes; reopening reloads disk and resolves the directory again.
New files are empty. Task changes and undo save immediately; navigation, preview
controls, and cancelled edits do not write.

Each line is a version 2 task. Relative line order within a status defines display
order. Descriptions contain escaped newlines within their JSON line:

```jsonl
{"version":2,"id":1,"title":"Plan the release","description":"Review scope\nChoose the next step","status":"backlog"}
{"version":2,"id":2,"title":"Ship the UI","description":"","status":"active"}
{"version":2,"id":3,"title":"Finished task","description":"","status":"done"}
{"version":2,"id":4,"title":"Deleted task","description":"","status":"discarded"}
```

`status` is the only source of column and deletion state. There are no completion
flags, separate column fields, or nested restoration statuses that can disagree.
Deleted tasks never appear in the manager; `u` can restore a deletion during the
same opening. IDs are unique positive safe integers, allocated above all existing
IDs, including deleted tasks. Titles must be nonempty single lines; descriptions
must be strings. Unknown fields, versions, invalid statuses, and duplicate IDs
are rejected. Blank lines, CRLF, and missing final newlines are accepted.

Version 1 files migrate automatically on opening. The entire file is validated
first, then copied byte for byte to an adjacent `todo.jsonl.v1-backup.XXXXXX` file
before atomic replacement. `triaged` becomes `active`; the other statuses keep
their meaning. Obsolete restoration positions are removed. IDs, titles,
descriptions, deleted records, and relative order are preserved. Empty files need
no migration. Already migrated files are not rewritten on opening.

`model.lua` owns validation and transitions; `session.lua` publishes a new snapshot
only after the repository saves it. `repository.lua` owns filesystem access,
validation at the disk boundary, and migration. `views.lua` builds the board and
sidebar; `theme.lua` applies the palette and follows Acid variant changes.

Writes use a flushed temporary file in the same directory and atomic rename while
holding `todo.jsonl.lock`. Existing permissions are preserved; new files are
private (`0600`). Cooperating instances compare loaded bytes to detect concurrent
changes. On a conflict, close and reopen before retrying; unfinished editor text
is preserved. External editors do not honor the lock, so simultaneous external
writes cannot be fully prevented. An old plugin instance cannot overwrite a file
that has since been migrated: its loaded-byte check rejects the save.

Invalid files are left untouched with a path/line error. Failed saves retain the
previous task state. Task-file symlinks and directories are rejected. A process
killed during a save may leave a lock or temporary file; remove a stale lock only
once no manager is writing. Migration backups remain available alongside the file.

## Tests

From this plugin directory, run `make test`, or from the dotfiles root:

```sh
nvim --headless -u NONE -l home/nvim/nvim/lua/isthatcentered/todo-prototype.nvim/tests/run.lua
```

The dependency-free suite exercises actual manager mappings, persistence across
processes, all board transitions, hidden deletion, undo, drafts, conflicts,
column geometry, preview wrapping and scrolling, migration, and injected disk
failures using temporary directories.
