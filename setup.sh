#!/bin/sh
set -eu

log() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

RICE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

SKIP_PACKAGES=0
for arg in "$@"; do
	case "$arg" in
		--no-packages) SKIP_PACKAGES=1 ;;
		-h|--help)
			printf 'usage: %s [--no-packages]\n' "$0"
			printf '  --no-packages   skip xbps package installation\n'
			exit 0 ;;
		*) printf 'warning: ignoring unknown argument: %s\n' "$arg" >&2 ;;
	esac
done

# Packages this rice needs (Void xbps package names, case sensitive).
PACKAGES="mangowc Waybar dunst swaybg fuzzel foot grim slurp satty \
wl-clipboard cliphist wlogout swaylock swayidle wlopm brightnessctl playerctl \
pipewire wireplumber libspa-bluetooth bluez polkit polkit-gnome gammastep SwayOSD \
qt6ct xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk dbus \
chromium zsh mesa-dri alsa-utils nerd-fonts-symbols-ttf noto-fonts-emoji \
jq wf-recorder git flatpak dejavu-fonts-ttf"

[ -n "${HOME:-}" ] || die "HOME is not set"
[ -d "$RICE_DIR/.config" ] || die "no .config next to this script ($RICE_DIR)"

if command -v getent >/dev/null 2>&1; then
	USER_SHELL=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
fi
USER_SHELL=${USER_SHELL:-${SHELL:-/bin/sh}}
SHELL_NAME=$(basename "$USER_SHELL")

case "$SHELL_NAME" in
	zsh)      RC_FILES=".zshenv .zprofile .zshrc .zlogin .zlogout" ;;
	bash)     RC_FILES=".bashrc .bash_profile .bash_login .bash_logout .profile" ;;
	ksh)      RC_FILES=".profile .kshrc" ;;
	csh|tcsh) RC_FILES=".cshrc .login .tcshrc" ;;
	fish)     RC_FILES=".config/fish" ;;
	*)        RC_FILES=".profile .bashrc .zshrc" ;;
esac

RICE_RC=".zshrc .zprofile .zshenv .zlogin .zlogout .colors .gtkrc-2.0"

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/rice-backup-$STAMP"
mkdir -p "$BACKUP_DIR"

printf '\nvoid-musl-rice installer\n'
printf '  rice:   %s\n' "$RICE_DIR"
printf '  target: %s\n' "$HOME"
printf '  shell:  %s (%s)\n' "$SHELL_NAME" "$USER_SHELL"
printf '  backup: %s\n\n' "$BACKUP_DIR"

printf '1. backing up the current ~/.config\n'
if [ -e "$HOME/.config" ]; then
	tar -czf "$BACKUP_DIR/config.tar.gz" -C "$HOME" .config
	log "$HOME/.config -> $BACKUP_DIR/config.tar.gz"
else
	log "no $HOME/.config, nothing to back up"
fi

printf '2. backing up the %s startup files\n' "$SHELL_NAME"
set --
for f in $RC_FILES; do
	if [ -e "$HOME/$f" ]; then
		set -- "$@" "$f"
	fi
done
if [ "$#" -gt 0 ]; then
	tar -czf "$BACKUP_DIR/shell-rc.tar.gz" -C "$HOME" "$@"
	log "tarred: $*"
	log "-> $BACKUP_DIR/shell-rc.tar.gz"
else
	log "no matching startup files, nothing to back up"
fi

