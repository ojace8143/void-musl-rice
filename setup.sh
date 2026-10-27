#!/bin/sh
# void-musl-rice installer — interactive fzf-driven setup.
#
# The script is bash internally, but re-execs itself so both
#   ./setup.sh
#   sh setup.sh
# work.
if [ -z "${BASH_VERSION:-}" ]; then
	exec bash "$0" "$@"
fi

set -Eeuo pipefail

###############################################################################
# constants
###############################################################################

SCRIPT_PATH=$(readlink -f -- "$0" 2>/dev/null || printf '%s\n' "$0")
RICE_DIR=$(CDPATH= cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)
SETUP_PATH="$RICE_DIR/setup.sh"

RICE_HOME_FILES=(
	.zshrc
	.zprofile
	.zshenv
	.zlogin
	.zlogout
	.colors
	.gtkrc-2.0
	.keybinds
	.asoundrc
)

# Colours are loaded later from ~/.colors (preferred) or the repo copy.
PALETTE_FILE=

# Install mode: copy (merge), link, or clean.
MODE=copy
MODE_SET=0

# Components (all on by default).
COMP_CONFIGS=1
COMP_PACKAGES=1
COMP_SYSTEM=1
COMP_FONT=1
COMP_WALLPAPER=1
COMP_GSETTINGS=1
COMPONENTS_SET=0

# System actions (all on by default).
SYS_UDEV=1
SYS_LIMITS=1
SYS_RCLOCAL=1
SYS_GROUPS=1
SYS_SERVICES=1
SYS_ACTIONS_SET=0

# Package groups (all on by default).
SELECTED_GROUPS=(core session cli theme apps extras)
PKG_GROUPS_SET=0

# CLI state.
ASSUME_YES=0
DRY_RUN=0
NO_BACKUP=0
FORCE_NO_COLOR=0
RESTORE_DIR=
BACKUP_DIR=
PACKAGE_FAILED=0
SYSTEM_CHANGED=0
declare -A AVAIL_CACHE=()

# Runtime environment.
TARGET_USER=
TARGET_UID=
TARGET_HOME=
USER_SHELL=
SHELL_NAME=
OS_NAME=Void
IS_VOID=0
ARCH=
LIBC=
ROOT_KIND=none
RC_FILES=()

# Package catalog.  Names are case-sensitive xbps package names.
GROUP_CORE=(
	mangowc
	Waybar
	dunst
	swaybg
	fuzzel
	foot
	grim
	slurp
	satty
	ImageMagick
	wl-clipboard
	cliphist
	wl-clip-persist
	swaylock
	swayidle
	wlopm
	brightnessctl
	playerctl
	gammastep
	SwayOSD
	wf-recorder
	jq
)

GROUP_SESSION=(
	pipewire
	wireplumber
	libspa-bluetooth
	bluez
	polkit
	polkit-gnome
	dbus
	seatd
	dconf
	xdg-desktop-portal
	xdg-desktop-portal-wlr
	xdg-desktop-portal-gtk
	xorg-server-xwayland
	mesa-dri
	alsa-utils
	alsa-pipewire
	pulseaudio-utils
	libnotify
	util-linux
	glib
	fontconfig
	xdg-utils
	xdg-user-dirs
)

GROUP_CLI=(
	zsh
	zsh-autosuggestions
	zsh-syntax-highlighting
	git
	curl
	unzip
	fzf
	ripgrep
	fd
	zoxide
	eza
	bat
	neovim
	btop
	cmus
	lazygit
	python3
)

GROUP_THEME=(
	qt5ct
	qt6ct
	qt5-wayland
	qt6-wayland
	arc-theme
	papirus-icon-theme
	nerd-fonts-symbols-ttf
	noto-fonts-emoji
	dejavu-fonts-ttf
)

GROUP_APPS=(
	chromium
	imv
	mpv
	zathura
	impala
	bluetui
	pavucontrol
)

GROUP_EXTRAS=(
	flatpak
)

###############################################################################
# terminal / palette
###############################################################################

C_RESET=
C_HEAD=
C_OK=
C_WARN=
C_ERR=
C_LABEL=
C_DIM=
C_ACCENT=
FZF_COLORS=
FZF_COLOR_ARGS=()

palette_get() {
	local key=$1 fallback=$2 value
	if [ -n "$PALETTE_FILE" ] && [ -r "$PALETTE_FILE" ]; then
		value=$(awk -v k="$key" '$1 == k { print $2; exit }' "$PALETTE_FILE" 2>/dev/null || true)
	else
		value=
	fi
	case "$value" in
		\#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
		*) value=$fallback ;;
	esac
	printf '%s\n' "$value"
}

