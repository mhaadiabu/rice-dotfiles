#!/bin/sh
set -eu
device=$1
profile='Rice Hotspot'

active_hotspot() {
    uuid=$(nmcli -g GENERAL.CON-UUID device show "$device")
    [ -n "$uuid" ]
    [ "$(nmcli -g 802-11-wireless.mode connection show uuid "$uuid")" = ap ]
    printf '%s\n' "$uuid"
}

case "$2" in
    on)
        if nmcli connection show id "$profile" >/dev/null 2>&1; then
            nmcli -w 20 connection up id "$profile" ifname "$device"
        else
            nmcli -w 20 device wifi hotspot ifname "$device" con-name "$profile" ssid "$(hostname -s) Hotspot"
        fi
        ;;
    off)
        uuid=$(active_hotspot)
        nmcli -w 10 connection down uuid "$uuid"
        ;;
    copy)
        uuid=$(active_hotspot)
        password=$(nmcli --show-secrets -g 802-11-wireless-security.psk connection show uuid "$uuid")
        [ -n "$password" ]
        printf '%s' "$password" | wl-copy --trim-newline >/dev/null 2>&1
        ;;
esac