printf '3. installing the rice config into %s/.config\n' "$HOME"
mkdir -p "$HOME/.config"
for item in "$RICE_DIR"/.config/* "$RICE_DIR"/.config/.[!.]* "$RICE_DIR"/.config/..?*; do
	[ -e "$item" ] || continue
	name=$(basename "$item")
	dest="$HOME/.config/$name"
	[ -L "$dest" ] && rm -f "$dest"
	rm -rf "$dest"
	cp -a "$item" "$dest"
	log ".config/$name"
done

printf '4. installing the rice startup files\n'
for f in $RICE_RC; do
	[ -e "$RICE_DIR/$f" ] || continue
	[ -L "$HOME/$f" ] && rm -f "$HOME/$f"
	rm -f "$HOME/$f"
	cp -a "$RICE_DIR/$f" "$HOME/$f"
	log "$f"
done

printf '5. installing system files\n'
if [ -d "$RICE_DIR/etc" ]; then
	if [ "$(id -u)" -eq 0 ]; then
		PRIV=
	elif command -v sudo >/dev/null 2>&1; then
		PRIV=sudo
	else
		PRIV=
	fi
	if [ -n "$PRIV" ] || [ "$(id -u)" -eq 0 ]; then
		for f in "$RICE_DIR"/etc/udev/rules.d/*.rules; do
			[ -e "$f" ] || continue
			$PRIV mkdir -p /etc/udev/rules.d
			$PRIV install -m644 "$f" /etc/udev/rules.d/
			log "/etc/udev/rules.d/$(basename "$f")"
		done
		$PRIV udevadm control --reload 2>/dev/null || true
		# eudev's trigger won't re-run rules on already-present devices,
		# so apply the backlight perms directly for this boot too.
		for bl in /sys/class/backlight/*; do
			[ -e "$bl/brightness" ] || continue
			if $PRIV chgrp video "$bl/brightness" 2>/dev/null &&
			   $PRIV chmod g+w "$bl/brightness" 2>/dev/null; then
				log "backlight write access: $(basename "$bl")"
			fi
		done
	else
		log "skipped: need root or sudo"
		log "run manually:"
		log "  sudo install -m644 $RICE_DIR/etc/udev/rules.d/*.rules /etc/udev/rules.d/"
		log "  sudo chgrp video /sys/class/backlight/*/brightness && sudo chmod g+w /sys/class/backlight/*/brightness"
	fi
	else
		log "no etc/ directory in the rice, nothing to do"
	fi

printf '6. installing packages with xbps\n'
if [ "$SKIP_PACKAGES" -eq 1 ]; then
	log "skipped (--no-packages)"
elif command -v xbps-install >/dev/null 2>&1; then
	if [ "$(id -u)" -eq 0 ]; then
		PKG_PRIV=
	elif command -v sudo >/dev/null 2>&1; then
		PKG_PRIV=sudo
	else
		PKG_PRIV=
	fi
	if [ -n "$PKG_PRIV" ] || [ "$(id -u)" -eq 0 ]; then
		$PKG_PRIV xbps-install -Sy $PACKAGES || die "xbps-install failed"
		log "packages installed / already up to date"
	else
		log "skipped: need root or sudo; run manually:"
		log "  sudo xbps-install -Sy $PACKAGES"
	fi
else
	log "skipped: xbps-install not found (not a Void system?)"
	log "install these with your package manager:"
	log "  $PACKAGES"
fi

printf '7. user groups and system services\n'
TARGET_USER=$(id -un)
if [ "$(id -u)" -eq 0 ]; then
	SYS_PRIV=
elif command -v sudo >/dev/null 2>&1; then
	SYS_PRIV=sudo
else
	SYS_PRIV=
fi
if [ -n "$SYS_PRIV" ] || [ "$(id -u)" -eq 0 ]; then
	for grp in video input; do
		if id -nG "$TARGET_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$grp"; then
			log "$TARGET_USER already in group $grp"
		elif grep -q "^$grp:" /etc/group 2>/dev/null; then
			$SYS_PRIV usermod -aG "$grp" "$TARGET_USER" &&
				log "added $TARGET_USER to group $grp"
		fi
	done
	for svc in dbus polkitd bluetoothd; do
		[ -d "/etc/sv/$svc" ] || continue
		if [ -e "/var/service/$svc" ]; then
			log "service already enabled: $svc"
		elif $SYS_PRIV ln -s "/etc/sv/$svc" /var/service/; then
			log "enabled service: $svc"
		fi
	done
else
	log "skipped: need root or sudo; run manually:"
	log "  sudo usermod -aG video,input $TARGET_USER"
	log "  sudo ln -s /etc/sv/dbus /etc/sv/polkitd /etc/sv/bluetoothd /var/service/"
fi

printf '8. installing wallpapers\n'
if [ -d "$RICE_DIR/wallpapers" ]; then
	mkdir -p "$HOME/Pictures"
	for wp in "$RICE_DIR"/wallpapers/*; do
		[ -e "$wp" ] || continue
		cp -a "$wp" "$HOME/Pictures/"
		log "Pictures/$(basename "$wp")"
	done
else
	log "no wallpapers/ next to this script, nothing to do"
fi

printf '\ndone. your old files are in %s\n' "$BACKUP_DIR"
printf 'restore everything with:\n'
printf '  tar -xzf %s/config.tar.gz -C "%s"\n' "$BACKUP_DIR" "$HOME"
if [ -f "$BACKUP_DIR/shell-rc.tar.gz" ]; then
	printf '  tar -xzf %s/shell-rc.tar.gz -C "%s"\n' "$BACKUP_DIR" "$HOME"
fi
printf '\nnote: this rice targets zsh.\n'
if [ "$SHELL_NAME" != "zsh" ]; then
	printf 'your login shell is %s; switch with:\n' "$SHELL_NAME"
	printf '  sudo xbps-install -S zsh && chsh -s /usr/bin/zsh\n'
fi
printf 'log out and back in to apply everything.\n\n'