hex_to_rgb() {
	local hex=${1#\#}
	printf '%d %d %d\n' \
		"$((16#${hex:0:2}))" \
		"$((16#${hex:2:2}))" \
		"$((16#${hex:4:2}))"
}

color_fg() {
	local r g b
	read -r r g b < <(hex_to_rgb "$1")
	printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

init_colors() {
	if [ "$FORCE_NO_COLOR" -eq 1 ] || [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
		USE_COLOR=0
	else
		USE_COLOR=1
	fi

	if [ -r "${HOME:-}/.colors" ]; then
		PALETTE_FILE="$HOME/.colors"
	elif [ -r "$RICE_DIR/.colors" ]; then
		PALETTE_FILE="$RICE_DIR/.colors"
	fi

	local bg bg_panel bg_elem fg fg_bright gray dim border green green_br cyan
	local blue magenta yellow red
	bg=$(palette_get VD_BG '#1b1f23')
	bg_panel=$(palette_get VD_BG_PANEL '#20252a')
	bg_elem=$(palette_get VD_BG_ELEM '#252b30')
	fg=$(palette_get VD_FG '#c9d1cf')
	fg_bright=$(palette_get VD_FG_BRIGHT '#f0f4f2')
	gray=$(palette_get VD_GRAY '#8b949e')
	dim=$(palette_get VD_DIM '#5b626b')
	border=$(palette_get VD_BORDER '#505a63')
	green=$(palette_get VD_GREEN '#478061')
	green_br=$(palette_get VD_GREEN_BR '#6fae86')
	cyan=$(palette_get VD_CYAN '#68b0a8')
	blue=$(palette_get VD_BLUE '#6f9fd1')
	magenta=$(palette_get VD_MAGENTA '#b184c9')
	yellow=$(palette_get VD_YELLOW '#d8b26b')
	red=$(palette_get VD_RED '#c46a6a')

	if [ "$USE_COLOR" -eq 1 ]; then
		C_RESET=$'\033[0m'
		C_HEAD=$(color_fg "$green")
		C_OK=$(color_fg "$green_br")
		C_WARN=$(color_fg "$yellow")
		C_ERR=$(color_fg "$red")
		C_LABEL=$(color_fg "$gray")
		C_DIM=$(color_fg "$dim")
		C_ACCENT=$(color_fg "$cyan")
		FZF_COLORS="bg:${bg},bg+:${bg_elem},fg:${fg},fg+:${fg_bright},hl:${green_br},hl+:${green},info:${gray},prompt:${green},pointer:${green_br},marker:${magenta},spinner:${cyan},header:${gray},border:${border},label:${gray},query:${fg},disabled:${dim},preview-bg:${bg_panel},preview-border:${border}"
		FZF_COLOR_ARGS=(--color "$FZF_COLORS")
	else
		FZF_COLOR_ARGS=()
	fi
}

###############################################################################
# output helpers
###############################################################################

log() { printf '  %s\n' "$*"; }
section() { printf '\n%s== %s ==%s\n' "$C_HEAD" "$*" "$C_RESET"; }
ok() { printf '  %s✓%s %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_RESET" "$*"; }
fatal_line() { printf '  %s✗%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; }
hint() { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

die() {
	fatal_line "$*"
	if [ -n "${BACKUP_DIR:-}" ] && [ -d "$BACKUP_DIR" ]; then
		printf '  backup: %s\n' "$BACKUP_DIR" >&2
	fi
	exit 1
}

cleanup_paths=()
cleanup() {
	local p
	for p in "${cleanup_paths[@]}"; do
		[ -n "$p" ] && rm -rf "$p" 2>/dev/null || true
	done
}
on_error() {
	local code=$1 line=$2
	trap - ERR
	fatal_line "installer failed at line $line (exit $code)"
	if [ -n "${BACKUP_DIR:-}" ] && [ -d "$BACKUP_DIR" ]; then
		printf '  backup: %s\n' "$BACKUP_DIR" >&2
		printf '  restore: %s --restore %q\n' "$SETUP_PATH" "$BACKUP_DIR" >&2
	fi
	printf '  re-run with --dry-run to inspect the plan safely.\n' >&2
	exit "$code"
}
trap 'on_error $? $LINENO' ERR
trap cleanup EXIT

confirm() {
	local prompt=$1 default=${2:-y} reply
	if [ ! -t 0 ]; then
		return 1
	fi
	if [ "$default" = y ]; then
		printf '%s [Y/n] ' "$prompt"
	else
		printf '%s [y/N] ' "$prompt"
	fi
	read -r reply || return 1
	reply=${reply:-$default}
	case "$reply" in
		y|Y|yes|YES) return 0 ;;
		*) return 1 ;;
	esac
}

join_by() {
	local sep=$1 first=1 item
	shift
	for item in "$@"; do
		if [ "$first" -eq 1 ]; then
			first=0
		else
			printf '%s' "$sep"
		fi
		printf '%s' "$item"
	done
}

###############################################################################
# fzf
###############################################################################

FZF_BASE=(
	--height=80%
	--min-height=12
	--layout=reverse
	--sync
	--border=rounded
	--border-label=' void-musl-rice '
	--info=inline-right
	--header-first
	--pointer='▶'
	--marker='✓'
	--prompt='  '
)

fzf_pick() {
	local header=$1 prompt=$2
	shift 2
	[ "$#" -gt 0 ] || return 1
	printf '%s\n' "$@" | fzf "${FZF_BASE[@]}" "${FZF_COLOR_ARGS[@]}" \
		--delimiter=$'\t' --with-nth=2 --accept-nth=1 \
		--header "$header" --prompt "$prompt "
}

fzf_multi() {
	local header=$1 prompt=$2
	shift 2
	[ "$#" -gt 0 ] || return 1
	printf '%s\n' "$@" | fzf "${FZF_BASE[@]}" "${FZF_COLOR_ARGS[@]}" \
		--multi --delimiter=$'\t' --with-nth=2 --accept-nth=1 \
		--bind 'start:select-all' \
		--bind 'space:toggle+down' \
		--bind 'ctrl-a:select-all' \
		--bind 'ctrl-d:deselect-all' \
		--header "$header" --prompt "$prompt "
}

ensure_fzf() {
	command -v fzf >/dev/null 2>&1 && return 0
	if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
		die "fzf is required for the interactive menus but is not installed (xbps-install -S fzf)"
	fi
	warn "fzf is required for the interactive menus."
	if ! confirm "Install fzf now with xbps-install?" y; then
		die "fzf is required; install it with: sudo xbps-install -S fzf"
	fi
	if ! command -v xbps-install >/dev/null 2>&1; then
		die "fzf is missing; install it with your package manager and re-run."
	fi
	if [ "$ROOT_KIND" = none ]; then
		die "need sudo or root to install fzf; run: sudo xbps-install -S fzf"
	fi
	ensure_root || die "could not get root privileges for fzf"
	run_root xbps-install -Sy fzf || die "failed to install fzf"
	command -v fzf >/dev/null 2>&1 || die "fzf still not found after installation"
}

###############################################################################
# environment / options
###############################################################################

usage() {
	cat <<EOF
usage: $0 [options]

Interactive installer for the void-musl-rice desktop.  With no options it
walks through environment detection, install mode, components, package
groups, system actions, and a final review.

Modes:
  --copy                  copy/merge configs, keep app data (default)
  --link                  symlink configs from this repo
  --clean                 replace rice-managed config dirs (keeps cmus/gh/opencode data)
  --mode=copy|link|clean  explicit mode

Components (all selected by default):
  --no-configs            skip ~/.config, shell files, and ~/.local/bin
  --no-packages           skip xbps package installation
  --no-system             skip udev/limits/rc.local/groups/services
  --no-font               skip the JetBrainsMono Nerd Font download
  --no-wallpaper          skip wallpapers
  --no-gsettings          skip GTK/Qt desktop defaults
  --components=LIST       comma list: configs,packages,system,font,wallpaper,gsettings

Package groups (all selected by default):
  --package-groups=LIST   comma list: core,session,cli,theme,apps,extras

System actions:
  --no-udev               skip udev rules and immediate device permissions
  --no-limits             skip /etc/security/limits.d/20-nofile.conf
  --no-rclocal            skip the /etc/rc.local runtime-dir block
  --no-groups             skip video/input/_seatd group membership
  --no-services           skip dbus/polkitd/bluetoothd/seatd service links

Other:
  --yes, -y               non-interactive; use defaults and flags
  --dry-run, -n           print every action, change nothing
  --restore DIR           restore a rice-backup directory instead of installing
  --backup-dir DIR        write the backup to DIR instead of ~/rice-backup-<stamp>
  --no-backup             do not create a backup (not recommended)
  --no-color              plain output
  -h, --help              this help

Examples:
  ./setup.sh
  ./setup.sh --link
  ./setup.sh --yes --no-packages --no-system
  ./setup.sh --dry-run --yes
  ./setup.sh --restore ~/rice-backup-20261026-220000
EOF
}

parse_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--yes|-y) ASSUME_YES=1 ;;
			--dry-run|-n) DRY_RUN=1 ;;
			--no-color) FORCE_NO_COLOR=1 ;;
			--no-backup) NO_BACKUP=1 ;;
			--copy) MODE=copy; MODE_SET=1 ;;
			--link) MODE=link; MODE_SET=1 ;;
			--clean) MODE=clean; MODE_SET=1 ;;
			--mode=*) MODE=${1#*=}; MODE_SET=1 ;;
			--mode)
				shift
				[ "$#" -gt 0 ] || die "--mode needs copy, link, or clean"
				MODE=$1
				MODE_SET=1
				;;
			--no-configs) COMP_CONFIGS=0; COMPONENTS_SET=1 ;;
			--no-packages) COMP_PACKAGES=0; COMPONENTS_SET=1 ;;
			--no-system) COMP_SYSTEM=0; COMPONENTS_SET=1 ;;
			--no-font) COMP_FONT=0; COMPONENTS_SET=1 ;;
			--no-wallpaper) COMP_WALLPAPER=0; COMPONENTS_SET=1 ;;
			--no-gsettings) COMP_GSETTINGS=0; COMPONENTS_SET=1 ;;
			--no-udev) SYS_UDEV=0; SYS_ACTIONS_SET=1 ;;
			--no-limits) SYS_LIMITS=0; SYS_ACTIONS_SET=1 ;;
			--no-rclocal) SYS_RCLOCAL=0; SYS_ACTIONS_SET=1 ;;
			--no-groups) SYS_GROUPS=0; SYS_ACTIONS_SET=1 ;;
			--no-services) SYS_SERVICES=0; SYS_ACTIONS_SET=1 ;;
			--components=*) set_components_from_csv "${1#*=}" ;;
			--components)
				shift
				[ "$#" -gt 0 ] || die "--components needs a comma list"
				set_components_from_csv "$1"
				;;
			--package-groups=*) set_package_groups_from_csv "${1#*=}" ;;
			--package-groups)
				shift
				[ "$#" -gt 0 ] || die "--package-groups needs a comma list"
				set_package_groups_from_csv "$1"
				;;
			--backup-dir=*) BACKUP_DIR=${1#*=} ;;
			--backup-dir)
				shift
				[ "$#" -gt 0 ] || die "--backup-dir needs a path"
				BACKUP_DIR=$1
				;;
			--restore=*) RESTORE_DIR=${1#*=} ;;
			--restore)
				shift
				[ "$#" -gt 0 ] || die "--restore needs a backup directory"
				RESTORE_DIR=$1
				;;
			--help|-h) usage; exit 0 ;;
			--) shift; break ;;
			-*) die "unknown option: $1 (try --help)" ;;
			*) die "unexpected argument: $1 (try --help)" ;;
		esac
		shift
	done

	case "$MODE" in
		copy|link|clean) ;;
		*) die "invalid mode: $MODE (use copy, link, or clean)" ;;
	esac

	if [ "$SYS_UDEV$SYS_LIMITS$SYS_RCLOCAL$SYS_GROUPS$SYS_SERVICES" = "00000" ]; then
		COMP_SYSTEM=0
	fi
}

