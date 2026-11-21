#!/usr/bin/env python3
"""Find local files and folders by name in the usual home folders."""

import json
import os
import sys
from pathlib import Path
from time import monotonic


def search(query):
    home = Path.home()
    folders = ("Desktop", "Documents", "Downloads", "Music", "Pictures", "Projects", "projects", "Videos")
    skip = {"node_modules", "build", "target", "__pycache__"}
    words = query.casefold().split()
    results = []
    deadline = monotonic() + 0.8

    for folder in folders:
        for directory, subdirs, files in os.walk(home / folder):
            if monotonic() >= deadline:
                return results

            subdirs[:] = [name for name in subdirs if not name.startswith(".") and name not in skip]
            for name in (*subdirs, *files):
                lower = name.casefold()
                if name.startswith(".") or not all(word in lower for word in words):
                    continue
                path = Path(directory) / name
                results.append({
                    "name": name,
                    "location": "~/" + str(path.parent.relative_to(home)),
                    "url": path.as_uri(),
                    "folder": name in subdirs,
                })
                if len(results) >= 64:
                    return results

    return results


query = sys.argv[1].strip()
matches = search(query) if len(query) >= 3 else []
matches.sort(key=lambda item: (not item["name"].casefold().startswith(query.casefold()), item["name"].casefold()))
print(json.dumps({"query": query, "matches": matches[:8]}))
