#!/bin/sh
# Inserts an emoji into the focused input. Usage: insert-emoji.sh <emoji>
#
# Terminals get it typed by wtype. Everything else gets a paste, because Chromium
# apps silently drop typed characters above U+FFFF, which covers most emoji.
# The paste borrows the clipboard and puts it back, both hidden from cliphist.
# It prints "sent" after pasting so the picker can take the keyboard back early.

# wtype can't decode emoji under the C locale.
export LC_ALL=C.UTF-8

# Give niri time to hand keyboard focus from the picker to the app.
sleep 0.1

case $(niri msg focused-window | sed -n 's/^ *App ID: "\(.*\)"$/\1/p') in
    foot | footclient | kitty | com.mitchellh.ghostty) exec wtype -- "$1" ;;
esac

saved=$(mktemp) || exit 1
trap 'rm -f "$saved"' EXIT

# Only one format can be restored, so prefer an image, then plain text.
types=$(wl-paste --list-types 2>/dev/null)
type=
for wanted in image/png 'text/plain;charset=utf-8' text/plain; do
    if printf '%s\n' "$types" | grep -qxF "$wanted"; then
        type=$wanted
        break
    fi
done
[ -n "$type" ] || type=$(printf '%s\n' "$types" | head -n 1)
if [ -n "$type" ]; then
    wl-paste --no-newline --type "$type" >"$saved" || type=
fi

printf %s "$1" | wl-copy --sensitive --type 'text/plain;charset=utf-8' >/dev/null || exit 1
wtype -M ctrl -k v -m ctrl
sleep 0.05
echo sent

# The app reads the clipboard after the keypress, so wait before restoring it.
sleep 0.5
if [ -n "$type" ]; then
    wl-copy --sensitive --type "$type" <"$saved" >/dev/null
else
    wl-copy --clear
fi