set_components_from_csv() {
	local csv=$1 item
	local -a items=()
	COMP_CONFIGS=0
	COMP_PACKAGES=0
	COMP_SYSTEM=0
	COMP_FONT=0
	COMP_WALLPAPER=0
	COMP_GSETTINGS=0
	IFS=',' read -r -a items <<< "$csv"
	for item in "${items[@]}"; do
		item=${item//[[:space:]]/}
		[ -n "$item" ] || continue
		case "$item" in
			configs) COMP_CONFIGS=1 ;;
			packages) COMP_PACKAGES=1 ;;
			system) COMP_SYSTEM=1 ;;
			font) COMP_FONT=1 ;;
			wallpaper) COMP_WALLPAPER=1 ;;
			gsettings) COMP_GSETTINGS=1 ;;
			*) die "unknown component: $item" ;;
		esac
	done
	COMPONENTS_SET=1
}

set_package_groups_from_csv() {
	local csv=$1 item
	local -a items=() valid=()
	IFS=',' read -r -a items <<< "$csv"
	for item in "${items[@]}"; do
		item=${item//[[:space:]]/}
		[ -n "$item" ] || continue
		case "$item" in
			core|session|cli|theme|apps|extras) valid+=("$item") ;;
			*) die "unknown package group: $item" ;;
		esac
	done
	[ "${#valid[@]}" -gt 0 ] || die "--package-groups selected nothing"
	SELECTED_GROUPS=("${valid[@]}")
	PKG_GROUPS_SET=1
}

detect_environment() {
	[ -n "${HOME:-}" ] || die "HOME is not set"
	[ -d "$RICE_DIR/.config" ] || die "no .config next to this script ($RICE_DIR)"
	if [ "$(id -u)" -eq 0 ]; then
		if [ -n "${SUDO_USER:-}" ]; then
			die "run as $SUDO_USER, not root; the installer uses sudo for system steps"
		fi
		die "run as your normal user, not root; the installer uses sudo for system steps"
	fi

	TARGET_USER=$(id -un)
	TARGET_UID=$(id -u)
	TARGET_HOME=$HOME

	if [ -r /etc/os-release ]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		OS_NAME=${PRETTY_NAME:-${NAME:-Void}}
	fi
	if command -v xbps-install >/dev/null 2>&1; then
		IS_VOID=1
	fi

	ARCH=$(xbps-uhelper arch 2>/dev/null || uname -m)
	if command -v ldd >/dev/null 2>&1; then
		LIBC=$(ldd --version 2>&1 | head -n 1 || true)
	fi
	case "$LIBC" in
		*musl*) LIBC=musl ;;
		*GLIBC*|*glibc*|*GNU*) LIBC=glibc ;;
		*)	case "$ARCH" in *musl*) LIBC=musl ;; *) LIBC=glibc ;; esac ;;
	esac

	if command -v getent >/dev/null 2>&1; then
		USER_SHELL=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7 || true)
	fi
	if [ -z "$USER_SHELL" ] && [ -r /etc/passwd ]; then
		USER_SHELL=$(awk -F: -v u="$TARGET_USER" '$1 == u { print $7; exit }' /etc/passwd)
	fi
	USER_SHELL=${USER_SHELL:-${SHELL:-/bin/sh}}
	SHELL_NAME=$(basename "$USER_SHELL")

	case "$SHELL_NAME" in
		zsh) RC_FILES=(.zshenv .zprofile .zshrc .zlogin .zlogout) ;;
		bash) RC_FILES=(.bashrc .bash_profile .bash_login .bash_logout .profile) ;;
		ksh) RC_FILES=(.profile .kshrc) ;;
		csh|tcsh) RC_FILES=(.cshrc .login .tcshrc) ;;
		fish) RC_FILES=(.config/fish) ;;
		*) RC_FILES=(.profile .bashrc .zshrc) ;;
	esac

	if command -v sudo >/dev/null 2>&1; then
		ROOT_KIND=sudo
	else
		ROOT_KIND=none
	fi
}

ensure_root() {
	if [ "$ROOT_KIND" = none ]; then
		return 1
	fi
	if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
		sudo -n -v 2>/dev/null || return 1
	else
		sudo -v || return 1
	fi
	return 0
}

run_root() {
	if [ "$ROOT_KIND" = none ]; then
		return 1
	fi
	sudo "$@"
}

print_environment() {
	section "Environment"
	printf '  %-12s %s\n' "rice" "$RICE_DIR"
	printf '  %-12s %s\n' "target" "$TARGET_HOME"
	printf '  %-12s %s\n' "user" "$TARGET_USER"
	printf '  %-12s %s\n' "os" "$OS_NAME"
	printf '  %-12s %s / %s\n' "platform" "$ARCH" "$LIBC"
	printf '  %-12s %s (%s)\n' "shell" "$SHELL_NAME" "$USER_SHELL"
	if [ "$IS_VOID" -eq 0 ]; then
		warn "xbps-install was not found; package and system steps will print manual commands."
	fi
	if [ -n "$PALETTE_FILE" ]; then
		printf '  %-12s %s\n' "palette" "$PALETTE_FILE"
	else
		warn "no .colors found; using the built-in void-dark fallback palette."
	fi
}

###############################################################################
# selection menus
###############################################################################

mode_label() {
	case "$MODE" in
		copy) printf 'copy + merge' ;;
		link) printf 'symlink (dotfiles mode)' ;;
		clean) printf 'copy + clean' ;;
	esac
}

component_label() {
	case "$1" in
		configs) printf 'configs + shell files + scripts' ;;
		packages) printf 'xbps packages' ;;
		system) printf 'system integration' ;;
		font) printf 'JetBrainsMono Nerd Font' ;;
		wallpaper) printf 'wallpapers' ;;
		gsettings) printf 'GTK/Qt defaults' ;;
	esac
}

selected_components() {
	local -a out=()
	[ "$COMP_CONFIGS" -eq 1 ] && out+=("configs")
	[ "$COMP_PACKAGES" -eq 1 ] && out+=("packages")
	[ "$COMP_SYSTEM" -eq 1 ] && out+=("system")
	[ "$COMP_FONT" -eq 1 ] && out+=("font")
	[ "$COMP_WALLPAPER" -eq 1 ] && out+=("wallpaper")
	[ "$COMP_GSETTINGS" -eq 1 ] && out+=("gsettings")
	[ "${#out[@]}" -gt 0 ] || return 1
	printf '%s\n' "${out[@]}"
}

