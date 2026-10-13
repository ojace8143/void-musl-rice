#!/bin/sh
set -eu

log() { printf '  %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

RICE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

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

RICE_RC=".zshrc .zprofile .zshenv .zlogin .zlogout .colors"

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
