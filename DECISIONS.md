# Architecture Decision Records

## D-CLOUDIGAN-001: Stripe-Datto Webhook Integration Architecture
**Date:** 2026-03-17
**Context:** Need automated Datto RMM site creation and agent download link delivery after Stripe checkout completion
**Decision:** Implemented webhook-based integration with dual delivery: Wix CMS for dynamic thank-you page + optional SendGrid email backup
**Consequences:** 
- Customers get immediate access to download links via dynamic page
- All customer download data stored in Wix CMS for future reference
- Datto OAuth token auto-refreshes every 100 hours via Playwright automation
- Infrastructure: CT181 container with HAProxy blue-green routing and NPM SSL termination

## D-CLOUDIGAN-002: Multi-Platform Download Link Generation
**Date:** 2026-03-17
**Context:** Customers need RMM agents for Windows, macOS, and Linux
**Decision:** Generate all three platform download links on every checkout, store in Wix CMS
**Consequences:** 
- Single webhook creates all platform links: `https://{platform}.rmm.datto.com/download-agent/{os}/{siteUid}`
- Customers can download for any platform without additional requests
- Thank-you page can display all options dynamically

## D-CLOUDIGAN-003: Wix CMS as Customer Download Registry
**Date:** 2026-03-17
**Context:** Need persistent storage for customer download links accessible from Wix site
**Decision:** Use Wix CMS collection "CustomerDownloads" with public read permissions
**Consequences:**
- Download links accessible via session ID from Stripe redirect
- Data persists for customer reference and support purposes
- Enables dynamic thank-you page without additional backend
- Field mapping: `dattoSiteUid`, `macOsDownloadLink` (capital O) required for Wix schema

## D-CLOUDIGAN-004: Datto OAuth Token Auto-Refresh Strategy
**Date:** 2026-03-17
**Context:** Datto OAuth tokens expire after 100 hours, manual refresh not scalable
**Decision:** Implemented automatic token refresh with 1-hour safety buffer using Playwright
**Consequences:**
- Token cached in `/opt/cloudigan-api/.datto-token.json`
- Every API call checks expiration, auto-refreshes if <1 hour remaining
- No manual intervention required for production operation
- Webhook remains operational 24/7 without downtime

## D-CLOUDIGAN-005: Authentik Identity Provider Branding & User Onboarding
**Date:** 2026-04-22
**Context:** Authentik needed Cloudigan branding and a scalable user onboarding system for staff/client access to internal apps
**Decision:** Custom brand at `auth.cloudigan.net` domain with Cloudigan logo/favicon; invitation-based enrollment with group auto-assignment from invite `fixed_data`
**Consequences:**
- Cloudigan branding applied to all auth flows (logo, favicon, "Welcome to Cloudigan!" titles)
- Three groups: `cloudigan-admins`, `cloudigan-staff`, `cloudigan-clients`
- Invites specify target group in `fixed_data: {"group": "cloudigan-staff"}` — expression policy assigns on enrollment
- TIP Generator access controlled via group bindings (admins + staff only)
- API token stored as `AUTHENTIK_API_TOKEN` in `.env` for programmatic invite creation
- Outpost "unhealthy" warning is cosmetic (WebSocket loopback) — non-blocking

## D-HOMELAB-001: TIP Generator Phased Rollout Strategy
**Date:** 2026-04-17
**Context:** Need AI-powered system to generate Technical Implementation Plans from customer discovery data and service orders
**Decision:** Build web application with phased rollout: v1 single-user → v2 team collaboration
**Consequences:**
- **v1 Focus:** Personal use with remote access, single reusable Word template, draft management
- **Template Intelligence:** Auto-detect structure, styles, colors from Word template on startup
- **AI Strategy:** Claude API with template-aware prompts for section-by-section generation
- **Tech Stack:** React + FastAPI + PostgreSQL (familiar, proven, scalable)
- **Authentication:** Authentik OAuth or M365 OAuth for remote access
- **v2 Expansion:** Team collaboration, blue-green deployment, multiple templates
- **Timeline:** 4 weeks for v1 (planning → deployment)
- **Plan Location:** `~/.windsurf/plans/tip-generator-webapp-424e2d.md`

