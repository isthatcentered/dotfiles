# Dotfiles manager

This repository contains a small Go program that installs configuration files by creating symbolic links from your home directory back into this repository.

It deliberately does one job: recursively discover `manage.json` files under `home/`, activate the manifests that support `macos` or `linux`, and reconcile every adjacent managed entry into every target directory. It does not copy files, install applications, manage secrets, or overwrite existing regular files and directories.

## Requirements

- Go 1.23 or newer
- macOS or Linux

Run commands from the repository root.

## Repository layout

Directories under `home/` may group related configurations however you find useful. A directory becomes a manifest container when it contains `manage.json`.

```text
.
├── go.mod
├── main.go
└── home/
    ├── tmux/
    │   ├── manage.json
    │   └── .tmux.conf
    ├── nvim/
    │   ├── manage.json
    │   └── nvim/
    │       ├── init.lua
    │       └── lua/
    └── zsh/
        └── linux/
            ├── manage.json
            ├── .zshrc
            └── .p10k.zsh
```

Manifests may appear at any depth beneath `home/`:

```text
home/**/manage.json
```

Discovery does not follow directory symlinks. Once a directory containing `manage.json` is found, that directory is a discovery boundary: its descendants are managed content and are not searched for additional manifests. Names such as `tmux`, `nvim`, `linux`, and `macos` are conventional; only the manifest controls activation.

## Manifest format

Every manifest is strict JSON with two fields:

```json
{
  "platforms": ["macos", "linux"],
  "targets": ["~/some/directory", "~/another/directory"]
}
```

`platforms` is a non-empty array containing `macos`, `linux`, or both. Duplicate and unsupported values are rejected. A manifest is active when the command's selected platform appears in this array.

`targets` is a non-empty array of destination directories shared by every platform in the manifest. Targets must use an absolute path, `~`, or a path beginning with `~/`. Environment variables and named-user forms such as `~alice` are not expanded. Targets are unordered, and two paths in one active manifest may not resolve to the same effective directory.

Every immediate child of an active manifest container other than `manage.json` is a managed entry. Each managed entry is linked into every target using its name:

```text
<container>/<managed entry> → <target>/<managed entry name>
```

For example:

```text
home/nvim/nvim → ~/.config/nvim
```

This includes regular files, directories, dotfiles, symlinks, ignored files, and untracked files. Directories are linked as whole units. `manage.json` is reserved and cannot itself be deployed. An active container containing only `manage.json` is invalid.

Managed entries must resolve within their container. Broken symlinks and symlinks that resolve outside the container are rejected.

Every discovered manifest must have valid JSON and a valid schema, including inactive manifests. Entries and target paths belonging to inactive manifests are not inspected. If different platforms need different targets or content, give each platform its own manifest container.

## Examples

### Tmux

`home/tmux/manage.json`:

```json
{
  "platforms": ["macos", "linux"],
  "targets": ["~"]
}
```

Result:

```text
~/.tmux.conf → <repository>/home/tmux/.tmux.conf
```

### Neovim

`home/nvim/manage.json`:

```json
{
  "platforms": ["macos", "linux"],
  "targets": ["~/.config"]
}
```

Result:

```text
~/.config/nvim → <repository>/home/nvim/nvim
```

### Platform-specific Zsh

Linux and macOS use separate containers with the same target but different contents:

```text
home/zsh/
├── linux/
│   ├── manage.json
│   ├── .zshrc
│   └── .p10k.zsh
└── macos/
    ├── manage.json
    ├── .zshrc
    └── .p10k.zsh
```

For example, `home/zsh/linux/manage.json` is:

```json
{
  "platforms": ["linux"],
  "targets": ["~"]
}
```

The macOS manifest has the same target and declares `"platforms": ["macos"]`. Running for a platform links only that container's siblings:

```text
# Linux
~/.zshrc → <repository>/home/zsh/linux/.zshrc

# macOS
~/.zshrc → <repository>/home/zsh/macos/.zshrc
```

### Platform-specific Ghostty targets

Ghostty uses separate containers because its target directory differs by platform:

```text
home/ghostty/
├── macos/
│   ├── manage.json
│   └── config
└── linux/
    ├── manage.json
    └── config
```

The macOS manifest targets `~/Library/Application Support/com.mitchellh.ghostty`; the Linux manifest targets `~/.config/ghostty`. Only the selected platform's container is applied.

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
would relink /target/config -> /repository/home/example/config
linked     /target/config -> /repository/home/example/config
relinked   /target/config -> /repository/home/example/config
exists     /target/config -> /repository/home/example/config
```

`exists` means the destination symlink already stores the exact planned absolute source path. `linked` creates a missing destination, while `relinked` atomically replaces an existing symlink whose stored target is different. The `would` variants report the same actions without changing the filesystem.

## Migrating an existing configuration

The manager intentionally refuses to overwrite existing regular files or directories. Move or copy the configuration into its manifest container, preserve a backup, and only then create the link.

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
mkdir -p home/nvim
cp -R ~/.config/nvim home/nvim/nvim
mv ~/.config/nvim ~/.config/nvim.before-dotfiles

go run . --dry-run macos
go run . macos
```

Review files for credentials and tokens before committing them to Git. A private repository is not a substitute for removing secrets.

## Safety behavior

Before changing any link, the manager validates the complete plan:

- Every manifest must be valid JSON with only recognized fields.
- Every active manifest container must contain at least one managed entry.
- Managed entries may not be broken or escape their container.
- Planned destinations may not be placed inside a managed entry.
- Manifest discovery is confined to real directories beneath `home/`; directory symlinks are not followed.
- Duplicate effective target directories within one active manifest are rejected.
- Two different managed entries may not claim the same destination, including through target-directory symlink aliases.
- A planned destination may not be nested below another planned destination, because every destination becomes a symlink.
- Dangling symlinks and non-directory components in target-directory paths are rejected before links are created.
- Existing regular files and directories are never replaced.
- Any symlink at a destination claimed by the current plan is managed: wrong, indirect, relative, and broken links are replaced atomically with the planned absolute link.
- Correct existing symlinks are left unchanged.
- Missing destination directories are created as needed.

The manager creates absolute symlinks to this repository. Moving the repository or its manifest containers temporarily breaks existing links; rerun the manager from the repository's new location to repair every destination claimed by the selected platform. Destinations no longer present in the current plan are left untouched.

There is no `--force` option. Resolve regular-file and directory conflicts yourself, then run the command again.

## Current limitations

- Symlinks only; no copying or templating
- No automatic operating-system detection
- No package installation or `Brewfile` handling
- No secret storage or encryption
- No automatic backups or removal of obsolete links
- No transactional rollback across the whole run: if an unexpected filesystem error occurs while applying a validated plan, earlier links remain created or updated
- No overlay or precedence between active manifests; conflicting destinations are rejected
- Managed entries are placed directly into the target rather than preserving their grouping-directory names

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

Tests call `Run` directly and use temporary repositories, manifest containers, managed entries, targets, and symlinks. They do not interact with your real home-directory configuration.
