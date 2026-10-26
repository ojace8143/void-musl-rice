# void-musl-rice
my personal void linux musl rice if you want to use it ig

honestly pretty clean if i do say so myself

## the deets
mangowm, waybar, fuzzel, foot, dunst, swaylock, swayosd, cliphist

basically it

## install
```sh
./setup.sh
```

The installer backs up your existing `~/.config` and shell startup files into
`~/rice-backup-<timestamp>/`, then merges the rice configs into `~/.config` and
your home directory. It prints the exact `tar -xzf` commands to restore.

Options:
```sh
./setup.sh --no-packages   # configs only, no xbps-install
./setup.sh --no-system     # skip udev/rc.local/limits/groups/services
./setup.sh --no-font       # skip the JetBrainsMono Nerd Font download
./setup.sh --clean         # replace config dirs instead of merging
./setup.sh --link          # symlink configs from this repo instead of copying
```

`--link` is the dotfiles-style mode: edits in this repo show up immediately.
`--clean` is useful after deleting files from the rice; the default merge keeps
things like cmus autosave, playlists, and `~/.config/opencode` data.
It also installs `.local/bin/pfetch` (which shadows the packaged pfetch when
`~/.local/bin` is on your `PATH`).

## system files
`setup.sh` installs:
- `/etc/udev/rules.d/90-backlight.rules` and `90-fan.rules` so the `video` group can control the backlight and the ASUS fan curve without elogind.
- `/etc/security/limits.d/20-nofile.conf` for a high open-file limit (Proton/Wine).
- a small block in `/etc/rc.local` that creates `/run/user/$UID` at boot (there is no elogind here).
- group membership for `video`, `input`, and `_seatd`, plus the `dbus`, `polkitd`, `bluetoothd`, and `seatd` services.

If setup can't get root, it prints the manual commands.

## desktop
- **waybar:** workspaces, MPRIS, bluetooth, network, audio, backlight, CPU, CPU temp, fans, memory, battery, idle inhibitor, tray.
- **OSD:** SwayOSD handles volume, microphone, brightness, and media keys.
- **clipboard:** cliphist + wl-clip-persist; `SUPER+V` opens the picker.
- **power menu:** `SUPER+Escape` (lock / logout / suspend / reboot / shutdown). Because this setup uses seatd instead of elogind, `polkit-gnome` cannot determine a login session; root actions fall back to a `foot` + `sudo` prompt. If you switch to elogind, enable the polkit agent line in `config.conf`.
- **night light:** `SUPER+CTRL+N` toggles gammastep at 4000K.
- **notifications:** dunst, themed to match.
- **themes/fonts:** Arc-Dark, Papirus-Dark, and JetBrainsMono Nerd Font, applied through gsettings and the Qt configs.
- **file defaults:** images → imv, video → mpv, PDF → zathura; Chromium stays the browser.
- **lock screen:** swaylock with an ImageMagick-pre-blurred wallpaper. Tune with `SWAYLOCK_BLUR` (default 14), `SWAYLOCK_BRIGHTNESS` (default 65), and `SWAYLOCK_WALLPAPER`; the cache key includes the blur/brightness values.
- **screenshots:** `Print` fullscreen, `SHIFT+Print` region, `CTRL+SHIFT+Print` window, `CTRL+Print` clipboard, `SUPER+Print` annotate. Saved shots get a notification.
- **recording:** `SUPER+SHIFT+R` region, `SUPER+ALT+R` full screen; press again to stop.

## colors
`~/.colors` is the palette reference (void-dark, accent = Void green `#478061`).
The consumers are still hand-synced — foot, waybar, dunst, fuzzel, swaylock,
btop, Qt, and nvim each embed their own copy. It is not a generated theme.

`pfetch` is themed to match: it's vendored in `.local/bin/pfetch` (a patched
pfetch 0.6.0) with truecolor art/palette and text colors from `.colors` — labels
`VD_GRAY`, data `VD_FG`, title `VD_GREEN_BR`. Vendoring means it renders
on-scheme even in terminals that aren't foot. Override the text colors with full
escape sequences via `PF_LABEL`, `PF_DATA`, `PF_TITLE`.

## fans
Hold `` ` `` and press `1` / `2` / `3` to raise, lower, or return both fans to
automatic (10% steps, normal notification on each change). The waybar module
shows `<fan icon> left%/right%` (left = CPU fan, right = GPU fan). In automatic
mode the percentage is estimated from the measured RPM after a one-time
`fanctl.sh calibrate` run, because the firmware does not expose its PWM value.

If the module ever reads `0%/0%` while the fans are clearly spinning:

```sh
rm ~/.cache/fanctl/calibration
~/.config/mango/scripts/fan/fanctl.sh calibrate
```

The script now ignores implausible RPM samples (outside 500–12000) so one bad
reading can't permanently poison the estimated maximum.

## binds
The full list is in `~/.keybinds`; `SUPER+/` opens it in `foot`.

```
Meta+Q           -- Terminal
Meta+Return      -- Dropdown terminal (named scratchpad)
Meta+W           -- Close Window
Meta+Space       -- Start Menu/Fuzzel
Meta+D           -- Run Command (dmenu equivalent in dwm)
Meta+Shift+Enter -- Chromium/Browser
Meta+V           -- Clipboard history
Meta+Escape      -- Power menu
Meta+/           -- Keybinding cheat sheet
PrtSc            -- Screenshot
Shift+PrtSc      -- Select Screenshot Area
Meta+PrtSc       -- Annotate screenshot
```

Volume up/down, mute, brightness, keyboard backlight, and media keys should work
as normal. Depending on your keyboard, you may have to change a few things.

## waybar clicks
- workspaces: activate / deactivate tag
- MPRIS: left play/pause, middle previous, right next
- bluetooth: bluetui or `bluetoothctl`
- network: impala or `iwctl`
- volume: pavucontrol, pulsemixer, or `alsamixer`
- battery: power menu
- idle inhibitor: left click toggle

Keyboard equivalents: `SUPER+CTRL+A` audio, `SUPER+CTRL+B` bluetooth,
`SUPER+CTRL+W` Wi-Fi.

## screenies
![screenshot1](screenies/screenshot1.png)
![screenshot2](screenies/screenshot2.png)

## ai use
i used ai a decent amount on this project to help me fine tune and fix some stuff,
specifically opencode and Big Pickle.
