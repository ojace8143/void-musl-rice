#!/usr/bin/env bash
# void-musl-rice — bootstrap for a Void Linux (musl) + mangoWM desktop.
#   1. symlinks tracked configs into $HOME
#   2. (optional) installs packages
#   3. sets git identity + dual-push remotes (GitHub + local Forgejo)
#
# Usage:  ./setup.sh [--packages] [--remotes] [--links]
# Runs all steps by default.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- GitHub / Forgejo settings (edit these) --------------------------------
GITHUB_USER="${GITHUB_USER:-ojace8143}"
GITHUB_REPO="${GITHUB_REPO:-void-musl-rice}"
FORGEJO_HOST="${FORGEJO_HOST:-jcnuc}"       # ssh host or ssh-config alias (port 2222)
FORGEJO_USER="${FORGEJO_USER:-ojace8143}"
FORGEJO_REPO="${FORGEJO_REPO:-void-musl-rice}"
GIT_NAME="${GIT_NAME:-ojace8143}"
GIT_EMAIL="${GIT_EMAIL:-ojace8143@gmail.com}"
# ---------------------------------------------------------------------------

FILES=(.zshrc .zprofile .colors)
CONFIG_DIRS=(btop dunst foot fuzzel mango nvim opencode waybar)

PACKAGES=(
  eza zoxide git github-cli
  foot fuzzel dunst waybar
  grim slurp wl-clipboard jq
  pipewire wireplumber pulseaudio-utils
  brightnessctl swaylock swayidle
  polkit xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
  noto-fonts-emoji noto-fonts-ttf
  gammastep cliphist wlogout
)

do_links=true do_packages=false do_remotes=true
for arg in "$@"; do
  case "$arg" in
    --links)    do_links=true ;;
    --packages) do_packages=true ;;
    --remotes)  do_remotes=true ;;
    --no-remotes) do_remotes=false ;;
  esac
done

link() { # link <target-in-repo> <path>
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(date +%s)"
  fi
  ln -sfn "$src" "$dst"
  echo "  linked $dst -> $src"
}

if $do_links; then
  echo "==> linking configs"
  for f in "${FILES[@]}"; do [ -e "$REPO/$f" ] && link "$REPO/$f" "$HOME/$f"; done
  for d in "${CONFIG_DIRS[@]}"; do [ -e "$REPO/.config/$d" ] && link "$REPO/.config/$d" "$HOME/.config/$d"; done
fi

if $do_packages; then
  echo "==> installing packages (sudo)"
  sudo xbps-install -Sy "${PACKAGES[@]}"
fi

if $do_remotes && git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "==> git identity"
  [ -n "$GIT_NAME" ]  && git -C "$REPO" config --global user.name  "$GIT_NAME"
  [ -n "$GIT_EMAIL" ] && git -C "$REPO" config --global user.email "$GIT_EMAIL"

  echo "==> dual-push remotes"
  gh_url="git@github.com:${GITHUB_USER}/${GITHUB_REPO}.git"
  fj_url="git@${FORGEJO_HOST}:${FORGEJO_USER}/${FORGEJO_REPO}.git"
  git -C "$REPO" remote remove origin 2>/dev/null || true
  git -C "$REPO" remote add origin "$gh_url"
  git -C "$REPO" remote set-url --add --push origin "$gh_url"   # push -> GitHub
  git -C "$REPO" remote set-url --add --push origin "$fj_url"   # push -> Forgejo
  git -C "$REPO" remote -v
fi

echo "==> done"
