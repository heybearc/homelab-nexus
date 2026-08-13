# Task State - homelab-nexus

**Last updated:** 2026-08-13 (end-day)

---

## Current Task
**3-node Proxmox cluster** — IN PROGRESS (hardware + phased join; production still on prox1)

### What I'm doing right now
Cluster plan locked (hybrid NFS + local). prox2/prox3 installed. Quote Builder infra handed off to app repo. Scrypted reconnect storm cleared 2026-08-10 with service restart — watch for recurrence.

### Recent completions
- ✅ **Quote Builder blue-green** — CT200/201, reusable `deploy-bluegreen-app.yml`, HAProxy (`quotes` / `blue-quotes` / `green-quotes`), NPM, MCP, handoff ready (2026-07-28 → 2026-08)
- ✅ **App keep/retire audit** — recommend retire LDC/QuantShift/CT119 later; no destroys (2026-07-28)
- ✅ **Scrypted interruption fix** — Baichuan reconnect storm; `systemctl restart scrypted` restored streams (2026-08-10)
- ✅ **prox2/prox3 + interim NFS + cluster buy list** — SX3016F + X520-DA2 (2026-07-24)

### Next steps
1. **Buy / receive:** Omada **SX3016F** + **2× Intel X520-DA2** (SFP+), or start Phase 1 on 1G
2. **Phase 1:** rename `prox` → `prox1`; align PVE `8.4.19`; `pvecm create` / join (no guest moves)
3. Watch Scrypted — if interruptions return, reduce concurrent streams (remote/low-res)
4. Optional: focused git commits for ansible BG template + DNS/monitoring (still uncommitted bulk)
5. Pending: Technitium `cloudigan.com` conditional forward → `10.92.0.10`

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator Phase 1**
- **Personal Ops Center** — backlog
- **LDC / QuantShift / chapter-hub-dev destroy** — approved retire later only

---

## Known Issues

- **Scrypted** — sustained Baichuan disconnect storm possible under multi-stream load (main/ext/sub + NVR variants); Garage `.remote` often empty; H.265 codec warnings; NFS EBUSY on prune
- **SG3428XMP has only 4× SFP+** — need SX3016F before dual 10G on all nodes
- **NFS ~104 MB/s interim** — prox host has no IP on 10G VLAN
- **TrueNAS media-pool** — interim; evacuate before disk rebuild
- **`cloudigan.com` AD DNS** — conditional forward still pending
- **Technitium** — production passwords (not `admin`/`admin`); API token for automation
- **prox `hdd-pool` DEGRADED** (verify current status)
- **NPM cert #30 expired** — tautulli NXDOMAIN (D-HOMELAB-007)

---

## Uncommitted work

- **Large untracked/modified set:** ansible (BG template, DNS, HHV/mail), monitoring, docs, logos, `.cursor/` — leave until focused commits
- **Intentionally uncommitted:** `files/Logos/`, bulk IDE noise
- **No end-day bulk commit** — context files only if committed separately
- Branch **ahead of origin** — push only when desired

---

## Exact Next Command

```text
# Cluster Phase 1 (1G OK) — version align then rename:
ssh root@10.92.0.5 'pveversion -v | head -1'
ssh root@10.92.0.6 'pveversion -v | head -1'
ssh root@10.92.0.7 'pveversion -v | head -1'
# Then rename prox→prox1 and pvecm create/join

# If Scrypted flaky again:
ssh scrypted 'systemctl restart scrypted'
```

**Tomorrow first action:** Resume **3-node cluster Phase 1** (version check → prox→prox1), or confirm SX3016F/X520 order status. Quote Builder product work lives in `~/Projects/cloudigan-quote-builder`.

---

## Infrastructure quick reference

| Service | Primary | Notes |
|---------|---------|--------|
| prox / prox1 | `10.92.0.5` | Rename before cluster |
| prox2 | `10.92.0.6` | iDRAC `10.92.0.16` |
| prox3 | `10.92.0.7` | iDRAC `10.92.0.17` |
| TrueNAS | `10.92.0.3` / NFS `10.92.3.200` | `truenas-proxmox`, `truenas-backups` |
| Switch | SG3428XMP `10.92.0.2` | 4× SFP+ full |
| Scrypted | CT180 `10.92.3.15` | Driveway `.184`, Garage `.189`, Front Porch `.190` |
| Quote Builder | CT200/201 `.100`/`.101` | LIVE=blue; `quotes.cloudigan.net` |
| Plan | `.cursor/plans/3-node_cluster_architecture_*.plan.md` | Hybrid NFS + local |
