# .zprofile — login shell setup (zsh equivalent of the old .bash_profile)
# Keeps the Wayland runtime dir + mango auto-start-on-tty1 behaviour.

# Ensure child processes (mango, foot, …) see the login shell as zsh
export SHELL=/usr/bin/zsh

# Set runtime dir for Wayland
if [ -z "$XDG_RUNTIME_DIR" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null
fi

# Auto-start MangoWM on TTY1 if no display manager
if [ "$(tty 2>/dev/null)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ -z "$SSH_TTY" ]; then
    exec dbus-run-session -- mango
fi
