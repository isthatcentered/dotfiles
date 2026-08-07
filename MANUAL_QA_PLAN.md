# Manual QA plan: dotfiles manager

## Purpose

This plan validates `main.go` as a safety-critical configuration manager. Its primary release invariant is:

> The CLI must never modify, replace, truncate, or delete an existing source, regular destination, directory destination, wrong symlink, or broken symlink.

All tests use a disposable repository, a fake home directory, and dummy content. Never run the apply command against this repository's real `home/` tree or a real home directory.

The plan is based on the behavior and examples documented in `README.md`: direct-child `home/<package>/manage.json` discovery, strict manifests, `macos`/`linux` target selection, globbed sources, dry-run, absolute symlinks, conflict refusal, and idempotent reruns.

## Scope and risk priorities

| Priority | Meaning | Areas |
| --- | --- | --- |
| P0 | Release blocking | Isolation, dry-run immutability, preflight validation, refusal to overwrite, source integrity, correct links, partial-apply behavior |
| P1 | High confidence | Manifest and path validation, aliases, nested destinations, permissions, interruption, repeatability |
| P2 | Compatibility and usability | Output, unusual names, manifest discovery rules, platform parity |

Out of scope except where explicitly observed: automatic backup, rollback, obsolete-link removal, copying, templating, package installation, secret management, and moving the repository after installation. The CLI intentionally does not implement these features.

## Release invariants

Every test must preserve these invariants unless its expected result explicitly creates a new dummy symlink or target directory:

1. Source file bytes and source directory trees remain unchanged.
2. Existing destination objects remain unchanged, including their type, bytes, children, permissions, and symlink text.
3. A rejected plan creates no destination directories or links anywhere.
4. `--dry-run` performs no filesystem mutation.
5. A created destination is a symlink whose text is the absolute source path in the disposable repository.
6. No created symlink is broken at command completion.
7. A successful rerun is idempotent.
8. Only the selected platform target is inspected and changed.
9. Any normal preflight error is detected before the first link is created.
10. An unexpected apply-time failure may leave a valid subset of new links because rollback is not implemented, but it must not damage sources or pre-existing destinations.

## Required environments

Run the P0 and P1 cases on both:

- A supported macOS host using `macos`.
- A supported Linux host using `linux`.

Record OS version, architecture, filesystem type, Go version, commit or source archive identifier, and whether the filesystem is case-sensitive. Run P2 filename cases on at least one case-sensitive and one case-insensitive filesystem when both are available.

Do not run permission cases as `root`; root can bypass the intended filesystem restrictions.

## Mandatory sandbox setup

Start in the real repository root, but build only a binary. All CLI execution after that happens inside a disposable repository.

```sh
ORIGINAL_REPOSITORY=$PWD
QA_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-qa.XXXXXX")
export QA_ROOT
export QA_REPO="$QA_ROOT/repository"
export QA_BIN="$QA_ROOT/bin/dotfiles"
export REAL_HOME_FOR_QA="$HOME"
export HOME="$QA_ROOT/fake-home"
export XDG_CONFIG_HOME="$QA_ROOT/fake-home/.config"
export PLATFORM=macos # use linux on the Linux pass

mkdir -p "$QA_ROOT/bin" "$QA_REPO/home" "$HOME" "$QA_ROOT/targets" "$QA_ROOT/evidence"
go build -o "$QA_BIN" .
cd "$QA_REPO"
```

Before **every** invocation, run this guard. Do not proceed if it fails.

```sh
qa_guard() {
  test -n "$QA_ROOT" || return 1
  test "$PWD" = "$QA_REPO" || return 1
  test "$HOME" = "$QA_ROOT/fake-home" || return 1
  test "$QA_BIN" = "$QA_ROOT/bin/dotfiles" || return 1
  case "$QA_ROOT" in
    */dotfiles-qa.*) ;;
    *) return 1 ;;
  esac
}

qa_guard || { echo "QA sandbox guard failed" >&2; return 1 2>/dev/null || exit 1; }
```

Use the compiled binary exactly as the user-facing CLI is used:

```sh
qa_guard && "$QA_BIN" --dry-run "$PLATFORM"
qa_guard && "$QA_BIN" "$PLATFORM"
```

Never use `go run` in a directory containing real manifests, and never give a manifest an absolute target outside `$QA_ROOT` during QA.

