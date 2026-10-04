#!/usr/bin/env python3
"""Remount this node's TrueNAS NFS via 10.92.2.200.

Run only after every guest on this node has left. The mount source must
be 10.92.2.200; an addr= option on a 10.92.3.200 source is ignored, and
an existing NFSv4 session to that server is reused until every mount is gone.
"""
import subprocess
import sys
import time
from pathlib import Path

CLIENT = sys.argv[1]
SERVER = "10.92.2.200"
OPTS = f"vers=4.2,clientaddr={CLIENT},_netdev"

FSTAB_MOUNTS = [
    ("/mnt/media-pool/data", "/mnt/pve/media-pool", "nfs4"),
    ("/mnt/media-pool/recordings", "/mnt/truenas-recordings", "nfs"),
    ("/mnt/media-pool/tip-uploads", "/mnt/pve/tip-uploads", "nfs"),
    ("/mnt/media-pool/theoshift-uploads", "/mnt/pve/theoshift-uploads", "nfs"),
]
PVE_MOUNTS = [
    ("/mnt/media-pool/vms/proxmox", "/mnt/pve/truenas-proxmox"),
    ("/mnt/media-pool/data/proxmox-backups", "/mnt/pve/truenas-backups"),
]


def run(cmd):
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=False)


def must(cmd):
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)


def running_guests():
    out = subprocess.check_output(["pct", "list"], text=True).splitlines()[1:]
    cts = [ln.split()[0] for ln in out if len(ln.split()) > 1 and ln.split()[1] == "running"]
    qout = subprocess.check_output(["qm", "list"], text=True).splitlines()[1:]
    vms = []
    for ln in qout:
        parts = ln.split()
        if len(parts) > 2 and parts[2] == "running":
            vms.append(parts[0])
    return cts, vms


def rewrite_fstab():
    path = Path("/etc/fstab")
    original = path.read_text()
    path.with_name("fstab.bak-vlan922").write_text(original)
    lines = []
    for line in original.splitlines():
        if "10.92.3.200:" not in line or line.lstrip().startswith("#"):
            lines.append(line)
            continue
        bits = line.split()
        if len(bits) < 4:
            raise SystemExit(f"unexpected fstab line: {line}")
        bits[0] = bits[0].replace("10.92.3.200:", f"{SERVER}:")
        opts = [o for o in bits[3].split(",") if not o.startswith("addr=") and not o.startswith("clientaddr=")]
        extra = f"clientaddr={CLIENT}"
        if extra not in opts:
            opts.append(extra)
        if "vers=4.2" not in opts:
            opts.append("vers=4.2")
        bits[3] = ",".join(opts)
        lines.append(" ".join(bits))
    path.write_text("\n".join(lines) + "\n")
    print("fstab updated")


def nfs_mounts():
    out = subprocess.check_output(["findmnt", "-t", "nfs,nfs4", "-n", "-o", "TARGET"], text=True)
    return [ln.strip() for ln in out.splitlines() if ln.strip()]


def main():
    cts, vms = running_guests()
    if cts or vms:
        raise SystemExit(f"refusing: running guests ct={cts} vm={vms}")
    rewrite_fstab()
    run(["systemctl", "stop", "pvestatd"])
    time.sleep(1)
    targets = nfs_mounts()
    # Unmount deepest paths last-in first. Repeat until the v4 session can die.
    for _ in range(5):
        targets = nfs_mounts()
        if not targets:
            break
        for target in reversed(targets):
            run(["umount", target])
        time.sleep(1)
    left = nfs_mounts()
    if left:
        raise SystemExit(f"still mounted: {left}")
    time.sleep(2)
    for export, target, fstype in FSTAB_MOUNTS:
        must(["mount", "-t", fstype, "-o", OPTS, f"{SERVER}:{export}", target])
    for export, target in PVE_MOUNTS:
        must(["mount", "-t", "nfs", "-o", OPTS, f"{SERVER}:{export}", target])
    print("--- findmnt ---")
    run(["findmnt", "-t", "nfs,nfs4", "-o", "TARGET,SOURCE,OPTIONS"])
    print("--- ss ---")
    run(["ss", "-tn", "dst", SERVER])
    run(["ss", "-tn", "dst", "10.92.3.200"])
    run(["systemctl", "start", "pvestatd"])
    time.sleep(2)
    run(["pvesm", "status"])


if __name__ == "__main__":
    main()
