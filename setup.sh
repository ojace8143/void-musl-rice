#!/bin/sh
set -eu

log() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

RICE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

SKIP_PACKAGES=0
SKIP_SYSTEM=0
SKIP_FONT=0
CLEAN=0
LINK_MODE=0
for arg in "$@"; do
	case "$arg" in
		--no-packages) SKIP_PACKAGES=1 ;;
		--no-system) SKIP_SYSTEM=1 ;;
		--no-font) SKIP_FONT=1 ;;
		--clean) CLEAN=1 ;;
		--link) LINK_MODE=1 ;;
		-h|--help)
			cat <<EOF
usage: $0 [options]

  --no-packages   skip xbps package installation
  --no-system     skip udev/rc.local/limits/groups/services (and sudo)
  --no-font       skip the JetBrainsMono Nerd Font download
  --clean         remove destination config dirs instead of merging into them
  --link          symlink configs from this repo instead of copying them
EOF
			exit 0 ;;
		*) printf 'warning: ignoring unknown argument: %s\n' "$arg" >&2 ;;
	esac
done

# Packages this rice needs (Void xbps package names, case sensitive).
PACKAGES="mangowc Waybar dunst swaybg fuzzel foot grim slurp satty ImageMagick \
wl-clipboard cliphist wl-clip-persist swaylock swayidle wlopm brightnessctl playerctl \
pipewire wireplumber libspa-bluetooth bluez polkit polkit-gnome gammastep SwayOSD \
qt5ct qt6ct xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk dbus dconf seatd xorg-server-xwayland zoxide eza bat \
chromium zsh zsh-autosuggestions zsh-syntax-highlighting mesa-dri alsa-utils alsa-pipewire nerd-fonts-symbols-ttf noto-fonts-emoji \
jq wf-recorder git flatpak dejavu-fonts-ttf neovim btop cmus fzf ripgrep fd lazygit \
arc-theme papirus-icon-theme imv mpv zathura impala bluetui pavucontrol \
xdg-utils xdg-user-dirs curl unzip"

[ -n "${HOME:-}" ] || die "HOME is not set"
[ -d "$RICE_DIR/.config" ] || die "no .config next to this script ($RICE_DIR)"

TARGET_USER=$(id -un)
TARGET_UID=$(id -u)

if command -v getent >/dev/null 2>&1; then
	USER_SHELL=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7)
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

RICE_HOME_FILES=".zshrc .zprofile .zshenv .zlogin .zlogout .colors .gtkrc-2.0 .keybinds .asoundrc"

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/rice-backup-$STAMP"
mkdir -p "$BACKUP_DIR"

printf '\nvoid-musl-rice installer\n'
printf '  rice:   %s\n' "$RICE_DIR"
printf '  target: %s\n' "$HOME"
printf '  shell:  %s (%s)\n' "$SHELL_NAME" "$USER_SHELL"
printf '  mode:   %s%s\n' "$([ "$LINK_MODE" -eq 1 ] && echo link || echo copy)" "$([ "$CLEAN" -eq 1 ] && echo ', clean')"
printf '  backup: %s\n\n' "$BACKUP_DIR"

# Copy, merge, or link one file/directory.
install_path() {
	src=$1
	dest=$2
	[ -e "$src" ] || return 0
	mkdir -p "$(dirname "$dest")"
	if [ "$LINK_MODE" -eq 1 ]; then
		rm -rf "$dest"
		ln -s "$src" "$dest"
	elif [ "$CLEAN" -eq 1 ]; then
		rm -rf "$dest"
		cp -a "$src" "$dest"
	else
		[ -L "$dest" ] && rm -f "$dest"
		if [ -d "$src" ]; then
			mkdir -p "$dest"
			cp -a "$src/." "$dest/"
		else
			cp -a "$src" "$dest"
		fi
	fi
}