### Reset and integrity helpers

The reset function refuses to operate unless the sandbox guard passes. It removes only disposable fixtures.

```sh
qa_reset() {
  qa_guard || return 1
  chmod -R u+rwX "$QA_REPO/home" "$QA_ROOT/targets" "$HOME" 2>/dev/null || true
  rm -rf "$QA_REPO/home" "$QA_ROOT/targets" "$HOME"
  mkdir -p "$QA_REPO/home" "$QA_ROOT/targets" "$HOME" "$QA_ROOT/evidence"
}

qa_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

qa_snapshot() {
  root=$1
  find "$root" -print | LC_ALL=C sort | while IFS= read -r path; do
    relative=${path#"$root"}
    if test -L "$path"; then
      printf 'link\t%s\t%s\n' "$relative" "$(readlink "$path")"
    elif test -f "$path"; then
      printf 'file\t%s\t%s\n' "$relative" "$(qa_hash "$path")"
    elif test -d "$path"; then
      printf 'dir\t%s\n' "$relative"
    else
      printf 'other\t%s\n' "$relative"
    fi
  done
}
```

The fixtures deliberately exclude newline characters in paths so the snapshot format remains unambiguous. For every negative or dry-run test:

```sh
qa_snapshot "$QA_REPO/home" >"$QA_ROOT/evidence/source.before"
qa_snapshot "$HOME" >"$QA_ROOT/evidence/home.before"
qa_snapshot "$QA_ROOT/targets" >"$QA_ROOT/evidence/targets.before"

# Run the test command here and record its status, stdout, and stderr.

qa_snapshot "$QA_REPO/home" >"$QA_ROOT/evidence/source.after"
qa_snapshot "$HOME" >"$QA_ROOT/evidence/home.after"
qa_snapshot "$QA_ROOT/targets" >"$QA_ROOT/evidence/targets.after"
diff -u "$QA_ROOT/evidence/source.before" "$QA_ROOT/evidence/source.after"
diff -u "$QA_ROOT/evidence/home.before" "$QA_ROOT/evidence/home.after"
diff -u "$QA_ROOT/evidence/targets.before" "$QA_ROOT/evidence/targets.after"
```

All three diffs must be empty. Also inspect permissions with the host's `stat` command in permission-specific cases; the portable snapshot checks types, link text, tree membership, and file content but not all metadata.

## Baseline README fixture

Create dummy equivalents of the README's Tmux, Neovim, and Ghostty examples. These names are safe because `HOME` is fake.

```sh
qa_reset
mkdir -p home/tmux home/neovim/nvim/lua home/ghostty
printf 'set -g mouse on\n' >home/tmux/.tmux.conf
printf '%s\n' '-- dummy init' >home/neovim/nvim/init.lua
printf '%s\n' '-- dummy module' >home/neovim/nvim/lua/dummy.lua
printf 'theme = dummy\n' >home/ghostty/config

cat >home/tmux/manage.json <<'JSON'
{"source":["./.tmux.conf"],"target":{"macos":"~","linux":"~"}}
JSON
cat >home/neovim/manage.json <<'JSON'
{"source":["./nvim"],"target":{"macos":"~/.config","linux":"~/.config"}}
JSON
cat >home/ghostty/manage.json <<'JSON'
{"source":["./config"],"target":{"macos":"~/Library/Application Support/com.mitchellh.ghostty","linux":"~/.config/ghostty"}}
JSON
```

On Linux, the Ghostty destination differs as documented. All expected paths below must be interpreted for the selected platform.

## Test execution protocol

For each case:

1. Run `qa_reset`, create only the fixture required by the case, and run `qa_guard`.
2. Capture pre-test snapshots for the source tree, fake home, and absolute target tree.
3. Capture the command, exit status, stdout, and stderr in the evidence directory.
4. Check the exact expected objects with `test`, `readlink`, `qa_hash`, and `find`.
5. Capture post-test snapshots. For successful apply cases, compare source snapshots and separately account for every destination addition. For rejected and dry-run cases, require all snapshots to be identical.
6. Record Pass, Fail, or Blocked. A surprising but harmless behavior is not an automatic pass; compare it to the documented contract and release invariants.

A convenient capture pattern is:

