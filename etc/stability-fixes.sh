#!/bin/sh
# stability-fixes.sh - make hard freezes diagnosable and cut the two most
# likely causes on this ASUS TUF A15 (FA507XV):
#
#   1. MediaTek MT7922 (mt7921e): PCIe ASPM + 802.11 power save
#   2. amdgpu PSR on the Radeon 780M eDP panel
#
# Also restores persistent kernel logging (the /var/service/socklog-unix
# symlink was dangling because socklog-void was never installed) and keeps the
# previous boot's dmesg.
#
# Usage:  sudo sh etc/stability-fixes.sh
#
# Reboot is required for mt7921e disable_aspm and amdgpu.dcdebugmask.
# Every replaced file is backed up as <file>.rice-bak-<timestamp>.
set -eu

RICE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
backup() {
	if [ -e "$1" ]; then
		cp -a "$1" "$1.rice-bak-$STAMP"
		printf '    backup: %s.rice-bak-%s\n' "$1" "$STAMP"
	fi
}
enable_svc() {
	svc=$1
	if [ ! -e "/var/service/$svc" ] && [ ! -L "/var/service/$svc" ]; then
		ln -s "/etc/sv/$svc" "/var/service/$svc"
	fi
	n=0
	until sv up "$svc" 2>/dev/null; do
		n=$((n + 1))
		if [ "$n" -ge 6 ]; then
			warn "could not start $svc"
			return 1
		fi
		sleep 1
	done
	sv status "$svc" || true
}

[ "$(id -u)" -eq 0 ] || { echo "error: run as root (sudo sh $0)" >&2; exit 1; }
[ -d "$RICE_DIR/etc" ] || { echo "error: cannot find etc/ next to this script" >&2; exit 1; }

# ---- 1. persistent kernel logging (socklog-void) ----------------------------
# The stock 'socklog' package only ships the binaries; 'socklog-void' is what
# provides /etc/sv/socklog-unix, the socklog group and /var/log/socklog.
say "installing socklog-void for persistent kernel logs"
if xbps-query -l 2>/dev/null | grep -q '^ii socklog-void'; then
	echo "    already installed"
else
	xbps-install -Sy socklog-void || warn "socklog-void install failed (no network?); kernel log will not persist"
fi
if [ -x /etc/sv/socklog-unix/run ]; then
	enable_svc socklog-unix || true
	enable_svc nanoklogd || true
else
	warn "/etc/sv/socklog-unix is still missing; kernel log will not persist"
fi

# ---- 2. keep the previous boot's early kernel log ---------------------------
say "keeping the previous boot's dmesg (dmesg.log.1)"
backup /etc/runit/core-services/97-dmesg.sh
install -m644 "$RICE_DIR/etc/runit/97-dmesg.sh" /etc/runit/core-services/97-dmesg.sh

# ---- 3. lockup/hang diagnostics --------------------------------------------
say "enabling all-CPU backtraces on lockups and hung tasks"
backup /etc/sysctl.d/90-lockup.conf
install -m644 "$RICE_DIR/etc/sysctl.d/90-lockup.conf" /etc/sysctl.d/90-lockup.conf
sysctl -p /etc/sysctl.d/90-lockup.conf || warn "sysctl -p reported an error"

# ---- 4. MediaTek MT7922: regulatory db, ASPM, power save -------------------
say "installing wireless-regdb (fixes 'failed to load regulatory.db')"
if xbps-query -l 2>/dev/null | grep -q '^ii wireless-regdb'; then
	echo "    already installed"
else
	xbps-install -Sy wireless-regdb || warn "wireless-regdb install failed (network?)"
fi

say "disabling mt7921e PCIe ASPM (takes effect on reboot)"
backup /etc/modprobe.d/mt7921.conf
install -m644 "$RICE_DIR/etc/modprobe.d/mt7921.conf" /etc/modprobe.d/mt7921.conf

say "installing wifi-powersave runit service"
install -d -m755 /etc/sv/wifi-powersave
install -m755 "$RICE_DIR/etc/sv/wifi-powersave/run" /etc/sv/wifi-powersave/run
enable_svc wifi-powersave || true

# ---- 5. amdgpu PSR off (next boot) -----------------------------------------
say "disabling amdgpu PSR via kernel command line (next boot)"
backup /etc/default/grub
if grep -q 'amdgpu.dcdebugmask' /etc/default/grub; then
	echo "    already present in /etc/default/grub"
else
	sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$|GRUB_CMDLINE_LINUX_DEFAULT="\1 amdgpu.dcdebugmask=0x10"|' /etc/default/grub
fi
if ! grep -q 'amdgpu.dcdebugmask=0x10' /etc/default/grub; then
	warn "could not edit GRUB_CMDLINE_LINUX_DEFAULT; PSR left enabled"
else
	backup /boot/grub/grub.cfg
	tmp=$(mktemp /tmp/grub.cfg.XXXXXX)
	if grub-mkconfig -o "$tmp" >/dev/null 2>&1 && [ -s "$tmp" ] && grep -q 'amdgpu.dcdebugmask=0x10' "$tmp"; then
		install -m644 "$tmp" /boot/grub/grub.cfg
		echo "    /boot/grub/grub.cfg regenerated"
	else
		warn "grub-mkconfig failed or produced no PSR entry; grub.cfg left unchanged"
	fi
	rm -f "$tmp"
fi

# ---- summary ---------------------------------------------------------------
cat <<EOF

Done. Reboot to activate:
  - mt7921e disable_aspm=1
  - amdgpu.dcdebugmask=0x10 (PSR off)
  - dmesg.log rotation and lockup backtraces

Verify after the reboot:
  grep -o 'amdgpu.dcdebugmask=0x10' /proc/cmdline
  cat /sys/module/mt7921e/parameters/disable_aspm      # N -> should become Y
  iw dev wlp4s0 get power_save                         # should be off
  ls -l /var/log/dmesg.log.1 /var/log/socklog/kernel/current
  sv status socklog-unix nanoklogd wifi-powersave

Rollback (files backed up with .rice-bak-$STAMP):
  /etc/default/grub, /boot/grub/grub.cfg,
  /etc/runit/core-services/97-dmesg.sh, /etc/sysctl.d/90-lockup.conf
  remove /etc/modprobe.d/mt7921.conf and /etc/sv/wifi-powersave to undo those
EOF
