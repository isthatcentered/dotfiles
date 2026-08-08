# Kanata on Linux

The configuration applies to every detected keyboard and only defines these
chords:

- `j` + `k`: Escape
- `u` + `i`: Backspace
- `m` + `,`: Enter

## One-time permissions

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

## Install the configuration and service

Run these commands from this directory:

```sh
mkdir -p "$HOME/.config/kanata" "$HOME/.config/systemd/user"
ln -s "$PWD/kanata.kbd" "$HOME/.config/kanata/kanata.kbd"
ln -s "$PWD/kanata.service" "$HOME/.config/systemd/user/kanata.service"
kanata --check --cfg "$HOME/.config/kanata/kanata.kbd"
systemctl --user daemon-reload
systemctl --user enable --now kanata.service
```

Inspect logs with:

```sh
journalctl --user --unit kanata.service --follow
```
