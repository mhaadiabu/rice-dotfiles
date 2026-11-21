#!/usr/bin/env python3
"""Stream CPU and Memory usage for Quickshell top bar."""

import json
import time


def read_cpu():
    with open("/proc/stat") as f:
        fields = [float(x) for x in f.readline().split()[1:8]]
    idle = fields[3] + fields[4]
    total = sum(fields)
    return idle, total


def read_mem():
    mem = {}
    with open("/proc/meminfo") as f:
        for line in f:
            parts = line.split(":")
            if len(parts) == 2:
                mem[parts[0].strip()] = int(parts[1].split()[0])
    total = mem.get("MemTotal", 1)
    avail = mem.get("MemAvailable", 0)
    return round(((total - avail) / total) * 100)


def main():
    prev_idle, prev_total = read_cpu()
    time.sleep(0.1)
    while True:
        curr_idle, curr_total = read_cpu()
        delta_total = curr_total - prev_total
        delta_idle = curr_idle - prev_idle
        cpu_pct = round((1.0 - (delta_idle / delta_total)) * 100) if delta_total > 0 else 0
        cpu_pct = max(0, min(100, cpu_pct))
        prev_idle, prev_total = curr_idle, curr_total

        mem_pct = read_mem()

        print(json.dumps({
            "cpu": cpu_pct,
            "mem": mem_pct
        }), flush=True)
        time.sleep(2.0)


if __name__ == "__main__":
    main()
