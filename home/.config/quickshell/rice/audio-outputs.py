#!/usr/bin/env python3
"""List PipeWire playback outputs and mark the current default."""

import json
import re
import subprocess


try:
    status = subprocess.run(
        ["wpctl", "status"], capture_output=True, check=True, text=True
    ).stdout
    sinks = status.split("├─ Sinks:", 1)[1].split("├─ Sources:", 1)[0]
    outputs = []
    for line in sinks.splitlines():
        match = re.search(r"(\*)?\s*(\d+)\.\s+(.+?)\s+\[vol:", line)
        if match:
            outputs.append({
                "id": int(match.group(2)),
                "name": match.group(3).strip(),
                "active": bool(match.group(1)),
            })
    print(json.dumps(outputs))
except (OSError, subprocess.CalledProcessError, IndexError):
    print("[]")
