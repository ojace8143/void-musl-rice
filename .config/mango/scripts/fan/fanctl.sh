#!/bin/sh
# fanctl - fan speed control for the ASUS TUF A15 (FA507XV)
#
# Usage: fanctl up|down|auto|status|json|calibrate
#
# This laptop/kernel (asus-wmi, 6.18) exposes no writable per-fan PWM.  The
# driver only supports the ASUS custom fan curve, so manual mode writes a flat
# curve (all 8 points the same) for both fans.  Auto mode hands the fans back
# to the firmware.
set -eu

STEP=${FAN_STEP:-10}
CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/fanctl
CAL_FILE=$CACHE_DIR/calibration
FALLBACK_MAX=6000
# Sanity range for the real fan tach.  This laptop reads ~0 RPM at idle and
# ~2.4k RPM under load; anything outside this range is a bad sample.
FAN_MAX_PLAUSIBLE=${FAN_MAX_PLAUSIBLE:-12000}

notify() {
    title=$1
    body=$2
    urgency=${3:-low}
    if command -v dunstify >/dev/null 2>&1; then
        dunstify -a fan -u "$urgency" -t 2000 -r 9901 "$title" "$body" >/dev/null 2>&1 || true
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send -a fan -u "$urgency" -t 2000 "$title" "$body" >/dev/null 2>&1 || true
    fi
}

die_notify() {
    notify "Fan control" "$1" normal
    printf '%s\n' "$1" >&2
    exit 1
}

find_hwmon() {
    for d in /sys/class/hwmon/hwmon*; do
        [ -r "$d/name" ] || continue
        [ "$(cat "$d/name" 2>/dev/null)" = "$1" ] && { printf '%s\n' "$d"; return 0; }
    done
    return 1
}

CURVE=$(find_hwmon asus_custom_fan_curve) || die_notify "ASUS fan curve hwmon not found"

find_fan_sensor() {
    for d in /sys/class/hwmon/hwmon*; do
        [ -r "$d/fan1_input" ] && { printf '%s\n' "$d"; return 0; }
    done
    return 1
}
SENSOR=$(find_fan_sensor) || SENSOR=$CURVE

FANS=
for i in 1 2 3; do
    [ -e "$CURVE/pwm${i}_enable" ] && FANS="$FANS $i"
done
[ -n "$FANS" ] || die_notify "No controllable fan channels found"

have_fan() {
    [ -e "$CURVE/pwm${1}_enable" ]
}

require_write() {
    for f in "$CURVE/pwm1_enable" "$CURVE/pwm1_auto_point1_pwm"; do
        [ -w "$f" ] && continue
        if command -v pkexec >/dev/null 2>&1; then
            pkexec sh -c "chgrp video '$f' 2>/dev/null; chmod g+w '$f' 2>/dev/null" >/dev/null 2>&1 && [ -w "$f" ] && continue
        fi
        if command -v sudo >/dev/null 2>&1; then
            sudo -n sh -c "chgrp video '$f' 2>/dev/null; chmod g+w '$f' 2>/dev/null" >/dev/null 2>&1 && [ -w "$f" ] && continue
        fi
        die_notify "No write access to $f. Install etc/udev/rules.d/90-fan.rules and re-run setup.sh (or apply the video-group permissions)."
    done
}

fan_enabled() { # 1 = manual curve active, 2 = firmware auto
    cat "$CURVE/pwm${1}_enable" 2>/dev/null || printf '2'
}

fan_rpm() {
    cat "$SENSOR/fan${1}_input" 2>/dev/null || printf '0'
}

cal_max() {
    max=$FALLBACK_MAX
    if [ -r "$CAL_FILE" ]; then
        while read -r idx val; do
            [ "$idx" = "$1" ] && [ -n "$val" ] && max=$val
        done < "$CAL_FILE"
    fi
    case "$max" in
        ''|*[!0-9]*) max=$FALLBACK_MAX ;;
    esac
    if [ "$max" -lt 500 ] || [ "$max" -gt "$FAN_MAX_PLAUSIBLE" ]; then
        max=$FALLBACK_MAX
    fi
    printf '%s\n' "$max"
}

