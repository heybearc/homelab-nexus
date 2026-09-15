#!/usr/bin/env python3
"""Enable shared vztmpl/iso on truenas-proxmox and copy templates from prox1."""
import subprocess
import sys


def ssh(host, cmd, timeout=60):
    r = subprocess.run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=15",
            host,
            cmd,
        ],
        capture_output=True,
        text=True,
    )
    return r.returncode, r.stdout, r.stderr


def main():
    rc, cfg, err = ssh("root@10.92.0.6", "cat /etc/pve/storage.cfg")
    if rc != 0:
        print("read storage.cfg failed", err)
        sys.exit(1)
    if "nfs: truenas-proxmox" not in cfg:
        print("truenas-proxmox storage missing")
        sys.exit(1)
    if "content images,rootdir,vztmpl,iso" not in cfg:
        patched = cfg.replace(
            "\tcontent images,rootdir\n\toptions vers=4.2\n\nnfs: truenas-backups",
            "\tcontent images,rootdir,vztmpl,iso\n\toptions vers=4.2\n\nnfs: truenas-backups",
        )
        if patched == cfg:
            print("storage.cfg pattern mismatch, abort")
            print(cfg)
            sys.exit(1)
        # write via python on the node (D-033)
        py = (
            "p='/etc/pve/storage.cfg'\n"
            "open(p,'w').write(%r)\n" % patched
        )
        rc, o, e = ssh("root@10.92.0.6", "python3 -c %s" % repr(py))
        print("patched storage.cfg rc", rc, o, e)
    else:
        print("storage.cfg already has vztmpl,iso")

    rc, o, e = ssh(
        "root@10.92.0.6",
        "mkdir -p /mnt/pve/truenas-proxmox/template/cache "
        "/mnt/pve/truenas-proxmox/template/iso && "
        "ls -la /mnt/pve/truenas-proxmox/template/cache",
    )
    print(o, e)

    rc, o, e = ssh(
        "root@10.92.0.5",
        "ls /var/lib/vz/template/cache/*.tar.zst",
    )
    print("prox1 templates:", o)
    rc, o, e = ssh(
        "root@10.92.0.5",
        "cp -an /var/lib/vz/template/cache/*.tar.zst "
        "/mnt/pve/truenas-proxmox/template/cache/ && "
        "ls -lh /mnt/pve/truenas-proxmox/template/cache",
        timeout=120,
    )
    print(o, e, "rc", rc)
    rc, o, e = ssh("root@10.92.0.7", "pveam list truenas-proxmox")
    print("prox3 pveam:\n", o, e)


if __name__ == "__main__":
    main()