## D-HOMELAB-003: Nextcloud Object Store Migration MinIO → AIStor (Free)
**Date:** 2026-05-07
**Context:** TrueNAS deprecated the community MinIO app in April 2026 because upstream MinIO transitioned to source-only/maintenance mode. Our Nextcloud instance (`10.92.5.200:9002`) uses MinIO as its **primary** S3 object store for ~1.1 TB / 137,336 objects in bucket `nc-data` (Nextcloud `oc_filecache` rows reference these by object key). A regression here breaks file access for all users.
**Decision:** Migrate to **MinIO AIStor (Free tier)** in-place against the existing on-disk data, keeping the same host path, ports, and root credentials so Nextcloud's stored S3 config required zero changes.
**Alternatives considered:**
- **SeaweedFS** — mature, Apache 2.0; rejected due to documented Nextcloud PROPFIND/dir-create instability with 100k+ objects.
- **Garage** — lovely but AGPLv3 and would have required full S3-to-S3 data migration (different on-disk format) for 1.1 TB.
- **VersityGW** — POSIX-on-S3 gateway changes storage semantics; not safe for an existing populated dataset.
- **RustFS** — too new for production data of this size.
**Consequences:**
- AIStor reuses the MinIO on-disk format → zero data movement; just remounted `/mnt/media-pool/minio` from `/export` → `/data` and chowned 473:473 → 568:568 for the AIStor `apps` user.
- Same `MINIO_ROOT_USER=admin` / same password / same `nc-data` bucket / same ports (9000 API, 9001 console) on `10.92.5.200` → Nextcloud `OBJECTSTORE_S3_*` env vars unchanged.
- Free-tier license is no-cost but **required** — without one, AIStor RELEASE.2026-05-04 boots in offline mode and blocks all S3 ops. License JWT is stored in the TrueNAS app config (`aistor.license_key`).
- Free tier limits: single-node only (fine for homelab), no multi-site replication, no object tiering, no `mc support`. Acceptable for our usage.
- Old `minio` app deleted from TrueNAS Apps; data preserved on disk + ZFS snapshot `media-pool/minio@pre-aistor-20260507` as rollback.
- Performed via `midclt` (TrueNAS middleware API) entirely from this agent — no UI clicks.
- **Migration runbook:** `documentation/AISTOR-MIGRATION-2026-05-07.md`.

## D-HOMELAB-004: Vaultwarden MSP HA — Primary + Backup, Not Active/Active
**Date:** 2026-05-12
**Context:** Plan to offer Vaultwarden as an MSP-style service on **`vault.cloudigan.com`** (`.com` branding) behind NPM and HAProxy, with redundancy expectations.
**Decision:** Use **one active Vaultwarden** at a time. HAProxy (or equivalent) routes to a **primary** backend with a **`backup`** peer and HTTP health checks on **`/alive`**. Standby holds replicated **PostgreSQL** (or promoted replica on failover) and replicated **`DATA_FOLDER`** / ZFS sync—**not** two independent writers serving the same logical instance concurrently.
**Alternatives considered:**
- **Round-robin / active-active to two Vaultwarden processes** — rejected: unsupported multi-writer semantics for Vaultwarden’s on-disk state + DB; high risk of corruption or subtle client bugs.
- **Single node + DR only** — acceptable **v1**; document RPO/RTO honestly if HA deferred.
**Consequences:**
- Marketing language should say **failover / DR**, not live/live clustering, unless architecture changes to a vendor-supported clustered Bitwarden deployment.
- **`DOMAIN`** must match the public URL users enter in Bitwarden (e.g. `https://vault.cloudigan.com`).
- White label remains **server-side** (SMTP, templates, web vault assets); clients stay Bitwarden-branded apps.

## D-HOMELAB-005: Homelab admin SSH — `homelab_root` everywhere except TP-Link switch
**Date:** 2026-05-16  
**Context:** Audit required consistent key-based SSH for automation (Ansible, MCP, scripts) across Proxmox LXCs and Windows VMs.  
**Decision:** Use `~/.ssh/homelab_root` for all LXCs (`root`) and Windows Administrator hosts. Bulk deploy via `pct exec` from `prox`. Windows domain admins use `C:\ProgramData\ssh\administrators_authorized_keys` with **one key per line**.  
**Exceptions:** TP-Link SG3428XMP (`switch`, 10.92.0.2) remains password-only until key imported in switch UI (legacy ciphers). TrueNAS uses `truenas_admin` on port 222 with same key.  
**Control plane:** Promoted as **D-041** in Cloudy-Work `DECISIONS.md`. Runbook: `_cloudy-ops/ssh/deploy-homelab-root-keys.md`.

