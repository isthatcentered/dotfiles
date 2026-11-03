# THROWAWAY — agent feedback behavior

Open `agent-feedback.prototype.html` directly in a browser; no server or dependencies.
No Neovim configuration has been changed. Delete this prototype after the behavior is agreed.

## Question

Does selecting code → attaching private feedback → collecting JSON and clearing the session
feel right before replacing the existing `<leader>R` TODO workflow?
This is a behavioral prototype, implemented in HTML at the user's request, not a full Vim emulator
or a set of alternate visual layouts. All feedback lives in memory.

## Proposed first pass

- `v` / `V`: characterwise / linewise selection, default inclusive Visual semantics.
- `<leader>R`: prompt for a single-line comment; Normal mode means current line.
- Enter saves; Escape or blank input cancels. Saved comments never touch source or undo history.
- Amber ranges and a `!` sign on the first line; overlapping comments remain separate.
- `<leader>rr`: quickfix-style list across files, select a location to jump.
- `<leader>rc`: export all pending comments, then purge the exported comments and decorations
  only after successful clipboard copy. Browser clipboard denial has an explicit manual-copy fallback.
- JSON: project-relative paths, 1-based lines and UTF-8 byte columns, exclusive end positions.
  Whole lines end at the next line's column 1, possibly the EOF boundary.
- Position at collection time, not the original line number. No tags or persistence.

The browser-only insertion scenario models whole-line insertion using start forward gravity
and end backward gravity. Arbitrary edits, range deletion, undo, buffer wipe/unload and block
selections are deliberately not simulated. The final implementation must decide those policies;
do not mistake this small simulator for a complete editor.

## Grounding

Installed Neovim: v0.12.6. Source inspected with `view-source-code` / Robert at the matching tag:

- [Visual selection semantics](https://github.com/neovim/neovim/blob/v0.12.6/runtime/doc/visual.txt)
- [Extmark positions, signs, range ends and gravity](https://github.com/neovim/neovim/blob/v0.12.6/runtime/doc/api.txt)
- [Extmark functional examples](https://github.com/neovim/neovim/blob/v0.12.6/test/functional/api/extmark_spec.lua)
- [Default vim.ui.input implementation](https://github.com/neovim/neovim/blob/v0.12.6/runtime/lua/vim/ui.lua)

Current workflow is `../lua/isthatcentered/review.lua` and remains untouched.
Browser controls and file tabs are a harness; the final Neovim implementation need not add UI chrome.

## Validation

Manually exercised in the HTML renderer at desktop and narrow widths: save, cancellation,
multiple files, list navigation, moving ranges, a three-byte euro character, denied clipboard
access with manual clearing, simulated successful copying, and session reset. JavaScript syntax
checked with Node. A clean headless Neovim session confirmed that adding decorations does not
set `modified`, insertion above the start shifts the range, insertion at an exclusive end stays
outside the range, and namespace clearing removes the marks.

## Verdict

Pending user trial. Decide whether single-line input, character-accurate ranges, and collect-and-clear
feel right, then iterate or replace the real workflow. Do not ship the HTML simulator as production code.
