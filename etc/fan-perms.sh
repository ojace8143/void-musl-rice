#!/bin/sh
# Give the video group write access to the ASUS custom fan curve attributes.
# Run as root once per boot if the udev rule could not be applied (for example
# when the rule was installed after the hwmon device already appeared).
for d in /sys/class/hwmon/hwmon*; do
	[ -r "$d/name" ] || continue
	[ "$(cat "$d/name" 2>/dev/null)" = "asus_custom_fan_curve" ] || continue
	# -L matters: /sys/class/hwmon/hwmonN is a symlink, and find does not
	# descend into a symlink given as its starting point by default.
	find -L "$d" -maxdepth 1 -name 'pwm*' \
		-exec chgrp video {} + \
		-exec chmod g+w {} + 2>/dev/null
	if [ -w "$d/pwm1_enable" ]; then
		printf 'fan control write access: %s\n' "$(basename "$d")"
	else
		printf 'failed to grant fan control write access: %s\n' "$(basename "$d")" >&2
	fi
done
