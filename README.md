# void-musl-rice
my personal void linux musl rice if you want to use it ig

honestly pretty clean if i do say so myself

## the deets
mangowm, fuzzel, waybar

basically it

lock screen: swaylock with an ImageMagick-pre-blurred wallpaper. tune with `SWAYLOCK_BLUR` (default 14), `SWAYLOCK_BRIGHTNESS` (default 65), and `SWAYLOCK_WALLPAPER`.

## colors
`~/.colors` is the single source of truth for the whole palette (void-dark, accent = Void green `#478061`). foot themes the ANSI slots from it, so terminal apps pick it up for free.

`pfetch` is themed to match: it's vendored in `.local/bin/pfetch` (a patched pfetch 0.6.0) with truecolor art/palette and text colors from `.colors` — labels `VD_GRAY`, data `VD_FG`, title `VD_GREEN_BR`. vendoring means it renders on-scheme even in terminals that aren't foot. override the text colors with full escape sequences via `PF_LABEL`, `PF_DATA`, `PF_TITLE`.

## install
```sh
./setup.sh
```
it tarballs your current `~/.config` and your shell's startup files into `~/rice-backup-<timestamp>/`, then copies the rice configs into `~/.config` and your home dir. it prints the exact `tar -xzf` commands to restore. no `.bak` files, just extractable tarballs.

it also drops `.local/bin/pfetch` into `~/.local/bin` (which shadows the packaged pfetch when `~/.local/bin` is on your `PATH`).

system files: `setup.sh` installs `etc/udev/rules.d/90-backlight.rules` (asks for sudo) so the `video` group can control the backlight without elogind, and applies the group perms to existing backlight devices. if you skip it or it can't get root, do it by hand:
```sh
sudo install -m644 etc/udev/rules.d/90-backlight.rules /etc/udev/rules.d/
sudo chgrp video /sys/class/backlight/*/brightness && sudo chmod g+w /sys/class/backlight/*/brightness
```

## Binds
Meta+Q           -- Terminal
Meta+W           -- Close Window
Meta+Space       -- Start Menu/Fuzzel
Meta+D           -- Run Command (dmenu equivalent in dwm)
Meta+Shift+Enter -- Chromium/Browser
PrtSc            -- Screenshot
Meta+PrtSc       -- Select Screenshot Area

Volume up and volume down buttons should work as normal, brightness up and down should also work. Depending on your keyboard, you may have to change a few things.

## screenies
![screenshot1](screenies/screenshot1.png)
![screenshot2](screenies/screenshot2.png)
  
## ai use
i used ai a decent amount on this project to help me fine tune and fix some stuff, specifically opencode and Big Pickle.


