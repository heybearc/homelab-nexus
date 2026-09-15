# Jellyfin (CT122)

**Hostname:** `jellyfin`  
**CTID:** 122  
**IP:** `10.92.3.20/24` on `vmbr0923`, gw `10.92.3.1` (D-020)  
**Port:** 8096  
**Domain:** `jellyfin.cloudigan.net`  
**Ansible:** `ansible/playbooks/deploy-jellyfin.yml`

---

## Wiring

| Layer | Value |
|-------|--------|
| LXC disk | `truenas-proxmox` (TrueNAS NFS; D-HOMELAB-014) |
| LXC resolver | `nameserver 10.92.3.11` (AdGuard **filter only**), `search cloudigan.net` |
| DNS authority | **Technitium** zone `cloudigan.net` — A `jellyfin` → `10.92.3.3` (NPM). DC manages AD/`cloudigan.com`. Do **not** use AdGuard rewrites for app DNS. |
| NPM proxy | host `jellyfin.cloudigan.net` → `10.92.3.20:8096` (id 124, cert 129) |
| Media | `mp0` `/mnt/pve/media-pool` → `/mnt/data` (TrueNAS, same as Plex) |
| SSH | `ssh jellyfin` (`homelab_root`) |

---

## Deploy / re-run

```bash
cd /Users/cory/Projects/homelab-nexus
set -a && source .env && set +a   # TECHNITIUM_API_TOKEN for zone updates
cd ansible && ansible-playbook playbooks/deploy-jellyfin.yml
```

DNS-only:

```bash
cd ansible && ansible-playbook playbooks/deploy-jellyfin.yml --start-at-task 'Configure Technitium DNS'
```

---

## Verify

```bash
curl -sS http://10.92.3.20:8096/health
dig +short jellyfin.cloudigan.net @10.92.3.10   # Technitium — expect 10.92.3.3
dig +short jellyfin.cloudigan.net @10.92.3.11   # via AdGuard filter — expect 10.92.3.3
curl -sS -o /dev/null -w '%{http_code}\n' https://jellyfin.cloudigan.net/health
```

Setup wizard: `https://jellyfin.cloudigan.net` — libraries under `/mnt/data/media/...`.

---

## Operator steps

1. Complete Jellyfin first-run wizard; published URL `https://jellyfin.cloudigan.net`.
2. Point libraries at `/mnt/data/media/...`.

**2026-08-20:** Technitium A + secondary resync; NPM 124 + LE 129. AdGuard rewrite removed (filter-only).