printf '1. backing up the current ~/.config\n'
if [ -e "$HOME/.config" ]; then
	tar -czhf "$BACKUP_DIR/config.tar.gz" \
		--exclude='.config/chromium' \
		--exclude='*/node_modules' \
		-C "$HOME" .config
	log "$HOME/.config -> $BACKUP_DIR/config.tar.gz"
else
	log "no $HOME/.config, nothing to back up"
fi

printf '2. backing up the %s startup files\n' "$SHELL_NAME"
set --
SEEN=' '
for f in $RC_FILES $RICE_HOME_FILES; do
	if [ -e "$HOME/$f" ]; then
		case "$SEEN" in *" $f "*) continue ;; esac
		SEEN="$SEEN$f "
		set -- "$@" "$f"
	fi
done
if [ "$#" -gt 0 ]; then
	tar -czhf "$BACKUP_DIR/shell-rc.tar.gz" -C "$HOME" "$@"
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

	# These dirs contain user data. In link mode, link only the rice files.
	if [ "$LINK_MODE" -eq 1 ] && [ "$name" = "cmus" ]; then
		mkdir -p "$dest"
		[ -f "$item/rc" ] && ln -sfn "$item/rc" "$dest/rc"
		log ".config/$name (rc linked, autosave kept)"
		continue
	fi
	if [ "$LINK_MODE" -eq 1 ] && [ "$name" = "opencode" ]; then
		mkdir -p "$dest"
		cp -a "$item/." "$dest/"
		log ".config/$name (copied, auth/node_modules kept)"
		continue
	fi

	install_path "$item" "$dest"
	log ".config/$name"
done

printf '4. installing the rice startup files\n'
for f in $RICE_HOME_FILES; do
	[ -e "$RICE_DIR/$f" ] || continue
	install_path "$RICE_DIR/$f" "$HOME/$f"
	log "$f"
done