```sh
set +e
qa_guard && "$QA_BIN" --dry-run "$PLATFORM" \
  >"$QA_ROOT/evidence/stdout" 2>"$QA_ROOT/evidence/stderr"
status=$?
set -e
printf '%s\n' "$status" >"$QA_ROOT/evidence/status"
```

## P0 test cases: corruption prevention and core behavior

### QA-P0-01 — Sandbox guard rejects unsafe context

- Setup: baseline fixture, then temporarily `cd "$ORIGINAL_REPOSITORY"` without changing any other variable.
- Action: run `qa_guard && "$QA_BIN" "$PLATFORM"`.
- Expected: guard returns nonzero; binary is not invoked; real repository and real home are unchanged.
- Repeat with `HOME="$REAL_HOME_FOR_QA"`, then immediately restore fake `HOME`.

### QA-P0-02 — Help is read-only

- Action: run `"$QA_BIN" --help` in an empty disposable repository.
- Expected: exit 0; usage and `--dry-run` appear on stderr; stdout is empty; all snapshots match.

### QA-P0-03 — Baseline dry-run is completely read-only

- Setup: baseline README fixture; its target directories must not exist.
- Action: run `"$QA_BIN" --dry-run "$PLATFORM"`.
- Expected: exit 0; one `would link` line per Tmux, Neovim, and Ghostty entry; no target directory or symlink is created; all snapshots match.
- Verify every source shown in output is absolute and below `$QA_REPO/home`.

### QA-P0-04 — Baseline apply creates only the intended links

- Setup: baseline README fixture.
- Action: run `"$QA_BIN" "$PLATFORM"`.
- Expected: exit 0 and three `linked` lines. Tmux is linked in fake `HOME`; Neovim is a directory symlink under fake `.config`; Ghostty follows the platform-specific README target.
- Verify `readlink` returns the absolute dummy source path, the source snapshot is unchanged, and reading `nvim/lua/dummy.lua` through the destination returns the dummy bytes.
- Verify `find "$HOME" -type l` lists exactly the three expected links.

### QA-P0-05 — Correct links are idempotent

- Setup: complete QA-P0-04 and snapshot the full sandbox fixture.
- Action: run the same apply command twice more.
- Expected: both exit 0; output contains only `exists` lines; the full fixture snapshot does not change on either run.

### QA-P0-06 — Mixed existing and missing destinations

- Setup: baseline fixture; pre-create only the correct Tmux symlink.
- Action: dry-run, then apply.
- Expected: dry-run prints Tmux as `exists` and the other entries as `would link`; apply prints Tmux as `exists` and creates only the missing links. Existing symlink text and metadata remain unchanged.

### QA-P0-07 — Existing regular file is never replaced

- Setup: two planned dummy sources sorted so `a.config` would be created first and `z.config` collides with an existing destination file containing `DO NOT CHANGE`.
- Action: apply.
- Expected: exit nonzero; error names `z.config` and says it is not a symlink; stdout is empty; `a.config` is not created; the existing file's hash and metadata are unchanged.

### QA-P0-08 — Existing directory is never replaced

- Setup: as QA-P0-07, but make `z.config` a directory containing nested dummy files.
- Expected: exit nonzero before any link; the directory and every child remain unchanged.

### QA-P0-09 — Wrong symlink is never replaced

- Setup: make the destination a symlink to a second in-sandbox dummy file.
- Expected: exit nonzero; error shows the resolved current target and intended source; symlink text remains exactly unchanged; neither target file changes.

### QA-P0-10 — Broken destination symlink is never replaced

- Setup: make the destination a symlink to `$QA_ROOT/missing-object`.
- Expected: exit nonzero with a broken-symlink error; the original broken symlink text remains unchanged; no other planned link is created.

### QA-P0-11 — A later invalid manifest prevents all changes

- Setup: package `a-valid` has a valid missing destination; package `z-invalid` has malformed JSON.
- Action: apply.
- Expected: exit nonzero, stdout empty, no target directory or link from `a-valid`, and all snapshots match.

### QA-P0-12 — A later unmatched source prevents all changes

- Setup: valid first package plus a later package whose `./missing-*` pattern matches nothing.
- Expected: exit nonzero before mutation and all snapshots match.

### QA-P0-13 — A later unusable target prevents all changes

