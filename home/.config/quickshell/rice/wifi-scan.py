#!/usr/bin/env python3
"""Return nearby Wi-Fi networks for the Quickshell menu.

Reads NetworkManager's cached scan results so it returns instantly, then kicks off
a background rescan so the next call is fresh. Output is deduplicated by SSID and
sorted with the connected network first, then by signal strength.
"""

import json
import subprocess

result = subprocess.run(
    ["nmcli", "-t", "--escape", "no", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"],
    capture_output=True,
    text=True,
)
best = {}
for line in result.stdout.splitlines():
    fields = line.split(":", 3)
    if len(fields) != 4 or not fields[1]:
        continue
    active, name, signal, security = fields
    entry = {"name": name, "signal": signal, "security": security, "active": active == "*"}
    known = best.get(name)
    if known is None or entry["active"] or (not known["active"] and int(signal) > int(known["signal"])):
        best[name] = entry

networks = sorted(best.values(), key=lambda n: (not n["active"], -int(n["signal"])))
print(json.dumps(networks))

subprocess.Popen(
    ["nmcli", "device", "wifi", "rescan"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    start_new_session=True,
)
