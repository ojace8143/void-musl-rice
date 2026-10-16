# .zprofile — login shell setup (zsh equivalent of the old .bash_profile)
# Keeps the Wayland runtime dir + mango auto-start-on-tty1 behaviour.

# Ensure child processes (mango, foot, …) see the login shell as zsh
export SHELL=/usr/bin/zsh

# Wayland screen capture for Chromium/Discord (reads via xdg-desktop-portal)
export CHROME_FLAGS="--enable-features=WebRTCPipeWireCapturer"

# Toolkit theming: cursor + GTK/Qt
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_QPA_PLATFORM="wayland;xcb"
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND="wayland,x11"
export MOZ_ENABLE_WAYLAND=1

# Set runtime dir for Wayland
if [ -z "$XDG_RUNTIME_DIR" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
fi

# Auto-start MangoWM on TTY1 if no display manager
if [ "$(tty 2>/dev/null)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    # No logind here, so exec-once daemons survive logout → kill leftovers first
    pkill -u "$USER" -x wireplumber 2>/dev/null
    pkill -u "$USER" -x pipewire-pulse 2>/dev/null
    pkill -u "$USER" -x pipewire 2>/dev/null
    rm -f "$XDG_RUNTIME_DIR"/pipewire-0 "$XDG_RUNTIME_DIR"/pipewire-0-manager \
          "$XDG_RUNTIME_DIR"/pipewire-0.lock "$XDG_RUNTIME_DIR"/pipewire-0-manager.lock 2>/dev/null
    exec dbus-run-session -- mango
fi
