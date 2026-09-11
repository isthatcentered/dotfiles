# To-do UI prototype

The Focus layout: a Triaged/Backlog queue with an optional task preview on the
right. The preview starts visible each time you open the queue. Press `Ctrl-p`
to toggle it. The queue and preview have equal widths. The queue keeps that
same width and position when the preview is hidden.
The preview shows a bold task title and its description in the normal text color.
This remains a UI prototype with no plugin dependencies.

Moving to a window outside the manager closes it and keeps focus on that window.
Switching buffers inside the queue or preview (for example with `Ctrl-o`)
also closes it and shows the destination buffer in the window you opened it from.
You can move between the queue, preview, and task editor without closing it.
If you leave while editing a task, the unfinished edit resumes when you reopen.

Press `<leader>TT` to toggle the manager (`Space`, `T`, `T` in your config).
Unfinished task edits are preserved when toggling it closed.
You can also open it with:

```vim
:TodoPrototype
```

For an isolated preview, run from the dotfiles root:

```sh
nvim -u home/nvim/nvim/lua/isthatcentered/todo-prototype.nvim/scripts/minimal_init.lua
```

Pass a code file after that command to try the queue alongside your work.
Neovim 0.11+; terminal minimum 60 × 18, preferably 100 × 25 or larger.

## Use the queue

| Key | Action |
| --- | --- |
| `Tab` in the queue | Cycle Queue (Triaged/Backlog) → Done → Discarded → Queue |
| `j` / `k`, up / down | Select next / previous task in the current screen |
| `h` / `l` | Jump to triaged / backlog |
| `gg` / `G` | First / last task |
| `x` | Move to Done; in Done, restore to the previous list and position |
| `d` in the queue | Move to Discarded; in Discarded, restore to the previous list and position |
| `m` | Move selected task to the end of the other list |
| `J` / `K` | Reorder selected task within its list |
| `a` | Add to the selected working list; from Done, Discarded, or an empty screen, add to Backlog |
| `Enter` / `e` | Edit title and full multiline description |
| `Ctrl-p` | Show / hide the preview |
| `Ctrl-w w` | Focus another pane for scrolling |
| `Ctrl-d` / `Ctrl-u` | Scroll the focused pane |
| `?` | Show shortcuts |
| `q` / `Esc` | Close and return to your code |

In the editor, line 1 is the title, followed by
an optional blank line and the description. Use ordinary Neovim editing;
`:w` or `Ctrl-s` saves and closes. `:q!` or normal-mode `q` / `Esc` closes
the editor without saving.

New task files start empty. Triaged holds several tasks chosen from the backlog for the current batch of work.
List order expresses priority, while the Focus pane shows the task selected in the UI.
Marking a task done removes it from Triaged/Backlog and appends it to Done.
The queue selects the next remaining task. Press `Tab` in the queue to cycle
through Queue, Done, and Discarded. Each screen remembers its selection. Restoring a task
with `x` moves it back to its previous list, as close as possible to its old position.
Press `d` in the queue to discard a task. It disappears from its current list and
appears in Discarded. Press `d` there to restore it, including its completion
status and its place in its previous list. Discarding never permanently deletes it.
Adding a task from Done or Discarded opens the working queue after saving it.

In the queue, `Ctrl-i` shares the `Tab` mapping; in the preview it remains a jump key.

## Storage

Opening the manager reads or creates `todo.jsonl` in the current Neovim working
directory (including `:lcd` / `:tcd`). It does not search parent directories.
The path stays fixed while the manager is open; closing and reopening resolves
the current directory again and reloads the file. Drafts are kept separately per
path in memory, and are not saved until you explicitly save the editor.

Every task change saves immediately: adding, editing,
reordering, moving between Triaged and Backlog, completing, discarding, and restoring.
Navigation, preview toggling and cancelled edits do not write the file.
There are no automatic sample tasks or sample-reset command.

Each line is one versioned task object. Relative line order within a status defines
its display order; multiline descriptions are escaped within a single JSON line.
For example:

```jsonl
{"version":1,"id":1,"title":"Ship the UI","description":"Review layout\nTry keyboard navigation","status":{"kind":"triaged"}}
{"version":1,"id":2,"title":"Investigate storage","description":"","status":{"kind":"backlog"}}
{"version":1,"id":3,"title":"Finished task","description":"","status":{"kind":"done","restore":{"kind":"triaged"},"index":1}}
{"version":1,"id":4,"title":"Discarded task","description":"","status":{"kind":"discarded","restore":{"kind":"backlog"},"index":2}}
```

The tagged `status` is the only source of completion and column information:

- `backlog` and `triaged` have only `kind`.
- `done` contains its previous working status in `restore` and its 1-based `index`.
- `discarded` contains its previous working or done status and its `index`.
  Discarding a done task nests the done status, retaining both restoration steps.

There is no separate `done` boolean or `lane` that can contradict the status.
IDs are unique positive integers, allocated above the highest existing ID.
Titles must be nonempty single lines; descriptions are strings.
Unknown fields, versions, duplicate IDs, and impossible restoration states are rejected.
Blank lines, CRLF and files without a final newline are accepted.

`model.lua` owns validation and task transitions. `session.lua` applies a command
to a copy, asks a repository to save it, and publishes it only after success.
`repository.lua` implements `load()` / `save(tasks)` and contains all filesystem
access. The UI only calls the session; tests can substitute a repository.

Writes use a temporary file in the same directory, flush it, and atomically rename
it over the original while holding `todo.jsonl.lock`. Existing permissions are
preserved; new files are private (`0600`). Cooperating plugin instances serialize
writes and compare against the loaded bytes to detect stale data. On a conflict,
close and reopen to reload before retrying. External editors do not honor this
lock, so simultaneous external writes during a save cannot be fully prevented.

Invalid files are left untouched with a path/line error. Failed saves retain the
previous task state and leave the editor draft available. Symlinks and directories
at the task file path are rejected. A process killed during a save may leave a
lock or temporary file: remove a leftover `todo.jsonl.lock` only after confirming
no manager is writing, then reopen. Unsaved editor drafts do not survive a normal
Neovim restart.

## Tests

From this plugin directory:

```sh
make test
```

Or from the dotfiles root:

```sh
nvim --headless -u NONE -l home/nvim/nvim/lua/isthatcentered/todo-prototype.nvim/tests/run.lua
```

The dependency-free suite uses temporary directories, injected filesystem failures,
and actual manager mappings. It covers round trips, process restarts, ordering,
restoration, malformed data, concurrent sessions, write failures, and cwd isolation.