## D-HOMELAB-006: Cloudigan Vault MSP — new product; Stripe via Cloudigan API
**Date:** 2026-05-16  
**Context:** `vault.cloudigan.com` is a paid MSP offering for customers (white-label Vaultwarden), separate from homelab TrueNAS Vaultwarden. Question whether to move Stripe automation to n8n.  
**Decision:** **New customer instance** on CT171/172 (not a cutover from TrueNAS). **Stripe checkout → Cloudigan API** webhook (extend D-038 `product_type` routing with `vault`); n8n only for optional non-critical side workflows. Proposed SMB pricing tiers documented in `documentation/CLOUDIGAN-VAULT-PRODUCT.md` (not yet in Stripe).  
**Consequences:** HAProxy MSP pool uses BLUE primary / GREEN backup only (TrueNAS excluded). Billing enforcement via invites/org seats + API automation, not Vaultwarden-native subscriptions.

## D-HOMELAB-007: NPM multi-domain certs — split when domains decommission
**Date:** 2026-05-28  
**Context:** Bitwarden clients failed with "failed to fetch" on `vaultwarden.cloudigan.net`. TrueNAS Vaultwarden was healthy; NPM proxy host 47 used expired Let's Encrypt cert #30 (expired 2026-05-24). Renewal failed because cert #30 bundled decommissioned `tautulli.cloudigan.net` (NXDOMAIN). Homelab personal vaults were never migrated to CT171/172 MSP stack (D-HOMELAB-006).  
**Decision:** Issue **dedicated per-domain (or small-group) NPM certs** for active hostnames. Do not rely on large multi-domain bundles that include retired services. Homelab personal Vaultwarden stays on TrueNAS @ `https://vaultwarden.cloudigan.net`; MSP product stays @ `https://vault.cloudigan.com`.  
**Consequences:** `vaultwarden.cloudigan.net` now uses NPM cert #103 (valid through 2026-08-26). Remaining domains on expired cert #30 need individual re-issue. Remove decommissioned hostnames from any cert before renewal attempts.

## D-HOMELAB-009: DNS redundancy — Technitium authority, dual AdGuard, no password in .env
**Date:** 2026-06-08  
**Context:** Migrate internal DNS from dc-01 to Technitium (Proxmox primary + TrueNAS secondary) with dual AdGuard filtering; DHCP cutover without dc-01 as client resolver.  
**Decision:** Clients use **AdGuard** (`10.92.3.11` / `10.92.3.204`) → **Technitium** (`10.92.3.10` / `10.92.3.203`) for resolution. Technitium holds `cloudigan.net` + product zones; **`cloudigan.com` stays on dc-01** (AD) until identity migration. Technitium admin password lives in **`auth.config` (UI only)** — not `TECHNITIUM_PASSWORD` in `.env` or Docker env after initial bootstrap. Optional `TECHNITIUM_API_TOKEN` for automation scripts.  
**Consequences:** DHCP DNS #1/#2 are AdGuard IPs only. Must add **conditional forward `cloudigan.com` → dc-01** while AD domain-joined machines exist. Per-zone Technitium permissions required for UI visibility (group membership alone insufficient). Do not decommission dc-01 for 2+ weeks. Runbook: `documentation/DNS-REDUNDANCY-MIGRATION.md`, `scripts/dns/STEPS-2-4.md`.

## D-HOMELAB-010: Reolink CX810 in Scrypted — Native plugin, uid per IP, NVR on TrueNAS NFS
**Date:** 2026-06-12  
**Context:** Three Reolink CX810 on management LAN (`10.92.0.x`); Scrypted CT180 on `10.92.3.15`; only Baichuan port 9000 open until Reolink app enables HTTP/RTSP/ONVIF.  
**Decision:** Use **`@apocaliss92/scrypted-reolink-native`** (not `@scrypted/reolink` alone). When adding multiple same-model cameras, pass **`uid` = camera IP** in `createDevice` so nativeIds do not collide. NVR recordings on existing TrueNAS NFS mount **`/mnt/recordings`** (`10.92.0.3:/mnt/media-pool/recordings`). Enable NVR via mixin **31** on each camera.  
**Consequences:** CX810 default RTMP port may be **1935** (not 9000). Disable HTTPS on camera for Scrypt compatibility. Prefer alphanumeric camera admin password for RTSP. Continuous NVR ~85 GB/camera/day at 2K — set retention explicitly when pool usage matters.