- Setup: valid first package plus a second target nested beneath an existing regular file, all inside `$QA_ROOT/targets`.
- Expected: exit nonzero before mutation; the valid first destination does not appear; blocker file remains unchanged.

### QA-P0-14 — Cross-package destination collision is atomic at preflight

- Setup: two packages contain different files both named `config` and select the same target directory.
- Expected: exit nonzero with `claimed by both`; neither destination is created and both sources retain their hashes.

### QA-P0-15 — Within-package basename collision is rejected

- Setup: one package contains `one/config` and `two/config`, both listed as sources for one target.
- Expected: same safety result as QA-P0-14.

### QA-P0-16 — Target symlink aliases cannot hide a collision

- Setup: create `$QA_ROOT/targets/real`, and `alias -> real`; two different `config` sources target each path.
- Expected: collision is detected using canonical destinations; no link is created through either spelling.

### QA-P0-17 — Nested planned destinations are rejected

- Setup: plan a directory link at `target/nvim` and a second link at `target/nvim/plugin`.
- Expected: exit nonzero with a nested-destination error; no `target/nvim` link is created; critically, no `plugin` link appears inside the source `nvim` directory.

### QA-P0-18 — Canonical nested destinations through an alias are rejected

- Setup: repeat QA-P0-17 with the parent target addressed through `alias -> real` and the child through `real`.
- Expected: rejection before mutation regardless of lexical sort order.

### QA-P0-19 — Source traversal is rejected

- Run separate fixtures with source patterns `../outside`, `../../outside`, and an absolute `$QA_ROOT/outside` path.
- Expected: each exits nonzero with the offending pattern; in-sandbox outside file and all destinations remain unchanged.

### QA-P0-20 — Source symlink escaping its package is rejected

- Setup: package source `external.config` is a symlink to a dummy file elsewhere under `$QA_ROOT` but outside the package.
- Expected: exit nonzero with `source escapes its package`; external dummy content and all destinations remain unchanged.

### QA-P0-21 — Broken source symlink is rejected

- Setup: matched source is a symlink to an absent in-sandbox path.
- Expected: exit nonzero with `resolve source`; no target directory is created.

### QA-P0-22 — Source contents and metadata survive a successful apply

- Setup: sources include an empty file, multiline UTF-8 file, executable file, read-only file, and nested directory. Record hashes and host-specific modes before apply.
- Expected: source hashes, modes, modification times, and tree membership are identical afterward. The CLI creates links only; it does not rewrite sources.

### QA-P0-23 — Writing through a directory link has explicit consequences

- Setup: apply the dummy Neovim directory link.
- Action: write a new dummy file through `$HOME/.config/nvim/`.
- Expected: the new file appears in the disposable repository source directory because the destination is a symlink. Record this as expected symlink semantics, not CLI corruption; remove it before the next case.
- Release check: README users must be able to understand that applications can modify repository files through these links.

### QA-P0-24 — Absolute target under the sandbox works without `HOME`

- Setup: target is `$QA_ROOT/targets/absolute`; save fake `HOME`, unset `HOME` only for the command.
- Expected: dry-run and apply succeed and use the absolute target. Restore fake `HOME` immediately.

### QA-P0-25 — `~` never resolves to the real home in QA

- Setup: baseline fixture and exported fake `HOME`.
- Expected: every planned destination is under `$QA_ROOT/fake-home`; search output for `$REAL_HOME_FOR_QA` and require no match; real-home sentinel hashes taken before the QA session remain unchanged.
- Do not recursively snapshot the real home. Use only preselected, non-sensitive sentinels if this independent check is desired.

### QA-P0-26 — Platform selection touches only one target

- Setup: one source with distinct absolute macOS and Linux targets under `$QA_ROOT`.
- Action: run selected platform.
- Expected: only its target is created. The unselected path may be malformed or blocked and must not be inspected because only the selected target is relevant.
- Repeat with the other platform in a fresh sandbox.

### QA-P0-27 — Apply-time permission failure is contained and documented

- Setup: two valid destinations: an alphabetically first writable target and a second target whose existing parent is changed to mode `0555` after fixture creation. Keep both under `$QA_ROOT` and do not run as root.
- Action: apply, then immediately restore owner-write permission in a trap or cleanup step.
- Expected: nonzero exit. Depending on action ordering, earlier links may remain because rollback is intentionally absent. Every remaining link must be valid and point into `$QA_REPO`; no source or pre-existing object changes.
- Release check: this observed behavior must remain consistent with the README's non-transactional limitation. Treat silent success or any overwritten object as a P0 failure.