menu_mode() {
	local choice
	choice=$(fzf_pick \
		$'Choose how the rice files should be installed.\nTAB is not needed here; ENTER selects, ESC cancels.' \
		"Mode" \
		$'copy\tCopy + merge — keep app data (recommended)' \
		$'link\tSymlink this repo — edits are live, repo becomes the source' \
		$'clean\tCopy + clean — replace rice-managed dirs, keep user data') || return 1
	case "$choice" in
		copy|link|clean) MODE=$choice; MODE_SET=1 ;;
		*) return 1 ;;
	esac
}

menu_components() {
	local selected id
	selected=$(fzf_multi \
		$'SPACE/TAB toggle · CTRL-A all · CTRL-D none · ENTER confirm\nAll components start selected.' \
		"Components" \
		$'configs\tConfigs, shell startup files, and ~/.local/bin scripts' \
		$'packages\tInstall xbps packages (choose groups next)' \
		$'system\tudev, limits, rc.local, groups, and services' \
		$'font\tDownload JetBrainsMono Nerd Font' \
		$'wallpaper\tInstall wallpapers into ~/Pictures' \
		$'gsettings\tApply GTK/Qt desktop defaults') || return 1
	[ -n "$selected" ] || return 1

	COMP_CONFIGS=0
	COMP_PACKAGES=0
	COMP_SYSTEM=0
	COMP_FONT=0
	COMP_WALLPAPER=0
	COMP_GSETTINGS=0
	while IFS= read -r id; do
		[ -n "$id" ] || continue
		case "$id" in
			configs) COMP_CONFIGS=1 ;;
			packages) COMP_PACKAGES=1 ;;
			system) COMP_SYSTEM=1 ;;
			font) COMP_FONT=1 ;;
			wallpaper) COMP_WALLPAPER=1 ;;
			gsettings) COMP_GSETTINGS=1 ;;
		esac
	done <<< "$selected"

	[ "$COMP_CONFIGS$COMP_PACKAGES$COMP_SYSTEM$COMP_FONT$COMP_WALLPAPER$COMP_GSETTINGS" != "000000" ] || return 1
	COMPONENTS_SET=1
}

group_packages() {
	case "$1" in
		core) printf '%s\n' "${GROUP_CORE[@]}" ;;
		session) printf '%s\n' "${GROUP_SESSION[@]}" ;;
		cli) printf '%s\n' "${GROUP_CLI[@]}" ;;
		theme) printf '%s\n' "${GROUP_THEME[@]}" ;;
		apps) printf '%s\n' "${GROUP_APPS[@]}" ;;
		extras) printf '%s\n' "${GROUP_EXTRAS[@]}" ;;
	esac
}

group_count() {
	local -a pkgs=()
	mapfile -t pkgs < <(group_packages "$1")
	printf '%s' "${#pkgs[@]}"
}

menu_package_groups() {
	local selected id
	selected=$(fzf_multi \
		$'SPACE/TAB toggle · CTRL-A all · CTRL-D none · ENTER confirm\nOnly missing packages are installed; unavailable ones are skipped.' \
		"Package groups" \
		$'core\tCore desktop — mango, waybar, foot, fuzzel, dunst, clipboard, screenshots ('"$(group_count core)"' pkgs)' \
		$'session\tSession/system — pipewire, bluez, portals, seatd, Qt/GTK deps ('"$(group_count session)"' pkgs)' \
		$'cli\tCLI/tools — zsh, fzf, git, neovim, btop, cmus, py ('"$(group_count cli)"' pkgs)' \
		$'theme\tTheming/fonts — Qt, Arc, Papirus, Nerd Font symbols ('"$(group_count theme)"' pkgs)' \
		$'apps\tApps — chromium, imv, mpv, zathura, network/audio GUIs ('"$(group_count apps)"' pkgs)' \
		$'extras\tExtras — flatpak ('"$(group_count extras)"' pkgs)') || return 1
	[ -n "$selected" ] || return 1

	local -a groups=()
	while IFS= read -r id; do
		[ -n "$id" ] || continue
		groups+=("$id")
	done <<< "$selected"
	[ "${#groups[@]}" -gt 0 ] || return 1
	SELECTED_GROUPS=("${groups[@]}")
	PKG_GROUPS_SET=1
}

system_actions_label() {
	case "$1" in
		udev) printf 'udev rules + backlight/fan permissions' ;;
		limits) printf 'high nofile limit' ;;
		rclocal) printf '/etc/rc.local runtime dir' ;;
		groups) printf 'video/input/_seatd groups' ;;
		services) printf 'dbus/polkitd/bluetoothd/seatd services' ;;
	esac
}

menu_system_actions() {
	local selected id
	selected=$(fzf_multi \
		$'SPACE/TAB toggle · CTRL-A all · CTRL-D none · ENTER confirm\nThese actions use sudo; you will be asked once.' \
		"System actions" \
		$'udev\tudev rules + immediate backlight/fan permissions' \
		$'limits\t/etc/security/limits.d/20-nofile.conf' \
		$'rclocal\t/etc/rc.local: create /run/user/$UID at boot' \
		$'groups\tadd video, input, _seatd groups' \
		$'services\tenable dbus, polkitd, bluetoothd, seatd') || return 1

	SYS_UDEV=0
	SYS_LIMITS=0
	SYS_RCLOCAL=0
	SYS_GROUPS=0
	SYS_SERVICES=0
	if [ -n "$selected" ]; then
		while IFS= read -r id; do
			[ -n "$id" ] || continue
			case "$id" in
				udev) SYS_UDEV=1 ;;
				limits) SYS_LIMITS=1 ;;
				rclocal) SYS_RCLOCAL=1 ;;
				groups) SYS_GROUPS=1 ;;
				services) SYS_SERVICES=1 ;;
			esac
		done <<< "$selected"
	fi
	if [ "$SYS_UDEV$SYS_LIMITS$SYS_RCLOCAL$SYS_GROUPS$SYS_SERVICES" = "00000" ]; then
		COMP_SYSTEM=0
		warn "no system actions selected; system integration disabled."
	fi
}

selected_system_actions() {
	local -a out=()
	[ "$SYS_UDEV" -eq 1 ] && out+=("udev")
	[ "$SYS_LIMITS" -eq 1 ] && out+=("limits")
	[ "$SYS_RCLOCAL" -eq 1 ] && out+=("rclocal")
	[ "$SYS_GROUPS" -eq 1 ] && out+=("groups")
	[ "$SYS_SERVICES" -eq 1 ] && out+=("services")
	[ "${#out[@]}" -gt 0 ] || return 1
	printf '%s\n' "${out[@]}"
}

collect_selected_packages() {
	local group pkg
	local -A seen=()
	SELECTED_PKGS=()
	for group in "${SELECTED_GROUPS[@]}"; do
		while IFS= read -r pkg; do
			[ -n "$pkg" ] || continue
			[ -n "${seen[$pkg]:-}" ] && continue
			seen[$pkg]=1
			SELECTED_PKGS+=("$pkg")
		done < <(group_packages "$group")
	done
}

summarize_components() {
	local -a labels=()
	local id
	while IFS= read -r id; do
		labels+=("$(component_label "$id")")
	done < <(selected_components || true)
	join_by ', ' "${labels[@]}"
}

summarize_system() {
	local -a labels=()
	local id
	while IFS= read -r id; do
		labels+=("$(system_actions_label "$id")")
	done < <(selected_system_actions || true)
	join_by ', ' "${labels[@]}"
}

