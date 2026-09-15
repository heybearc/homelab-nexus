#!/usr/bin/env python3
import re
import sys

path = "/mnt/old151/var/lib/postgresql/17/main/postgresql.auto.conf"
text = open(path).read()
m = re.search(r"password=''([^']+)''", text)
if not m:
    m = re.search(r"password='([^']+)'", text)
if not m:
    m = re.search(r'password="([^"]+)"', text)
if not m:
    sys.stderr.write("no password in auto.conf\n")
    sys.exit(1)
open("/root/repl.pass", "w").write(m.group(1))
print("bytes", len(m.group(1)))
