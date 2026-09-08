# Kanata

macOS and Linux use the same `kanata.kbd`: home-row modifiers, navigation,
number, symbol, and function layers, media keys, and chords. No device filters
are configured; Kanata uses its default device detection on each platform.
Hold the `e` + `r` chord for the accent layer: `u` outputs `é`, `i` outputs
`è`, `o` outputs `à`, and `p` outputs `ç`.

Installation is manual. The Go dotfiles manager only discovers manifests under
`home/`, so it does not install anything in this directory.

Run the commands below from this directory, with Kanata already installed.

## Linux

### One-time permissions

Kanata needs access to keyboard input devices and `/dev/uinput`:

```sh
getent group uinput >/dev/null || sudo groupadd --system uinput
sudo usermod -aG input,uinput "$USER"
sudo install -Dm644 99-input.rules /etc/udev/rules.d/99-input.rules
sudo modprobe uinput
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Log out and back in after adding the groups.

### Install or update

The service expects `/usr/bin/kanata`. Adjust `kanata.service` if your binary
is elsewhere. These links also replace links to the former `linux/` directory.
If either destination is a regular file, back it up before replacing it.

```sh
mkdir -p "$HOME/.config/kanata" "$HOME/.config/systemd/user"
ln -sfn "$PWD/kanata.kbd" "$HOME/.config/kanata/kanata.kbd"
ln -sfn "$PWD/kanata.service" "$HOME/.config/systemd/user/kanata.service"
kanata --check --cfg "$HOME/.config/kanata/kanata.kbd"
systemctl --user daemon-reload
systemctl --user enable kanata.service
systemctl --user restart kanata.service
```

Restart after editing the configuration:

```sh
systemctl --user restart kanata.service
```

Inspect logs with:

```sh
journalctl --user --unit kanata.service --follow
```

## macOS

Kanata needs the Karabiner virtual keyboard driver and the permissions described
in the [upstream macOS setup guide](https://github.com/jtroo/kanata/blob/main/docs/setup-macos.md).
The supplied plist runs Kanata as a root LaunchDaemon.

### Install or update

Edit both absolute paths in `kanata.plist` for your machine: the Kanata binary
and this directory's shared `kanata.kbd`.

```sh
kanata --check --cfg "$PWD/kanata.kbd"
```

If the daemon is already installed, unload it first. This is also required when
migrating from the former `macos/kanata.kbd` path:

```sh
sudo launchctl bootout system/dev.kanata.kanata
```

Then install and load the updated plist:

```sh
sudo cp kanata.plist /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo chown root:wheel /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist
```

Restart after editing the configuration:

```sh
sudo launchctl kickstart -k system/dev.kanata.kanata
```

If the plist changes, repeat the unload, copy, and bootstrap steps above.
Standard error is logged to `/var/log/kanata.log`.