print_summary() {
	section "Plan"
	printf '  %-13s %s\n' "mode" "$(mode_label)"
	printf '  %-13s %s\n' "components" "$(summarize_components)"
	printf '  %-13s %s\n' "dry run" "$([ "$DRY_RUN" -eq 1 ] && printf 'yes — nothing will be changed' || printf 'no')"

	if [ "$COMP_PACKAGES" -eq 1 ]; then
		collect_selected_packages
		printf '  %-13s %s (%s packages)\n' "package groups" "$(join_by ', ' "${SELECTED_GROUPS[@]}")" "${#SELECTED_PKGS[@]}"
	else
		printf '  %-13s %s\n' "package groups" "skipped"
	fi

	if [ "$COMP_SYSTEM" -eq 1 ]; then
		printf '  %-13s %s\n' "system" "$(summarize_system)"
	else
		printf '  %-13s %s\n' "system" "skipped"
	fi

	if [ "$NO_BACKUP" -eq 1 ]; then
		printf '  %-13s %s\n' "backup" "disabled (--no-backup)"
	else
		printf '  %-13s %s\n' "backup" "${BACKUP_DIR:-$HOME/rice-backup-<timestamp>}"
	fi

	if [ "$MODE" = clean ]; then
		warn "clean mode replaces rice-managed config dirs; cmus/gh/opencode user data is preserved."
	fi
	if [ "$COMP_CONFIGS" -eq 0 ] && [ "$COMP_PACKAGES" -eq 0 ] && [ "$COMP_SYSTEM" -eq 0 ] \
		&& [ "$COMP_FONT" -eq 0 ] && [ "$COMP_WALLPAPER" -eq 0 ] && [ "$COMP_GSETTINGS" -eq 0 ]; then
		die "nothing selected"
	fi
}

review_loop() {
	local action
	while :; do
		print_summary
		action=$(fzf_pick \
			$'Review the plan. ENTER starts; ESC cancels.' \
			"Action" \
			$'start\tStart install' \
			$'mode\tChange install mode' \
			$'components\tChange components' \
			$'packages\tChange package groups' \
			$'system\tChange system actions' \
			$'cancel\tCancel') || die "cancelled"
		case "$action" in
			start) return 0 ;;
			mode) menu_mode || true ;;
			components) menu_components || true ;;
			packages)
				if [ "$COMP_PACKAGES" -eq 1 ]; then
					menu_package_groups || true
				else
					warn "packages are not enabled; select the packages component first."
				fi
				;;
			system)
				if [ "$COMP_SYSTEM" -eq 1 ]; then
					menu_system_actions || true
				else
					warn "system integration is not enabled; select the system component first."
				fi
				;;
			cancel) die "cancelled" ;;
		esac
	done
}

interactive_flow() {
	if [ "$MODE_SET" -eq 0 ]; then
		menu_mode || die "cancelled"
	fi
	if [ "$COMPONENTS_SET" -eq 0 ]; then
		menu_components || die "cancelled"
	fi
	if [ "$COMP_PACKAGES" -eq 1 ] && [ "$PKG_GROUPS_SET" -eq 0 ]; then
		menu_package_groups || die "cancelled"
	fi
	if [ "$COMP_SYSTEM" -eq 1 ] && [ "$SYS_ACTIONS_SET" -eq 0 ]; then
		menu_system_actions || die "cancelled"
	fi
	review_loop
}

###############################################################################
# backup / restore
###############################################################################

next_backup_dir() {
	local base=$1 dir=$1 n=1
	while [ -e "$dir" ]; do
		dir="${base}-$n"
		n=$((n + 1))
	done
	printf '%s\n' "$dir"
}

backup_tar() {
	local archive=$1
	shift
	if [ "$#" -eq 0 ]; then
		return 0
	fi
	if tar -czf "$BACKUP_DIR/$archive" -C "$HOME" "$@" 2>/dev/null; then
		log "$archive"
	else
		warn "could not create $archive"
	fi
}

system_backup() {
	local -a files=()
	local f
	for f in \
		/etc/rc.local \
		/etc/udev/rules.d/90-backlight.rules \
		/etc/udev/rules.d/90-fan.rules \
		/etc/security/limits.d/20-nofile.conf; do
		[ -e "$f" ] && files+=("$f")
	done
	[ "${#files[@]}" -gt 0 ] || return 0
	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would back up system files"
		return 0
	fi
	if ! ensure_root; then
		warn "system files were not backed up (sudo unavailable)"
		return 0
	fi
	if run_root tar -czf "$BACKUP_DIR/system.tar.gz" "${files[@]}" 2>/dev/null; then
		run_root chown "$TARGET_USER:$TARGET_USER" "$BACKUP_DIR/system.tar.gz" 2>/dev/null || true
		log "system.tar.gz"
	else
		warn "could not create system.tar.gz"
	fi
}

