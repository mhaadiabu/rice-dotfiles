#!/usr/bin/env python3
"""List selectable backgrounds with correctly escaped file URLs."""

import json
from pathlib import Path

pictures = Path.home() / "Pictures"
extensions = {".avif", ".bmp", ".jpeg", ".jpg", ".png", ".webp"}
files = {
    path
    for folder in (pictures / "Wallpapers", pictures / "Saved")
    for path in folder.rglob("*")
    if path.is_file() and path.suffix.lower() in extensions
}
print(json.dumps([
    {"name": path.stem, "location": str(path), "url": path.as_uri()}
    for path in sorted(files, key=lambda path: (path.parent != pictures / "Wallpapers", path.name.casefold()))
]))
