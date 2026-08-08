# Dotfiles manager

This repository contains a small Go program that installs configuration files by creating symbolic links from your home directory back into this repository.

It deliberately does one job: read package manifests from `home/*/manage.json`, select the targets for `macos` or `linux`, and link every matching source into every selected target directory. It does not copy files, install applications, manage secrets, or modify an existing destination.

## Requirements

- Go 1.23 or newer
- macOS or Linux

Run commands from the repository root.

## Repository layout

Each direct child of `home/` is an independently named package. The package name is only for humans; it does not affect the destination path.

```text
.
├── go.mod
├── main.go
└── home/
    ├── tmux/
    │   ├── manage.json
    │   └── .tmux.conf
    ├── neovim/
    │   ├── manage.json
    │   └── nvim/
    │       ├── init.lua
    │       └── lua/
    └── ghostty/
        ├── manage.json
        └── config
```

The manager only discovers manifests at this depth:

```text
home/<package>/manage.json
```

Names such as `tmux`, `neovim`, and `ghostty` are conventional. Any directory name is valid.

## Manifest format

Every package contains a strict JSON manifest with two fields:

```json
{
  "source": ["./file", "./folder", "./*.config"],
  "targets": {
    "macos": ["~/some/directory", "~/another/directory"],
    "linux": ["~/some/directory"]
  }
}
```

`source` is a non-empty list of paths or glob patterns relative to the package directory. Each matched file or directory is linked into every selected target using its basename:

```text
<package>/<matched source> → <target>/<source basename>
```

For example:

```text
home/neovim/nvim → ~/.config/nvim
```

Source patterns support Go filepath globs such as `*`, `?`, and character ranges. They do not recursively cross directory separators. To manage a complete directory tree, match the directory itself and the manager will link that directory as one unit.

Sources must remain inside their package. Absolute patterns, `..` traversal, broken links, and source symlinks that resolve outside the package are rejected.

`targets` maps each supported operating-system name to an array of destination directories. Every array must contain strings; scalar paths, `null`, and the former singular `target` field are invalid. Only `macos` and `linux` keys are supported. Targets must use an absolute path, `~`, or a path beginning with `~/`. Environment variables and named-user forms such as `~alice` are not expanded.

Only the selected operating system needs a non-empty target array, although defining both makes a package portable. Paths for the unselected operating system are not inspected. Target arrays are unordered: output is sorted by destination, and declaration order gives no target priority. Within the selected array, two paths may not resolve to the same effective directory.

## Examples

### Tmux

`home/tmux/manage.json`:

```json
{
  "source": ["./.tmux.conf"],
  "targets": {
    "macos": ["~"],
    "linux": ["~"]
  }
}
```

Result:

```text
~/.tmux.conf → <repository>/home/tmux/.tmux.conf
```

### Neovim

`home/neovim/manage.json`:

```json
{
  "source": ["./nvim"],
  "targets": {
    "macos": ["~/.config"],
    "linux": ["~/.config"]
  }
}
```

Result:

```text
~/.config/nvim → <repository>/home/neovim/nvim
```

### Ghostty

`home/ghostty/manage.json`:

```json
{
  "source": ["./config"],
  "targets": {
    "macos": ["~/Library/Application Support/com.mitchellh.ghostty"],
    "linux": ["~/.config/ghostty"]
  }
}
```

Results:

```text
# macOS
~/Library/Application Support/com.mitchellh.ghostty/config
    → <repository>/home/ghostty/config

# Linux
~/.config/ghostty/config
    → <repository>/home/ghostty/config
```

## Usage

Preview the complete plan first:

```bash
go run . --dry-run macos
```

Create the links:

```bash
go run . macos
```

Use `linux` on a Linux machine:

```bash
go run . --dry-run linux
go run . linux
```

Flags must appear before the operating-system argument.

Show help:

```bash
go run . --help
```

The command reports one line per managed entry:

```text
would link /target/config -> /repository/home/example/config
linked     /target/config -> /repository/home/example/config
exists     /target/config -> /repository/home/example/config
```

`exists` means the destination is already a symlink to the correct source, so no change was needed.

## Migrating an existing configuration

The manager intentionally refuses to overwrite existing files or directories. Move or copy the configuration into its package, preserve a backup, and only then create the link.

For example, a cautious Tmux migration could be:

```bash
mkdir -p home/tmux
cp ~/.tmux.conf home/tmux/.tmux.conf
mv ~/.tmux.conf ~/.tmux.conf.before-dotfiles

go run . --dry-run macos
go run . macos
```

After verifying that Tmux works through the symlink, the backup can be removed manually.

For a directory such as Neovim, copy it recursively and move the original aside:

```bash
mkdir -p home/neovim
cp -R ~/.config/nvim home/neovim/nvim
mv ~/.config/nvim ~/.config/nvim.before-dotfiles

go run . --dry-run macos
go run . macos
```

Review files for credentials and tokens before committing them to Git. A private repository is not a substitute for removing secrets.

## Safety behavior

Before creating any link, the manager validates the complete plan:

- Every manifest must be valid JSON with only recognized fields.
- Every source pattern must match at least one entry.
- Sources may not escape their package.
- Planned destinations may not be placed inside a managed source.
- Package-directory discovery errors are reported instead of silently skipping a package.
- Duplicate effective target directories within one package and platform are rejected.
- Two different sources may not claim the same destination, including through target-directory symlink aliases.
- A planned destination may not be nested below another planned destination, because every destination becomes a symlink.
- Dangling symlinks and non-directory components in target-directory paths are rejected before links are created.
- Existing regular files and directories are never replaced.
- Wrong and broken destination symlinks are never replaced.
- Correct existing symlinks are left unchanged.
- Missing destination directories are created as needed.

The manager creates absolute symlinks to this repository. Moving the repository afterward will break those links; place the clone at its intended permanent location before applying it.

There is no `--force` option. Resolve a conflict yourself, then run the command again.

## Current limitations

- Symlinks only; no copying or templating
- No automatic operating-system detection
- No package installation or `Brewfile` handling
- No secret storage or encryption
- No automatic backups or removal of obsolete links
- No transactional rollback: if an unexpected filesystem error occurs while applying a validated plan, links created earlier in that run remain in place
- Sources are placed directly into the target by basename rather than preserving their package-relative path

These constraints are intentional for the first version.

## Development

Run the test suite:

```bash
go test ./...
```

Run additional checks:

```bash
go test -race ./...
go vet ./...
```

Before a release, follow the isolated [manual QA plan](MANUAL_QA_PLAN.md). It builds a disposable repository, redirects `HOME` to a fake directory, and uses only dummy sources and targets.

Tests call `Run` directly and use temporary repositories, source files, directories, targets, and symlinks. They do not interact with your real home-directory configuration.