rpm_pct() {
    rpm=$(fan_rpm "$1")
    cal_raise "$1" "$rpm"
    max=$(cal_max "$1")
    pct=$(( (rpm * 100 + max / 2) / max ))
    [ "$pct" -gt 100 ] && pct=100
    [ "$pct" -lt 0 ] && pct=0
    printf '%s\n' "$pct"
}

# The EC ramps slowly, so the true maximum is learned over time instead of
# only during the one-time calibration run.
cal_raise() {
    fan=$1
    rpm=$2
    [ -r "$CAL_FILE" ] || return 0
    [ "$rpm" -ge 500 ] && [ "$rpm" -le "$FAN_MAX_PLAUSIBLE" ] || return 0
    cur=$(cal_max "$fan")
    [ "$rpm" -gt "$cur" ] || return 0
    m1=$(cal_max 1)
    m2=$(cal_max 2)
    if [ "$fan" = 1 ]; then
        m1=$rpm
    else
        m2=$rpm
    fi
    mkdir -p "$CACHE_DIR"
    printf '1 %s\n2 %s\n' "$m1" "$m2" > "$CAL_FILE" 2>/dev/null || true
}

curve_pct() {
    val=$(cat "$CURVE/pwm${1}_auto_point1_pwm" 2>/dev/null || printf '0')
    pct=$(( (val * 100 + 127) / 255 ))
    [ "$pct" -gt 100 ] && pct=100
    printf '%s\n' "$pct"
}

fan_pct() {
    if [ "$(fan_enabled "$1")" = 1 ]; then
        curve_pct "$1"
    else
        rpm_pct "$1"
    fi
}

apply_target() {
    target=$1
    [ "$target" -lt 0 ] && target=0
    [ "$target" -gt 100 ] && target=100
    val=$(( (target * 255 + 50) / 100 ))

    for i in $FANS; do
        for p in 1 2 3 4 5 6 7 8; do
            printf '%s\n' "$val" > "$CURVE/pwm${i}_auto_point${p}_pwm" ||
                die_notify "Failed to write fan ${i} curve point ${p}"
        done
        printf '1\n' > "$CURVE/pwm${i}_enable" ||
            die_notify "Failed to enable manual mode for fan ${i}"
    done
}

current_avg_pct() {
    total=0
    count=0
    for i in $FANS; do
        p=$(fan_pct "$i")
        total=$((total + p))
        count=$((count + 1))
    done
    printf '%s\n' $(( (total + count / 2) / count ))
}

all_manual() {
    for i in $FANS; do
        [ "$(fan_enabled "$i")" = 1 ] || return 1
    done
    return 0
}

cmd_up() {
    require_write
    base=$(current_avg_pct)
    if all_manual; then
        target=$((base + STEP))
    elif [ "$base" -lt 50 ]; then
        # coming from auto with quiet fans: take manual control at a
        # speed you can actually hear/feel, then step from there
        target=50
    else
        target=$((base + STEP))
    fi
    [ "$target" -gt 100 ] && target=100
    apply_target "$target"
    notify "Fan speed" "Both fans: ${target}% (manual)"
}

cmd_down() {
    require_write
    base=$(current_avg_pct)
    target=$((base - STEP))
    [ "$target" -lt 0 ] && target=0
    apply_target "$target"
    notify "Fan speed" "Both fans: ${target}% (manual)"
}

cmd_auto() {
    require_write
    for i in $FANS; do
        printf '2\n' > "$CURVE/pwm${i}_enable" ||
            die_notify "Failed to return fan ${i} to automatic"
    done
    notify "Fan speed" "Fans: automatic"
}

