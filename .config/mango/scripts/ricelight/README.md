# ricelight

Match your keyboards to your rice. fzf-driven lighting control for:

- **ASUS TUF laptop keyboard** — via the in-kernel `asus-wmi` sysfs interface
  (`/sys/class/leds/asus::kbd_backlight/kbd_rgb_mode`), no extra daemons.
  Single-zone RGB: static / breathe / color-cycle / strobe, 0-255 per channel.
- **External mechanical keyboard** — via OpenRGB CLI, if the controller is
  detected. Budget 2.4G boards (Areson receivers, e.g. the Redragon here) are
  usually invisible to OpenRGB; ricelight degrades gracefully.

Colors are parsed **live from `~/.config/foot/foot.ini` `[colors-dark]`**, so
the keyboard palette always matches the rice. Recolor foot, get a new keyboard
theme for free.

## Install

Handled by the rice installer (`setup.sh`):

- package: `openrgb` (extras group)
- udev rule: `etc/udev/rules.d/99-ricelight.rules` makes `kbd_rgb_mode` /
  `kbd_rgb_state` writable by group `wheel` (rootless control)
- this directory is installed with the rest of `.config/mango/scripts/`
- `post_install` links `~/.local/bin/ricelight` here
- mango gets `SUPER+K` (menu) and an `exec_once` re-applying your last choice

Manual one-off instead:

```sh
sudo install -m644 etc/udev/rules.d/99-ricelight.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger -c change -s leds
```

## Use

```sh
ricelight               # fzf menu: pick effect, then color
ricelight --status      # what is detected, what is saved
ricelight --apply-last  # silently re-apply saved state (used at login)
ricelight --lab         # step through WMI mode numbers (hardware testing)
ricelight --save-bios   # persist current choice into BIOS (survives poweroff)
```

Super+K opens the menu in a foot window.

## How it works

`kbd_rgb_mode` write format: `<cmd> <mode> <red> <green> <blue> <speed>`

| field | values |
|-------|--------|
| cmd   | 0 = this boot only, 1 = save to BIOS |
| mode  | 0 static, 1 breathe, 2 color cycle, 10 strobe (verified on FA507XV) |
| r/g/b | 0-255 |
| speed | 0 slow, 1 normal, 2 fast |

Firmware notes from live testing on the TUF A15 FA507XV: modes 2-8 all behave
as color cycle, 10/11 both strobe, and there is no rainbow/per-key mode — the
board is 1-zone.

`kbd_rgb_state` (`<cmd> <boot> <awake> <sleep> <shutdown>`) controls in which
power states the light is on; ricelight sets awake=1 for the current boot
before applying colors.

The last selection is stored in `~/.config/ricelight/state.conf` (user state,
not part of the rice) and re-applied at login via `exec_once` in the mango
config.

## Files

```
ricelight.sh          main script + fzf menus
lib/common.sh         foot.ini palette parsing, state, notifications
lib/asus.sh           TUF sysfs WMI writer
lib/openrgb.sh        OpenRGB CLI wrapper for external boards
```

## Notes / caveats

- Your existing `kbdlight` script (brightness up/down) keeps working untouched.
- If the lighting looks wrong after a reboot, one `ricelight --apply-last`
  fixes it — writes are volatile (cmd=0) unless you run `--save-bios`.