### QA-P0-28 — Recovery after partial apply is safe

- Setup: continue from QA-P0-27; restore permissions without removing any valid link.
- Action: dry-run, then apply.
- Expected: dry-run accurately reports retained links as `exists` and missing links as `would link`; apply completes; subsequent run is fully idempotent.

### QA-P0-29 — Destination appears after preflight

- Setup: create thousands of dummy planned links in one in-sandbox target. In a background watcher, wait for the first link and then create a conflicting regular file at a much later destination, also in the sandbox.
- Action: apply and stop the watcher afterward.
- Expected: the CLI must never replace the racing regular file. It may stop with a nonzero `file exists` error after creating an earlier subset. Sources remain unchanged. If the race is not hit, record Inconclusive and retry; do not mark Pass.

### QA-P0-30 — Process interruption leaves only intact objects

- Setup: create a large dummy plan under `$QA_ROOT/targets`.
- Action: start apply in the background, wait until at least one link exists, send `TERM`; if it completes too quickly, enlarge the fixture and retry.
- Expected: process exits due to interruption or completes normally. There are no temporary files because the CLI uses direct symlink creation. Every created entry is a valid symlink to an unchanged source; pre-existing objects remain unchanged. A rerun safely completes the plan.

## P1 test cases: validation depth and filesystem behavior

### Arguments and output

| ID | Fixture/action | Expected result |
| --- | --- | --- |
| QA-P1-01 | No platform argument | Nonzero; usage error; no repository read or mutation |
| QA-P1-02 | Extra positional argument | Nonzero; usage error; no mutation |
| QA-P1-03 | `windows` | Nonzero; unsupported OS names `windows`; no mutation |
| QA-P1-04 | Unknown flag | Nonzero; flag parser message on stderr and final error; no mutation |
| QA-P1-05 | `macos --dry-run` | Nonzero usage error because flags must precede the platform; no mutation |
| QA-P1-06 | `--dry-run -- macos` | Successful dry-run; separator is accepted by Go's flag parser |
| QA-P1-07 | Successful output ordering | Destinations within each status group are lexically ordered; `exists` lines precede action lines |
| QA-P1-08 | Paths containing spaces and Unicode | Output preserves the paths and links resolve correctly; no shell splitting occurs |
| QA-P1-09 | Capture stdout and stderr separately | Success uses stdout and empty stderr; CLI failures have `error:` on stderr and nonzero status |

### Manifest discovery

| ID | Fixture/action | Expected result |
| --- | --- | --- |
| QA-P1-10 | No `home/` directory | Nonzero `no manage.json files found`; no mutation |
| QA-P1-11 | Empty `home/` | Same as QA-P1-10 |
| QA-P1-12 | Regular files directly under `home/` | Ignored; they are not packages |
| QA-P1-13 | Package directory without `manage.json` plus valid package | Unmanaged directory is ignored; valid package applies |
| QA-P1-14 | Manifest only at `home/a/nested/manage.json` | Not discovered; direct-child depth rule holds |
| QA-P1-15 | Valid package directory symlink inside `home/` pointing to an in-sandbox package | Discovered; source must still remain inside the resolved package |
| QA-P1-16 | Broken package directory symlink plus valid package | Entire run fails before mutation and names broken package |
| QA-P1-17 | `manage.json` is a directory | Invalid/read error before mutation |
| QA-P1-18 | Unreadable manifest, run as non-root | Permission error before mutation; restore permissions after test |
| QA-P1-19 | Manifest is a symlink to an in-sandbox valid JSON file | Record actual behavior; currently expected to load successfully. Confirm no path leaves `$QA_ROOT` |

### Manifest JSON and schema

For each row, include one earlier valid package to prove full-plan validation prevents partial changes. Expected status is nonzero, stdout is empty, the error identifies the manifest, and all snapshots match.

