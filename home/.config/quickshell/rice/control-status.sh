#!/bin/sh
# Report the backlight, appearance preference and Niri's OpenScreen capture.
backlight=$(brightnessctl -c backlight -m 2>/dev/null | cut -d, -f4 | tr -d '%')
scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
animations=$(gsettings get org.gnome.desktop.interface enable-animations 2>/dev/null)
recording=0
if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    pid=$(cat "$XDG_RUNTIME_DIR/openscreen-record.pid" 2>/dev/null)
    case "$pid" in
        ''|*[!0-9]*) ;;
        *)
            if kill -0 "$pid" 2>/dev/null &&
                grep -q 'Recording started' "$XDG_RUNTIME_DIR/openscreen-record.log" 2>/dev/null &&
                ! grep -q '"event":"done"' "$XDG_RUNTIME_DIR/openscreen-record.log" 2>/dev/null; then
                recording=1
            fi
            ;;
    esac
fi
printf '%s|%s|%s|%s\n' "$backlight" "$scheme" "$recording" "${animations:-true}"
