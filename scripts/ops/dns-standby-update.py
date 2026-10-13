#!/usr/bin/env python3
"""Update TrueNAS DNS standby containers only when docker pull changes the image.

Recreates technitium-standby and adguard-2. Leaves a stopped -prev container.
Does not print environment values. Writes /home/truenas_admin/standby-update.txt.
"""
from __future__ import annotations

import json
import subprocess

LOG = "/home/truenas_admin/standby-update.txt"
NAMES = ("technitium-standby", "adguard-2")


def log(msg: str) -> None:
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(msg + "\n")
    print(msg, flush=True)


def run(args: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=check, text=True, capture_output=True)


def extra_env(container_env: list[str], image_env: list[str]) -> list[str]:
    base = set(image_env or [])
    kept: list[str] = []
    for item in container_env or []:
        if item in base or item.startswith("DOTNET_"):
            continue
        kept.append(item)
    return kept


def recreate(name: str) -> None:
    inspected = run(["docker", "inspect", name], check=False)
    if inspected.returncode != 0:
        log(f"SKIP {name} not present")
        return
    meta = json.loads(inspected.stdout)[0]
    ref = meta["Config"]["Image"]
    old_id = meta["Image"]
    pulled = run(["docker", "pull", ref], check=False)
    if pulled.returncode != 0:
        log(f"FAIL {name} pull")
        return
    new_id = run(["docker", "image", "inspect", "--format", "{{.Id}}", ref]).stdout.strip()
    if new_id == old_id:
        log(f"no patches available {name}")
        return

    image_env = json.loads(run(["docker", "image", "inspect", ref]).stdout)[0]["Config"].get("Env") or []
    host = meta["HostConfig"]
    prev = f"{name}-prev"
    run(["docker", "rm", "-f", prev], check=False)
    run(["docker", "stop", name])
    run(["docker", "rename", name, prev])

    cmd = ["docker", "run", "-d", "--name", name]
    restart = (host.get("RestartPolicy") or {}).get("Name") or ""
    if restart and restart != "no":
        cmd.extend(["--restart", restart])
    if host.get("Privileged"):
        cmd.append("--privileged")
    network = host.get("NetworkMode") or "bridge"
    if network and network not in ("default", "bridge"):
        cmd.extend(["--network", network])
    if network != "host":
        for cport, bindings in (host.get("PortBindings") or {}).items():
            for binding in bindings or []:
                host_port = binding.get("HostPort") or ""
                host_ip = binding.get("HostIp") or ""
                if not host_port:
                    continue
                spec = f"{host_ip}:{host_port}:{cport}" if host_ip else f"{host_port}:{cport}"
                cmd.extend(["-p", spec])
    for bind in host.get("Binds") or []:
        cmd.extend(["-v", bind])
    for item in extra_env(meta["Config"].get("Env") or [], image_env):
        cmd.extend(["-e", item])
    cmd.append(ref)

    created = run(cmd, check=False)
    running = False
    if created.returncode == 0:
        state = run(["docker", "inspect", "--format", "{{.State.Running}}", name], check=False)
        running = state.returncode == 0 and state.stdout.strip() == "true"
    if running:
        log(f"SWITCHED {name}")
        return

    run(["docker", "rm", "-f", name], check=False)
    run(["docker", "rename", prev, name], check=False)
    run(["docker", "start", name], check=False)
    log(f"ROLLBACK {name}")


def main() -> None:
    open(LOG, "w", encoding="utf-8").close()
    for name in NAMES:
        try:
            recreate(name)
        except subprocess.CalledProcessError:
            log(f"FAIL {name}")
    log("DONE")


if __name__ == "__main__":
    main()