## D-HOMELAB-008: HHV production site — Next.js on standard blue-green pattern
**Date:** 2026-06-05  
**Context:** New customer-facing site at `helpfulhirschventures.com` on dedicated blue-green pair (CT198/199).  
**Decision:** Deploy as **Next.js 14 + TypeScript** on port **3001**, PM2 `hhv-blue` / `hhv-green`, MCP app id `hhv`, HAProxy ACL `is_hhv`, optional Postgres DB `hhv` on CT131 when forms/CRM needed. External DNS + NPM are operator-managed (not Ansible). App repo is **`heybearc/hhv`**.  
**Consequences:** Follows Chapter Hub / FactorPoint deploy model. `connection_limit=5` on Prisma when DB added.

## D-HOMELAB-011: TD Synnex PO numbers — Redis atomic counter + Cursor slash command
**Date:** 2026-07-08  
**Context:** Need sequential PO numbers for TD Synnex orders (`Cloud-PO-0019` was last used); no procurement/ERP in lab.  
**Decision:** Store counter in **Redis** on `redis-shared` (CT192) key `synnex:po:counter` with **`INCR`** for atomic allocation. Format **`Cloud-PO-####`** (4-digit pad). Script: `scripts/procurement/next-synnex-po.sh` (SSH fallback when local `redis-cli` missing). Cursor commands: `/next-po` (allocate), `/next-po-peek` (preview).  
**Consequences:** Next PO after seed 19 is **Cloud-PO-0020** (issued 2026-07-08). Re-seed with `--set N` where N is last issued sequence. No audit log yet — add later if needed (Postgres row or append-only file).

## D-HOMELAB-012: 3-node cluster — hybrid NFS + local; SX3016F + X520-DA2
**Date:** 2026-07-24  
**Context:** Expand to prox1/prox2/prox3 with HA, rolling upgrades, and workload balance without breaking production on current prox. SG3428XMP has only 4× SFP+ (TrueNAS LACP + prox1 dual). NFS via mgmt gateway ~104 MB/s.  
**Decision:** **Hybrid storage** — TrueNAS NFS (`truenas-proxmox`, 4T `media-pool/vms/proxmox`) for migratable/HA guests only; keep DBs/Scrypted/Plex on **local** disks (pin GPU/TPU workloads to prox1). Buy **Omada SX3016F** for storage-only SFP+/DAC fabric and **2× Intel X520-DA2** (82599) for prox2/prox3. Prefer TrueNAS+Proxmox on the storage switch (not hairpin via Omada uplink). Do **not** use Ceph on PERC RAID. Rename `prox`→`prox1` before `pvecm create`. Cluster join may proceed on 1G before 10G hardware arrives.  
**Consequences:** HA only for NFS-backed guests. Evacuate `truenas-proxmox` before TrueNAS disk rebuild. Plan: `.cursor/plans/3-node_cluster_architecture_*.plan.md`. **Guest placement for new deploys superseded by D-HOMELAB-014** (all new LXCs/VMs on `truenas-proxmox`).

## D-HOMELAB-013: Technitium is client DNS SoT — AdGuard optional filter
**Date:** 2026-08-20  
**Context:** Restarting AdGuard took out client internet/DNS because DHCP pointed only at AdGuard. Dual authority (dc-01 + Technitium) caused zone drift (`quotes` vs `jellyfin`).  
**Decision:**  
- **DHCP DNS #1/#2** = Technitium `10.92.3.10` / `10.92.3.203` (authoritative + recursive).  
- **AdGuard** (`10.92.3.11` / `.204`) is **optional** filtering only — not on the critical path.  
- Technitium owns `cloudigan.net` + product zones; lab automation writes Technitium API only (`dns-add-record.sh`).  
- Conditional forwarders on Technitium: `cloudigan.com` + `_msdcs.cloudigan.com` → `10.92.0.10` while AD remains.  
- Public recursion via Technitium forwarders `1.1.1.1` / `9.9.9.9`.  
**Consequences:** Omada DHCP must be cut over (see `documentation/DNS-TECHNITIUM-AUTHORITATIVE.md`). AdGuard outages no longer break resolution. dc-01 stays until Entra migration. Supersedes client-path portion of D-HOMELAB-009 (AdGuard-as-DHCP-DNS).

