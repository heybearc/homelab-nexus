#!/usr/bin/env python3
"""Align replica postgresql.conf with primary hot-standby requirements."""
from pathlib import Path

conf = Path("/etc/postgresql/17/main/postgresql.conf")
text = conf.read_text()
settings = {
    "listen_addresses": "'*'",
    "max_connections": "200",
    "max_wal_senders": "10",
    "max_worker_processes": "8",
    "wal_level": "replica",
    "hot_standby": "on",
    "hot_standby_feedback": "on",
}


def upsert(src, key, value):
    prefix = "%s =" % key
    lines = src.splitlines()
    out = []
    found = False
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith(prefix) or stripped.startswith("#" + prefix) or stripped.startswith("# " + prefix):
            out.append("%s = %s" % (key, value))
            found = True
        else:
            out.append(line)
    if not found:
        out.append("%s = %s" % (key, value))
    return "\n".join(out) + "\n"


for key, value in settings.items():
    text = upsert(text, key, value)
conf.write_text(text)
print("updated", conf)