| ID | Invalid manifest variant | Required error concept |
| --- | --- | --- |
| QA-P1-20 | Empty document | Invalid JSON |
| QA-P1-21 | `{` | Invalid JSON |
| QA-P1-22 | Valid object followed by `{}` | Multiple/trailing JSON value |
| QA-P1-23 | Unknown top-level field such as `typo` | Invalid JSON / unknown field |
| QA-P1-24 | Missing, `null`, or empty `source` | At least one source pattern required |
| QA-P1-25 | `source` is a string rather than array | Invalid JSON type |
| QA-P1-26 | `source` contains a number, object, boolean, or null | Invalid JSON type |
| QA-P1-27 | Missing or `null` `target` | OS targets required |
| QA-P1-28 | `target` is a string or array | Invalid JSON type |
| QA-P1-29 | Selected platform value is non-string, missing, or empty | Invalid type or no configured selected target |
| QA-P1-30 | Relative target `relative/path` | Must start with `~` or `/` |
| QA-P1-31 | Named-user target `~someone/config` | Named-user home unsupported |
| QA-P1-32 | Environment-variable target `$HOME/config` | Not expanded; rejected as relative |
| QA-P1-33 | Valid selected platform plus unknown map key | Accepted; map keys other than the selected platform do not affect the plan |

### Source matching

| ID | Fixture/action | Expected result |
| --- | --- | --- |
| QA-P1-36 | Exact file and exact directory | Both linked by basename |
| QA-P1-37 | `./*.config` with multiple files | Every match linked; output/destination order deterministic |
| QA-P1-38 | `?` and character-range globs | Matches follow Go filepath glob semantics |
| QA-P1-39 | Glob does not recursively cross `/` | Nested file is not matched unless directory itself is matched |
| QA-P1-40 | Overlapping exact and glob patterns select same source | One destination and one output line only |
| QA-P1-41 | Empty source pattern | Rejected as non-local / invalid source pattern |
| QA-P1-42 | Malformed glob `[` | Rejected with invalid-pattern error before mutation |
| QA-P1-43 | Unmatched exact path or glob | Rejected before mutation |
| QA-P1-44 | Source symlink resolving to another path inside same package | Accepted; destination symlink points to the source path spelling, and resolution reaches the internal target |
| QA-P1-45 | Source named `manage.json` | Record that it can be managed like any other source; destination is only a link and original manifest is unchanged |
| QA-P1-46 | Source `.` | Record actual behavior and assess usability; it must never cause a source write or destination overwrite |

### Targets, aliases, and permissions

| ID | Fixture/action | Expected result |
| --- | --- | --- |
| QA-P1-47 | Target `~` | Expands exactly to fake `HOME` |
| QA-P1-48 | Target `~/path with spaces` | Missing parents created and link correct |
| QA-P1-49 | Target with repeated separators, `.` components, or trailing slash | Clean destination and correct link |
| QA-P1-50 | Target `~/../sandbox-sibling`, with fake home directly under `$QA_ROOT` | Remains within `$QA_ROOT`; record cleaned destination. This proves `~` expansion is not a home-containment policy |
| QA-P1-51 | Existing target directory symlink to an in-sandbox real directory | Link is created through alias and physically appears in real directory |
| QA-P1-52 | Dangling target ancestor plus valid package | Entire run rejected before mutation |
| QA-P1-53 | Target ancestor is a regular file | Entire run rejected before mutation |
| QA-P1-54 | Target directory is not searchable/readable for current non-root user | Nonzero before or during apply; no overwrite and sources unchanged |
| QA-P1-55 | Restrictive `umask 077` with missing target parents | New parents do not gain broader permissions than allowed by umask; links still function |
| QA-P1-56 | Existing correct relative destination symlink | Accepted if it resolves to the intended source; link text remains relative and unchanged |
| QA-P1-57 | Existing symlink reaches source through an in-sandbox alias | Accepted when resolved targets are equal; original symlink text remains unchanged |

## P2 test cases: compatibility and usability

