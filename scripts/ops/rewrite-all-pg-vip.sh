#!/bin/bash
# Run on ansible-control. Rewrite 10.92.3.21 -> 10.92.3.23 on app LXCs.
set -u
IPS=$(python3 - <<'PY'
import subprocess
skip = {
    "10.92.3.21", "10.92.3.31", "10.92.3.23", "10.92.3.26", "10.92.3.32",
    "10.92.3.2", "10.92.3.10", "10.92.3.11", "10.92.3.90",
}
ips = []
for host in ("root@10.92.0.6", "root@10.92.0.7"):
    r = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", host, "grep -h ip= /etc/pve/lxc/*.conf"],
        capture_output=True, text=True,
    )
    for line in r.stdout.splitlines():
        for part in line.split(","):
            if part.startswith("ip=") and "/24" in part:
                ip = part.split("=")[1].split("/")[0]
                if ip.startswith("10.92.3.") and ip not in skip:
                    ips.append(ip)
print("\n".join(sorted(set(ips))))
PY
)
echo "SCAN $(echo "$IPS" | grep -c .)"
remote='
python3 - <<'"'"'PY'"'"'
import os
old, new = "10.92.3.21", "10.92.3.23"
ext_ok = (".env", ".yml", ".yaml", ".js", ".cjs", ".json")
changed = []
for root in ("/opt", "/home", "/root", "/etc"):
    if not os.path.isdir(root):
        continue
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in {".git","node_modules",".cache"}]
        for fn in fns:
            path = os.path.join(dp, fn)
            low = fn.lower()
            if not (low.startswith(".env") or low.endswith(ext_ok) or "compose" in low or "ecosystem" in low):
                continue
            try:
                if os.path.getsize(path) > 2_000_000:
                    continue
                text = open(path, "r", errors="ignore").read()
            except OSError:
                continue
            if old not in text:
                continue
            open(path, "w").write(text.replace(old, new))
            changed.append(path)
print("changed", len(changed))
for p in changed:
    print(p)
PY
'
echo "$IPS" | while read -r ip; do
  [ -z "$ip" ] && continue
  if ! ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new "root@$ip" "true" >/dev/null 2>&1; then
    echo "$ip SKIP"
    continue
  fi
  out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$ip" "$remote" 2>/dev/null || true)
  echo "$ip $out"
done