make_backup() {
	if [ "$NO_BACKUP" -eq 1 ]; then
		BACKUP_DIR=
		warn "backup disabled (--no-backup)"
		return 0
	fi
	if [ -z "$BACKUP_DIR" ]; then
		BACKUP_DIR=$(next_backup_dir "$HOME/rice-backup-$(date +%Y%m%d-%H%M%S)")
	fi
	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would create backup: $BACKUP_DIR"
		return 0
	fi
	mkdir -p "$BACKUP_DIR"

	section "Backing up"
	local backup_rel=
	case "$BACKUP_DIR" in
		"$HOME"/*) backup_rel=${BACKUP_DIR#"$HOME"/} ;;
	esac
	if [ -e "$HOME/.config" ]; then
		local -a tar_args=(--exclude='.config/chromium' --exclude='*/node_modules' --exclude='*/Cache')
		if [ -n "$backup_rel" ]; then
			tar_args+=("--exclude=$backup_rel")
		fi
		if tar -czf "$BACKUP_DIR/config.tar.gz" "${tar_args[@]}" -C "$HOME" .config 2>/dev/null; then
			log "config.tar.gz"
		else
			warn "could not create config.tar.gz"
		fi
	else
		log "no ~/.config to back up"
	fi

	local -a files=()
	local f
	for f in "${RC_FILES[@]}" "${RICE_HOME_FILES[@]}"; do
		if [ -e "$HOME/$f" ]; then
			case " ${files[*]-} " in
				*" $f "*) continue ;;
			esac
			files+=("$f")
		fi
	done
	backup_tar shell-rc.tar.gz "${files[@]}"

	if [ -d "$HOME/.local/bin" ]; then
		backup_tar local-bin.tar.gz .local/bin
	fi
	local -a wallpaper_backup=()
	local wp target
	if [ "$COMP_WALLPAPER" -eq 1 ]; then
		for wp in "$RICE_DIR"/wallpapers/*; do
			[ -e "$wp" ] || continue
			target="Pictures/$(basename "$wp")"
			[ -e "$HOME/$target" ] && wallpaper_backup+=("$target")
		done
	fi
	backup_tar wallpaper.tar.gz "${wallpaper_backup[@]}"
	if [ -d "$HOME/.local/share/fonts/JetBrainsMonoNerdFont" ]; then
		backup_tar fonts.tar.gz .local/share/fonts/JetBrainsMonoNerdFont
	fi
	if [ "$COMP_SYSTEM" -eq 1 ]; then
		system_backup
	fi

	local restore_lines=""
	local archive
	for archive in config.tar.gz shell-rc.tar.gz local-bin.tar.gz wallpaper.tar.gz fonts.tar.gz; do
		if [ -f "$BACKUP_DIR/$archive" ]; then
			restore_lines+="  tar -xzf \"$BACKUP_DIR/$archive\" -C \"$HOME\""$'\n'
		fi
	done
	if [ -f "$BACKUP_DIR/system.tar.gz" ]; then
		restore_lines+="  sudo tar -xzf \"$BACKUP_DIR/system.tar.gz\" -C /"$'\n'
	fi

	cat > "$BACKUP_DIR/MANIFEST" <<EOF
void-musl-rice backup
created: $(date -Is)
user: $TARGET_USER
home: $TARGET_HOME
platform: $ARCH / $LIBC
mode: $MODE
components: $(summarize_components)
package groups: $(if [ "$COMP_PACKAGES" -eq 1 ]; then join_by ', ' "${SELECTED_GROUPS[@]}"; else printf 'skipped'; fi)
system: $(if [ "$COMP_SYSTEM" -eq 1 ]; then summarize_system; else printf 'skipped'; fi)

restore:
$restore_lines
or:
  $SETUP_PATH --restore "$BACKUP_DIR"
EOF
	ok "backup: $BACKUP_DIR"
}

restore_backup() {
	local dir=$1
	[ -d "$dir" ] || die "backup directory not found: $dir"
	section "Restoring"
	printf '  %-12s %s\n' "backup" "$dir"
	if [ -f "$dir/MANIFEST" ]; then
		printf '\n'
		sed 's/^/  /' "$dir/MANIFEST"
		printf '\n'
	fi
	if [ "$ASSUME_YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
		confirm "Restore this backup over the current files?" y || die "cancelled"
	fi

	local archive
	for archive in config.tar.gz shell-rc.tar.gz local-bin.tar.gz wallpaper.tar.gz fonts.tar.gz; do
		if [ ! -f "$dir/$archive" ]; then
			continue
		fi
		if [ "$DRY_RUN" -eq 1 ]; then
			log "[dry-run] tar -xzf $dir/$archive -C $HOME"
		else
			if tar -xzf "$dir/$archive" -C "$HOME"; then
				ok "$archive"
			else
				warn "failed to restore $archive"
			fi
		fi
	done

	if [ -f "$dir/system.tar.gz" ]; then
		if [ "$DRY_RUN" -eq 1 ]; then
			log "[dry-run] sudo tar -xzf $dir/system.tar.gz -C /"
		elif ensure_root; then
			if run_root tar -xzf "$dir/system.tar.gz" -C /; then
				ok "system.tar.gz"
			else
				warn "failed to restore system.tar.gz"
			fi
		else
			warn "system.tar.gz needs root; run manually:"
			log "sudo tar -xzf $dir/system.tar.gz -C /"
		fi
	fi

	if [ "$DRY_RUN" -eq 0 ]; then
		if command -v fc-cache >/dev/null 2>&1; then
			fc-cache -f >/dev/null 2>&1 || true
		fi
		if command -v bat >/dev/null 2>&1; then
			bat cache --build >/dev/null 2>&1 || true
		fi
		ok "restore complete"
	fi
}

###############################################################################
# packages
###############################################################################

package_availability_works() {
	command -v xbps-query >/dev/null 2>&1 || return 1
	xbps-query -R -p pkgver base-files >/dev/null 2>&1
}

package_available() {
	local pkg=$1
	if [ -n "${AVAIL_CACHE[$pkg]:-}" ]; then
		[ "${AVAIL_CACHE[$pkg]}" = 1 ]
		return
	fi
	if xbps-query -R -p pkgver "$pkg" >/dev/null 2>&1; then
		AVAIL_CACHE[$pkg]=1
		return 0
	fi
	AVAIL_CACHE[$pkg]=0
	return 1
}

print_manual_packages() {
	local -a pkgs=("$@")
	warn "need sudo/root for package installation; run manually:"
	printf '  sudo xbps-install -Sy %s\n' "${pkgs[*]}"
}

install_packages() {
	[ "$COMP_PACKAGES" -eq 1 ] || return 0
	section "Packages"
	collect_selected_packages
	if [ "${#SELECTED_PKGS[@]}" -eq 0 ]; then
		warn "no package groups selected"
		return 0
	fi

	local -A installed=()
	local pkg name installed_raw
	if command -v xbps-query >/dev/null 2>&1; then
		installed_raw=$(xbps-query -l 2>/dev/null | awk '{ n=$2; sub(/-[0-9].*$/, "", n); print n }' || true)
		while IFS= read -r name; do
			[ -n "$name" ] && installed[$name]=1
		done <<< "$installed_raw"
	fi

	local -a already=() to_install=() unavailable=()
	for pkg in "${SELECTED_PKGS[@]}"; do
		if [ -n "${installed[$pkg]:-}" ]; then
			already+=("$pkg")
		else
			to_install+=("$pkg")
		fi
	done
	log "${#already[@]} already installed, ${#to_install[@]} missing"

	if [ "${#to_install[@]}" -eq 0 ]; then
		ok "all selected packages are already installed"
		return 0
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would sync xbps and install:"
		printf '    %s\n' "${to_install[*]}"
		return 0
	fi

	if ! command -v xbps-install >/dev/null 2>&1; then
		warn "xbps-install not found; install these with your package manager:"
		printf '    %s\n' "${to_install[*]}"
		PACKAGE_FAILED=1
		return 0
	fi

	AVAIL_CACHE=()
	local availability_ok=0
	if package_availability_works; then
		availability_ok=1
		local -a filtered=()
		for pkg in "${to_install[@]}"; do
			if package_available "$pkg"; then
				filtered+=("$pkg")
			else
				unavailable+=("$pkg")
			fi
		done
		to_install=("${filtered[@]}")
	fi
	if [ "${#unavailable[@]}" -gt 0 ]; then
		warn "not available in this repo; skipped: ${unavailable[*]}"
	fi
	if [ "${#to_install[@]}" -eq 0 ]; then
		warn "nothing installable remains"
		return 0
	fi

	if [ "$ROOT_KIND" = none ] || ! ensure_root; then
		print_manual_packages "${to_install[@]}"
		PACKAGE_FAILED=1
		return 0
	fi

	run_root xbps-install -S >/dev/null 2>&1 || warn "xbps repository sync failed; continuing with cached metadata"

	if [ "$availability_ok" -eq 0 ] && package_availability_works; then
		local -a filtered=()
		unavailable=()
		for pkg in "${to_install[@]}"; do
			if package_available "$pkg"; then
				filtered+=("$pkg")
			else
				unavailable+=("$pkg")
			fi
		done
		to_install=("${filtered[@]}")
		if [ "${#unavailable[@]}" -gt 0 ]; then
			warn "not available in this repo; skipped: ${unavailable[*]}"
		fi
		if [ "${#to_install[@]}" -eq 0 ]; then
			warn "nothing installable remains"
			return 0
		fi
	fi

	if [ "${#to_install[@]}" -eq 1 ]; then
		log "installing 1 package:"
	else
		log "installing ${#to_install[@]} packages:"
	fi
	printf '    %s\n' "${to_install[*]}"
	if run_root xbps-install -y "${to_install[@]}"; then
		ok "packages installed"
	else
		warn "xbps-install failed; config installation will continue"
		PACKAGE_FAILED=1
	fi
}

###############################################################################
# system integration
###############################################################################

print_manual_system() {
	local action
	for action in "$@"; do
		case "$action" in
			udev)
				log "sudo install -d /etc/udev/rules.d"
				log "sudo install -m644 $RICE_DIR/etc/udev/rules.d/*.rules /etc/udev/rules.d/"
				log "sudo udevadm control --reload"
				log "sudo chgrp video /sys/class/backlight/*/brightness && sudo chmod g+w /sys/class/backlight/*/brightness"
				log "sudo sh $RICE_DIR/etc/fan-perms.sh"
				;;
			limits)
				log "sudo install -m644 $RICE_DIR/etc/security/limits.d/20-nofile.conf /etc/security/limits.d/"
				;;
			rclocal)
				log 'sed -e "s|__USER__|'"$TARGET_USER"'|g" -e "s|__UID__|'"$TARGET_UID"'|g" '"$RICE_DIR"'/etc/rc.local.rice | sudo tee -a /etc/rc.local'
				log "sudo chmod 755 /etc/rc.local"
				log "sudo install -d -m 700 -o $TARGET_USER -g $TARGET_USER /run/user/$TARGET_UID"
				;;
			groups)
				log "sudo usermod -aG video,input,_seatd $TARGET_USER"
				;;
			services)
				log "sudo mkdir -p /var/service"
				log "sudo ln -s /etc/sv/dbus /etc/sv/polkitd /etc/sv/bluetoothd /etc/sv/seatd /var/service/"
				;;
		esac
	done
}

apply_udev() {
	local f bl
	run_root mkdir -p /etc/udev/rules.d
	for f in "$RICE_DIR"/etc/udev/rules.d/*.rules; do
		[ -e "$f" ] || continue
		run_root install -m644 "$f" /etc/udev/rules.d/ || warn "could not install $(basename "$f")"
	done
	if command -v udevadm >/dev/null 2>&1; then
		run_root udevadm control --reload 2>/dev/null || true
		run_root udevadm trigger --subsystem-match=backlight 2>/dev/null || true
		run_root udevadm trigger --subsystem-match=hwmon 2>/dev/null || true
	fi
	for bl in /sys/class/backlight/*; do
		[ -e "$bl/brightness" ] || continue
		if run_root chgrp video "$bl/brightness" 2>/dev/null &&
			run_root chmod g+w "$bl/brightness" 2>/dev/null; then
			log "backlight write access: $(basename "$bl")"
		fi
	done
	if [ -f "$RICE_DIR/etc/fan-perms.sh" ]; then
		run_root sh "$RICE_DIR/etc/fan-perms.sh" || warn "fan permission helper failed"
	fi
}

apply_limits() {
	if [ -f "$RICE_DIR/etc/security/limits.d/20-nofile.conf" ]; then
		run_root mkdir -p /etc/security/limits.d
		run_root install -m644 "$RICE_DIR/etc/security/limits.d/20-nofile.conf" /etc/security/limits.d/
		ok "limits.d/20-nofile.conf"
	fi
}

apply_rclocal() {
	if [ ! -f "$RICE_DIR/etc/rc.local.rice" ]; then
		warn "etc/rc.local.rice not found"
		return 0
	fi
	if run_root grep -q 'void-musl-rice runtime dir' /etc/rc.local 2>/dev/null; then
		ok "/etc/rc.local runtime block already present"
	else
		local tmp
		tmp=$(mktemp)
		cleanup_paths+=("$tmp")
		sed -e "s|__USER__|$TARGET_USER|g" -e "s|__UID__|$TARGET_UID|g" \
			"$RICE_DIR/etc/rc.local.rice" > "$tmp"
		if [ ! -e /etc/rc.local ]; then
			printf '#!/bin/sh\n\n' | run_root tee /etc/rc.local >/dev/null
			run_root chmod 755 /etc/rc.local
		fi
		run_root tee -a /etc/rc.local < "$tmp" >/dev/null
		ok "/etc/rc.local runtime block"
	fi
	run_root chmod 755 /etc/rc.local 2>/dev/null || true
	run_root install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "/run/user/$TARGET_UID" 2>/dev/null || true
	log "/run/user/$TARGET_UID ready for this boot"
}

group_exists() {
	local grp=$1
	if command -v getent >/dev/null 2>&1; then
		getent group "$grp" >/dev/null 2>&1
	else
		grep -q "^$grp:" /etc/group 2>/dev/null
	fi
}

apply_groups() {
	local grp
	for grp in video input _seatd; do
		if ! group_exists "$grp"; then
			warn "group $grp does not exist; skipped"
			continue
		fi
		if id -nG "$TARGET_USER" 2>/dev/null | tr ' ' '\n' | grep -x "$grp" >/dev/null 2>&1; then
			log "$TARGET_USER already in group $grp"
		elif run_root usermod -aG "$grp" "$TARGET_USER"; then
			ok "added $TARGET_USER to group $grp"
			SYSTEM_CHANGED=1
		else
			warn "could not add $TARGET_USER to group $grp"
		fi
	done
}

apply_services() {
	local svc
	run_root mkdir -p /var/service
	for svc in dbus polkitd bluetoothd seatd; do
		[ -d "/etc/sv/$svc" ] || continue
		if [ -e "/var/service/$svc" ]; then
			log "service already enabled: $svc"
		elif run_root ln -s "/etc/sv/$svc" /var/service/; then
			ok "enabled service: $svc"
			SYSTEM_CHANGED=1
		else
			warn "could not enable service: $svc"
		fi
	done
}

install_system() {
	[ "$COMP_SYSTEM" -eq 1 ] || return 0
	local -a actions=()
	mapfile -t actions < <(selected_system_actions || true)
	[ "${#actions[@]}" -gt 0 ] || return 0
	section "System integration"

	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would apply: ${actions[*]}"
		print_manual_system "${actions[@]}"
		return 0
	fi

	if [ "$ROOT_KIND" = none ] || ! ensure_root; then
		warn "need sudo/root; system steps were skipped."
		print_manual_system "${actions[@]}"
		return 0
	fi

	local action
	for action in "${actions[@]}"; do
		case "$action" in
			udev) apply_udev ;;
			limits) apply_limits ;;
			rclocal) apply_rclocal ;;
			groups) apply_groups ;;
			services) apply_services ;;
		esac
	done
}

###############################################################################
# config installation
###############################################################################

install_path() {
	local src=$1 dest=$2
	[ -e "$src" ] || return 0
	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] $MODE: ${src#"$RICE_DIR"/} -> $dest"
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	case "$MODE" in
		link)
			rm -rf "$dest"
			ln -s "$src" "$dest"
			;;
		clean)
			rm -rf "$dest"
			cp -a "$src" "$dest"
			;;
		copy)
			if [ -L "$dest" ]; then
				rm -f "$dest"
			fi
			if [ -d "$src" ]; then
				mkdir -p "$dest"
				cp -a "$src/." "$dest/"
			else
				cp -a "$src" "$dest"
			fi
			;;
	esac
}

ensure_dir() {
	if [ "$DRY_RUN" -eq 1 ]; then
		return 0
	fi
	mkdir -p "$@"
}

install_configs() {
	[ "$COMP_CONFIGS" -eq 1 ] || return 0
	section "Configs"
	ensure_dir "$HOME/.config" "$HOME/.local/bin"

	local item name f
	shopt -s nullglob dotglob
	for item in "$RICE_DIR/.config"/*; do
		name=$(basename "$item")
		case "$name" in
			cmus)
				ensure_dir "$HOME/.config/cmus"
				install_path "$item/rc" "$HOME/.config/cmus/rc"
				log ".config/cmus/rc (autosave/playlists kept)"
				;;
			gh)
				install_path "$item/config.yml" "$HOME/.config/gh/config.yml"
				log ".config/gh/config.yml (hosts.yml kept)"
				;;
			opencode)
				ensure_dir "$HOME/.config/opencode"
				for f in opencode.jsonc tui.json cli.json themes; do
					[ -e "$item/$f" ] || continue
					install_path "$item/$f" "$HOME/.config/opencode/$f"
				done
				log ".config/opencode (auth/service/node_modules kept)"
				;;
			QtProject.conf)
				log ".config/QtProject.conf skipped (app state)"
				;;
			*)
				install_path "$item" "$HOME/.config/$name"
				log ".config/$name"
				;;
		esac
	done
	shopt -u nullglob dotglob

	for f in "${RICE_HOME_FILES[@]}"; do
		[ -e "$RICE_DIR/$f" ] || continue
		install_path "$RICE_DIR/$f" "$HOME/$f"
		log "$f"
	done

	if [ -d "$RICE_DIR/.local/bin" ]; then
		for f in "$RICE_DIR"/.local/bin/*; do
			[ -e "$f" ] || continue
			install_path "$f" "$HOME/.local/bin/$(basename "$f")"
			if [ "$DRY_RUN" -eq 0 ] && [ ! -L "$HOME/.local/bin/$(basename "$f")" ]; then
				chmod +x "$HOME/.local/bin/$(basename "$f")" 2>/dev/null || true
			fi
			log ".local/bin/$(basename "$f")"
		done
	fi

	# Chromium theme (not auto-installed into profile)
	if [ -d "$RICE_DIR/.config/chromium-theme/void-dark" ]; then
		if [ "$DRY_RUN" -eq 1 ]; then
			log "[dry-run] would install chromium theme to ~/.local/share/chromium-themes/void-dark"
		else
			ensure_dir "$HOME/.local/share/chromium-themes"
			if [ "$MODE" = "link" ]; then
				rm -rf "$HOME/.local/share/chromium-themes/void-dark"
				ln -s "$RICE_DIR/.config/chromium-theme/void-dark" "$HOME/.local/share/chromium-themes/void-dark"
			else
				rm -rf "$HOME/.local/share/chromium-themes/void-dark"
				cp -a "$RICE_DIR/.config/chromium-theme/void-dark" "$HOME/.local/share/chromium-themes/void-dark"
			fi
			log "chromium theme -> ~/.local/share/chromium-themes/void-dark (load via chrome://extensions)"
		fi
	fi
}

###############################################################################
# extras
###############################################################################

install_fonts() {
	[ "$COMP_FONT" -eq 1 ] || return 0
	section "Font"
	local target="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
	if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -i 'JetBrainsMono Nerd Font' >/dev/null 2>&1; then
		ok "JetBrainsMono Nerd Font already installed"
		return 0
	fi
	if [ -d "$target" ] && [ -n "$(find "$target" -maxdepth 1 -name '*.ttf' -print -quit 2>/dev/null)" ]; then
		ok "JetBrainsMono Nerd Font files already present"
		return 0
	fi
	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would download JetBrainsMono Nerd Font to $target"
		return 0
	fi
	if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
		warn "curl/unzip not installed; install them or enable the cli package group"
		return 0
	fi

	local tmp url
	tmp=$(mktemp -d "${TMPDIR:-/tmp}/void-rice-font.XXXXXX")
	cleanup_paths+=("$tmp")
	url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.zip"
	if ! curl -fL --retry 3 -o "$tmp/font.zip" "$url" >/dev/null 2>&1; then
		warn "font download failed; install nerd-fonts-ttf manually if needed"
		return 0
	fi
	if ! unzip -q "$tmp/font.zip" -d "$tmp/font" >/dev/null 2>&1; then
		warn "font archive could not be extracted"
		return 0
	fi
	mkdir -p "$target"
	if cp -a "$tmp"/font/*.ttf "$target/" 2>/dev/null; then
		ok "$target"
	else
		warn "no .ttf files found in the font archive"
		return 0
	fi
	if command -v fc-cache >/dev/null 2>&1; then
		fc-cache -f >/dev/null 2>&1 || true
	fi
}

install_wallpapers() {
	[ "$COMP_WALLPAPER" -eq 1 ] || return 0
	section "Wallpapers"
	ensure_dir "$HOME/Pictures"
	local wp
	for wp in "$RICE_DIR"/wallpapers/*; do
		[ -e "$wp" ] || continue
		if [ "$DRY_RUN" -eq 1 ]; then
			log "[dry-run] copy $(basename "$wp") -> ~/Pictures/"
			continue
		fi
		if command -v cmp >/dev/null 2>&1 &&
			[ -e "$HOME/Pictures/$(basename "$wp")" ] &&
			cmp -s "$wp" "$HOME/Pictures/$(basename "$wp")"; then
			log "Pictures/$(basename "$wp") unchanged"
		else
			cp -a "$wp" "$HOME/Pictures/"
			log "Pictures/$(basename "$wp")"
		fi
	done
}

apply_gsettings() {
	[ "$COMP_GSETTINGS" -eq 1 ] || return 0
	section "GTK/Qt defaults"
	if ! command -v gsettings >/dev/null 2>&1; then
		warn "gsettings not found; skipped"
		return 0
	fi
	local script
	script=$(cat <<'GS'
gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 11' 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
GS
)
	if [ "$DRY_RUN" -eq 1 ]; then
		log "[dry-run] would apply GTK/Qt gsettings defaults"
		return 0
	fi
	if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
		bash -c "$script" || true
	elif command -v dbus-run-session >/dev/null 2>&1; then
		dbus-run-session -- bash -c "$script" || true
	else
		bash -c "$script" || true
	fi
	ok "gsettings applied (best effort)"
}

###############################################################################
# post-install
###############################################################################

post_install() {
	section "Done"
	if [ "$DRY_RUN" -eq 1 ]; then
		ok "dry run complete; nothing was changed"
		return 0
	fi

	mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Recordings" "$HOME/.local/bin"
	if [ "$COMP_CONFIGS" -eq 1 ] && command -v bat >/dev/null 2>&1; then
		if bat cache --build >/dev/null 2>&1; then
			ok "bat theme cache built"
		else
			warn "bat cache --build failed; run it manually"
		fi
	fi
	if command -v fc-cache >/dev/null 2>&1; then
		fc-cache -f >/dev/null 2>&1 || true
	fi

	if [ "$PACKAGE_FAILED" -eq 1 ]; then
		warn "some packages were not installed; rerun the installer or use the printed xbps command."
	fi
	if [ "$COMP_SYSTEM" -eq 1 ] && [ "$SYSTEM_CHANGED" -eq 1 ]; then
		warn "log out and back in for group/service changes to take effect."
	fi
	if [ "$SHELL_NAME" != zsh ]; then
		printf '\n  your login shell is %s; switch with:\n' "$SHELL_NAME"
		printf '    chsh -s /usr/bin/zsh\n'
	fi
	if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
		printf '\n  backup: %s\n' "$BACKUP_DIR"
		printf '  restore: %s --restore %q\n' "$SETUP_PATH" "$BACKUP_DIR"
	fi
	printf '\n  log out and back in, then start mango from tty1.\n'
	if [ -e "$HOME/.keybinds" ]; then
		printf '  keybinds: %s\n' "$HOME/.keybinds"
	fi
	printf '\n'
}

###############################################################################
# main
###############################################################################

main() {
	parse_args "$@"
	detect_environment
	init_colors

	printf '\n%svoid-musl-rice installer%s\n' "$C_HEAD" "$C_RESET"
	print_environment

	if [ -n "$RESTORE_DIR" ]; then
		restore_backup "$RESTORE_DIR"
		return 0
	fi

	if [ "$ASSUME_YES" -eq 0 ] && [ ! -t 0 ]; then
		die "interactive menus need a TTY; use --yes for non-interactive mode."
	fi
	if [ "$ASSUME_YES" -eq 0 ]; then
		ensure_fzf
	fi

	if [ "$ASSUME_YES" -eq 0 ]; then
		interactive_flow
	else
		# Non-interactive defaults: all components, all groups, all actions.
		print_summary
	fi

	make_backup
	install_packages
	install_system
	install_configs
	install_fonts
	install_wallpapers
	apply_gsettings
	post_install
}

main "$@"