| ID | Fixture/action | Expected result |
| --- | --- | --- |
| QA-P2-01 | Empty source file | Link succeeds; reading through link yields zero bytes |
| QA-P2-02 | Large dummy file (for example 100 MiB sparse file) | Apply time does not scale with content copying; source size/hash unchanged |
| QA-P2-03 | Deep source directory tree | One directory symlink is created; no child-by-child links |
| QA-P2-04 | File and directory names with spaces, tabs, leading dots, Unicode, `#`, and shell metacharacters | Correct links without shell interpretation; output is understandable |
| QA-P2-05 | Names differing only by case | On case-sensitive FS, distinct links; on case-insensitive FS, collision or filesystem error must not overwrite either source |
| QA-P2-06 | Very long but valid in-sandbox path | Clear success or OS error; no earlier pre-existing object changes |
| QA-P2-07 | Path exceeding OS component/path limit | Nonzero with OS error and no preflight mutation |
| QA-P2-08 | Read-only source file and tree | Links can be created if traversal permits; sources remain read-only |
| QA-P2-09 | Repository path itself contains spaces and Unicode | Absolute symlink text is correct and links resolve |
| QA-P2-10 | Move disposable repository after apply | Links become broken as documented; CLI does not auto-repair because it can no longer read original repo. Move it back and confirm recovery |
| QA-P2-11 | Change source content after apply | Destination immediately reflects the dummy source change, confirming symlink behavior |
| QA-P2-12 | Remove a source after apply | Destination becomes broken; rerun rejects the missing source and never deletes or rewrites the destination |
| QA-P2-13 | Remove a package from the manifest after apply | Obsolete link remains, matching the documented lack of removal |
| QA-P2-14 | Run two apply processes concurrently against the same missing plan | At most one creates each link; the other may fail with `file exists`; all resulting links are correct and no object is overwritten |

## Optional adversarial race test

This test probes a time-of-check/time-of-use boundary and must remain entirely inside `$QA_ROOT`.

1. Create a target parent `$QA_ROOT/targets/swap` and a second directory `$QA_ROOT/targets/alternate`.
2. Build a very large plan whose destinations are below `swap` so validation/application lasts long enough to observe.
3. In a background process, rename `swap` to another in-sandbox name and replace it with a symlink to `alternate` during apply.
4. Verify no path outside `$QA_ROOT` was ever referenced.

Expected safety assessment: the command must never overwrite an existing object, but links may be created beneath the swapped in-sandbox parent because original destination paths are used after canonical preflight. Any observed redirection outside the canonical target would be a security finding. This is an adversarial local race, not a normal functional pass criterion, but its result should inform the threat model.

## Automated checks that accompany manual QA

Run these against the exact source being released:

```sh
cd "$ORIGINAL_REPOSITORY"
go test ./...
go test -race ./...
go vet ./...
```

Manual QA is not a substitute for these checks. Conversely, automated temporary-directory tests do not replace the cross-platform, permissions, interruption, output, and operator-safety exercises above.

## Evidence record

For every test, retain:

```text
Test ID:
Date / tester:
Source revision or archive hash:
OS / version / architecture:
Filesystem and case sensitivity:
Go version:
Exact fixture:
Exact command:
Exit status:
stdout:
stderr:
Before/after snapshot diff:
Additional symlink and metadata checks:
Result: Pass / Fail / Blocked / Inconclusive
Defect link and severity, if any:
Notes:
```

For race cases, `Inconclusive` means the timing condition was not reached; it is not a pass.

## Release gate

A release is acceptable only when:

- Every P0 case passes on macOS and Linux, except QA-P0-27 where the documented valid-subset behavior is the expected result.
- Every P1 case passes, or a deviation is explicitly documented and approved with no corruption risk.
- No rejected or dry-run case changes any snapshot.
- No case changes a source except QA-P0-23 and QA-P2-11, where the tester deliberately writes through a dummy link to demonstrate symlink semantics.
- No existing destination object is replaced or modified in any case.
- Every unexpected failure leaves only unchanged pre-existing objects plus, where rollback is unavailable, valid newly-created symlinks.
- Test evidence identifies the exact released source.

Any source-content change caused by the CLI, overwritten destination, mutation during dry-run, link outside the sandbox, or preflight error after an unrelated link was created is an immediate P0 release blocker.

## Safe cleanup

Close any shell that still has the fake `HOME`, or restore it explicitly. Delete only the guarded sandbox:

```sh
cd "$ORIGINAL_REPOSITORY"
HOME=$REAL_HOME_FOR_QA
export HOME
case "$QA_ROOT" in
  */dotfiles-qa.*) rm -rf "$QA_ROOT" ;;
  *) echo "Refusing cleanup: unexpected QA_ROOT" >&2; exit 1 ;;
esac
unset QA_ROOT QA_REPO QA_BIN REAL_HOME_FOR_QA XDG_CONFIG_HOME PLATFORM
```