printf '5. installing the rice scripts\n'
if [ -d "$RICE_DIR/.local/bin" ]; then
	for f in "$RICE_DIR"/.local/bin/*; do
		[ -e "$f" ] || continue
		name=$(basename "$f")
		install_path "$f" "$HOME/.local/bin/$name"
		[ -L "$HOME/.local/bin/$name" ] || chmod +x "$HOME/.local/bin/$name"
		log ".local/bin/$name"
	done
else
	log "no .local/bin/ in the rice, nothing to do"
fi

printf '6. installing system files\n'
if [ "$SKIP_SYSTEM" -eq 1 ]; then
	log "skipped (--no-system)"
elif [ -d "$RICE_DIR/etc" ]; then
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
		# Same for the ASUS fan curve used by the fan keybinds.
		if [ -f "$RICE_DIR/etc/fan-perms.sh" ]; then
			$PRIV sh "$RICE_DIR/etc/fan-perms.sh" || true
		fi
		# Raise the hard nofile limit for gaming/Proton.
		if [ -f "$RICE_DIR/etc/security/limits.d/20-nofile.conf" ]; then
			$PRIV mkdir -p /etc/security/limits.d
			$PRIV install -m644 "$RICE_DIR/etc/security/limits.d/20-nofile.conf" /etc/security/limits.d/
			log "/etc/security/limits.d/20-nofile.conf"
		fi
		# Create XDG_RUNTIME_DIR at boot without elogind/logind.
		if [ -f "$RICE_DIR/etc/rc.local.rice" ]; then
			if ! $PRIV grep -q 'void-musl-rice runtime dir' /etc/rc.local 2>/dev/null; then
				tmp=$(mktemp)
				sed -e "s|__USER__|$TARGET_USER|g" \
					-e "s|__UID__|$TARGET_UID|g" \
					"$RICE_DIR/etc/rc.local.rice" > "$tmp"
				$PRIV tee -a /etc/rc.local < "$tmp" >/dev/null
				rm -f "$tmp"
				log "/etc/rc.local: runtime dir block"
			else
				log "/etc/rc.local: runtime dir block already present"
			fi
			$PRIV install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "/run/user/$TARGET_UID" 2>/dev/null || true
			log "/run/user/$TARGET_UID ready for this boot"
		fi
	else
		log "skipped: need root or sudo"
		log "run manually:"
		log "  sudo install -m644 $RICE_DIR/etc/udev/rules.d/*.rules /etc/udev/rules.d/"
		log "  sudo chgrp video /sys/class/backlight/*/brightness && sudo chmod g+w /sys/class/backlight/*/brightness"
		log "  sudo sh $RICE_DIR/etc/fan-perms.sh"
		log "  sudo install -m644 $RICE_DIR/etc/security/limits.d/20-nofile.conf /etc/security/limits.d/"
		log "  sudo sh -c 'cat $RICE_DIR/etc/rc.local.rice >> /etc/rc.local'"
	fi
else
	log "no etc/ directory in the rice, nothing to do"
fi

printf '7. installing packages with xbps\n'
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

# .config/bat was linked above, but bat only sees the theme after a cache build
if command -v bat >/dev/null 2>&1; then
	if bat cache --build >/dev/null 2>&1; then
		log "built bat theme cache (void-dark)"
	else
		log "warning: bat cache --build failed; run it manually"
	fi
fi

printf '8. installing the JetBrainsMono Nerd Font\n'
if [ "$SKIP_FONT" -eq 1 ]; then
	log "skipped (--no-font)"
elif command -v fc-list >/dev/null 2>&1 &&
     fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font'; then
	log "already installed"
elif command -v curl >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
	tmp=$(mktemp -d)
	url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.zip"
	if curl -fL --retry 2 -o "$tmp/font.zip" "$url" >/dev/null 2>&1 &&
	   unzip -q "$tmp/font.zip" -d "$tmp/font" >/dev/null 2>&1; then
		mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
		cp -a "$tmp"/font/*.ttf "$HOME/.local/share/fonts/JetBrainsMonoNerdFont/" 2>/dev/null || true
		fc-cache -f >/dev/null 2>&1 || true
		log "$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
	else
		log "download failed; install nerd-fonts-ttf manually if needed"
	fi
	rm -rf "$tmp"
else
	log "skipped: curl/unzip not found"
fi

printf '9. applying GTK font/theme defaults\n'
apply_gsettings() {
	command -v gsettings >/dev/null 2>&1 || { log "gsettings not found"; return 0; }
	if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
		gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true
		gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
		gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 11' 2>/dev/null || true
		gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
		gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
		gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
	else
		dbus-run-session -- sh -c '
			gsettings set org.gnome.desktop.interface gtk-theme "Arc-Dark" 2>/dev/null || true
			gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null || true
			gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 11" 2>/dev/null || true
			gsettings set org.gnome.desktop.interface cursor-theme "Adwaita" 2>/dev/null || true
			gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
			gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
		' 2>/dev/null || true
	fi
	log "gsettings applied (best effort)"
}
apply_gsettings

printf '10. user groups and system services\n'
if [ "$SKIP_SYSTEM" -eq 1 ]; then
	log "skipped (--no-system)"
else
	if [ "$(id -u)" -eq 0 ]; then
		SYS_PRIV=
	elif command -v sudo >/dev/null 2>&1; then
		SYS_PRIV=sudo
	else
		SYS_PRIV=
	fi
	if [ -n "$SYS_PRIV" ] || [ "$(id -u)" -eq 0 ]; then
		for grp in video input _seatd; do
			if id -nG "$TARGET_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$grp"; then
				log "$TARGET_USER already in group $grp"
			elif grep -q "^$grp:" /etc/group 2>/dev/null; then
				$SYS_PRIV usermod -aG "$grp" "$TARGET_USER" &&
					log "added $TARGET_USER to group $grp"
			fi
		done
		for svc in dbus polkitd bluetoothd seatd; do
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
fi

printf '11. installing wallpapers\n'
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