cmd_calibrate() {
    require_write

    prev_manual=0
    for i in $FANS; do
        [ "$(fan_enabled "$i")" = 1 ] && prev_manual=1
    done
    prev_target=$(current_avg_pct)

    apply_target 100
    notify "Fan calibration" "Spinning both fans up for up to 30 seconds..." normal

    # The EC ramps slowly; sample until it plateaus so we capture the real max.
    sleep 3
    max1=0
    max2=0
    stable=0
    prev1=0
    prev2=0
    i=0
    while [ "$i" -lt 30 ]; do
        r1=$(fan_rpm 1)
        r2=$(fan_rpm 2)
        [ "$r1" -ge 500 ] && [ "$r1" -le "$FAN_MAX_PLAUSIBLE" ] && [ "$r1" -gt "$max1" ] && max1=$r1
        [ "$r2" -ge 500 ] && [ "$r2" -le "$FAN_MAX_PLAUSIBLE" ] && [ "$r2" -gt "$max2" ] && max2=$r2
        if [ "$r1" -le "$prev1" ] && [ "$r2" -le "$prev2" ] && [ "$i" -gt 10 ]; then
            stable=$((stable + 1))
            [ "$stable" -ge 5 ] && break
        else
            stable=0
        fi
        prev1=$r1
        prev2=$r2
        sleep 1
        i=$((i + 1))
    done
    [ "$max1" -gt 0 ] || max1=$FALLBACK_MAX
    [ "$max2" -gt 0 ] || max2=$FALLBACK_MAX

    mkdir -p "$CACHE_DIR"
    printf '1 %s\n2 %s\n' "$max1" "$max2" > "$CAL_FILE"

    if [ "$prev_manual" = 1 ]; then
        apply_target "$prev_target"
    else
        for i in $FANS; do
            printf '2\n' > "$CURVE/pwm${i}_enable" || true
        done
    fi

    notify "Fan calibration" "Max RPM: CPU ${max1}, GPU ${max2}"
}

cmd_status() {
    for i in $FANS; do
        if [ "$(fan_enabled "$i")" = 1 ]; then
            printf 'fan%s: manual %s%% (%s RPM)\n' "$i" "$(fan_pct "$i")" "$(fan_rpm "$i")"
        else
            printf 'fan%s: auto %s%% (%s RPM)\n' "$i" "$(fan_pct "$i")" "$(fan_rpm "$i")"
        fi
    done
}

cmd_json() {
    manual=1
    for i in $FANS; do
        [ "$(fan_enabled "$i")" = 1 ] || manual=0
    done

    p1=$(fan_pct 1)
    if have_fan 2; then
        p2=$(fan_pct 2)
    else
        p2=$p1
    fi

    if [ "$manual" = 1 ]; then
        r1=$(fan_rpm 1)
        if have_fan 2; then
            r2=$(fan_rpm 2)
        else
            r2=$r1
        fi
        text="󰈐 ${p1}%/${p2}%"
        tooltip="Manual fan curve\\nCPU fan (left): ${p1}% (${r1} RPM)\\nGPU fan (right): ${p2}% (${r2} RPM)"
        class=manual
    else
        r1=$(fan_rpm 1)
        if have_fan 2; then
            r2=$(fan_rpm 2)
        else
            r2=$r1
        fi
        text="󰈐 ${p1}%/${p2}%"
        tooltip="Automatic (firmware)\\nCPU fan (left): ${r1} RPM (${p1}%)\\nGPU fan (right): ${r2} RPM (${p2}%)"
        class=auto
    fi

    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
}

case "${1:-}" in
    up)        cmd_up ;;
    down)      cmd_down ;;
    auto)      cmd_auto ;;
    status)    cmd_status ;;
    json)      cmd_json ;;
    calibrate) cmd_calibrate ;;
    *)
        printf 'usage: %s up|down|auto|status|json|calibrate\n' "$0" >&2
        exit 2
        ;;
esac