## D-HOMELAB-014: All new Proxmox guests on TrueNAS NFS
**Date:** 2026-09-02  
**Context:** New LXCs/VMs were still being created on local `hdd-pool` / `local-lvm` while Windows 11 and ops-stack already used `truenas-proxmox`.  
**Decision:** **Every new deploy** (Ansible, `provision-container.sh`, Semaphore templates) places guest disks on **`truenas-proxmox`**. Do not use `hdd-pool` or `local-lvm` for new containers or VMs.  
**Consequences:** Shared playbooks `deploy-proxmox-container.yml` / `deploy-proxmox-vm.yml` default and assert this datastore. Existing local guests are not migrated by this decision. Supercedes new-guest placement in D-HOMELAB-012 (cluster NIC/switch plan unchanged).

## D-HOMELAB-015: Omada Controller CT142 — 8 GB RAM
**Date:** 2026-09-08  
**Context:** CT142 `omada-controller` @ `10.92.0.34` wedged: Omada Java stuck in disk wait, cgroup RAM ~1.9/2 GB, only SSH :22 listening, `https://omada.cloudigan.net` 502. Access points kept serving without the controller. A 4 GB bump still sat at ~3.8 GB used right after `tpeap` started (jsvc ~2.5 GB + Java `-Xmx1024m` + mongod). Mongo logged one OOM start (`exit 127`) then recovered.  
**Decision:** Keep CT142 at **8192 MB RAM** (swap 1024). Do not run the Omada controller at 2 GB.  
**Consequences:** APs continue independently if the controller dies again; recover with `pct stop 142` (kill if I/O-stuck) then `pct start 142`. UI: `https://omada.cloudigan.net` → NPM → `10.92.0.34:8043`. Rootfs remains NFS `truenas-proxmox` (D-HOMELAB-014).

## D-HOMELAB-016: Postgres RW VIP + split-host HA + shared LXC templates
**Date:** 2026-09-15  
**Context:** After PVE 9 on all three nodes, HAProxy LIVE+STANDBY were both on prox3 and Postgres primary+replica were both on prox2. Replica CT151 was Ubuntu 24.04 / glibc 2.39 vs primary Debian 12 / glibc 2.36. Apps connected to `10.92.3.21`, so watchdog promote did not move traffic. LXC templates lived only on prox1 `local`.  
**Decision:**  
- Place HAProxy pair and Postgres pair on **different nodes** (LIVE 136 + replica 151 + monitoring 150 on **prox3**; STANDBY 139 + primary 131 on **prox2**). GPU CTs stay on prox1. Do not PVE-HA blue-green pairs.  
- Apps use keepalived **RW VIP `10.92.3.23`** (`postgres.cloudigan.net` / `postgresql.cloudigan.net`, VRID 52). Node IPs `.21`/`.31` are for replication and admin only.  
- Rebuild CT151 on **Debian 12** from shared NFS templates so libc matches the primary.  
- `truenas-proxmox` content includes **`vztmpl,iso`**; all nodes use `truenas-proxmox:vztmpl/…`.  
**Consequences:** Failover = watchdog promote on CT150 + VIP follow. Replication `primary_conninfo` must stay on `.21`/`.31`, never the VIP. 10G fabric / corosync link1 / PVE HA for NFS singletons still wait on SX3016F + X520 (D-HOMELAB-012).

## D-HOMELAB-002: TIP Generator Template Management Approach
**Date:** 2026-04-17
**Context:** Word template needs to be reusable across projects with style preservation
**Decision:** Server-side template file with intelligent parsing, not per-project upload
**Consequences:**
- Single template stored at `/data/tip-generator/templates/active-template.docx`
- Template parsed on application startup to extract structure, styles, colors
- Section taxonomy cached for fast generation
- Template updates: replace file on server (v2: admin UI)
- AI generates content that preserves original template formatting
- Export clones template and populates with AI content
- Ensures consistent branding and styling across all generated TIPs
