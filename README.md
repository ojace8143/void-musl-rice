# void-musl-rice
my personal void linux musl rice if you want to use it ig

honestly pretty clean if i do say so myself

## the deets
mangowm, fuzzel, waybar

basically it
## install
```sh
./setup.sh
```
it tarballs your current `~/.config` and your shell's startup files into `~/rice-backup-<timestamp>/`, then copies the rice configs into `~/.config` and your home dir. it prints the exact `tar -xzf` commands to restore. no `.bak` files, just extractable tarballs.

system files: `setup.sh` installs `etc/udev/rules.d/90-backlight.rules` (asks for sudo) so the `video` group can control the backlight without elogind, and applies the group perms to existing backlight devices. if you skip it or it can't get root, do it by hand:
```sh
sudo install -m644 etc/udev/rules.d/90-backlight.rules /etc/udev/rules.d/
sudo chgrp video /sys/class/backlight/*/brightness && sudo chmod g+w /sys/class/backlight/*/brightness
```

## screenies
![screenshot1](screenies/screenshot1.png)
![screenshot2](screenies/screenshot2.png)
  
## ai use
i used ai a decent amount on this project to help me fine tune and fix some stuff, specifically opencode and Big Pickle.


