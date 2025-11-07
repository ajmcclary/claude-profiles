#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK_RE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)|\[[^\]]+\]\(([^)]+)\)")
SCHEMES = ("http://", "https://", "mailto:")

missing: list[str] = []

for md_file in ROOT.rglob("*.md"):
    text = md_file.read_text(encoding="utf-8")
    for match in LINK_RE.finditer(text):
        target = match.group(1) or match.group(2) or ""
        target = target.strip()
        if not target or target.startswith("#"):
            continue
        if any(target.lower().startswith(s) for s in SCHEMES):
            continue
        if target.startswith("data:") or target.startswith("//"):
            continue
        clean = target.split("#", 1)[0].split("?", 1)[0]
        if not clean:
            continue
        candidate = (md_file.parent / clean).resolve()
        try:
            candidate.relative_to(ROOT)
        except ValueError:
            # Allow links pointing outside the repo (e.g., ../other)
            continue
        if not candidate.exists():
            rel_md = md_file.relative_to(ROOT)
            missing.append(f"{rel_md}: missing asset '{clean}'")

if missing:
    print("Missing documentation assets detected:")
    for line in missing:
        print(f" - {line}")
    sys.exit(1)

print("All referenced documentation assets exist.")
