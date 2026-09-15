#!/usr/bin/env python3
"""Replace 10.92.3.21 with Postgres VIP 10.92.3.23 in app env files on a host."""
import os
import sys

OLD = "10.92.3.21"
NEW = "10.92.3.23"
ROOTS = ("/opt", "/home", "/etc", "/var/www", "/root")
NAMES = {
    ".env",
    ".env.local",
    ".env.production",
    ".env.production.local",
    "docker-compose.yml",
    "docker-compose.yaml",
    "compose.yml",
    "ecosystem.config.js",
    "ecosystem.config.cjs",
}
changed = []

for root in ROOTS:
    if not os.path.isdir(root):
        continue
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d
            for d in dirnames
            if d not in {".git", "node_modules", ".cache", "proc"}
        ]
        for name in filenames:
            if name not in NAMES and not name.endswith(".env"):
                continue
            path = os.path.join(dirpath, name)
            try:
                if os.path.getsize(path) > 2_000_000:
                    continue
                text = open(path, "r", errors="ignore").read()
            except OSError:
                continue
            if OLD not in text:
                continue
            open(path, "w").write(text.replace(OLD, NEW))
            changed.append(path)

print("changed", len(changed))
for p in changed:
    print(p)
