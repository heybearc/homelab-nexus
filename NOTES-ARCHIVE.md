---
purpose: Archive of rolled daily notes
---


## 2026-05-20

_Rolled from NOTES-TODAY.md_

---
date: 2026-05-16
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus (paused — other task)
- **Cloudigan Vault MSP** — infra deployed; product/pricing captured in `documentation/CLOUDIGAN-VAULT-PRODUCT.md`

### Session summary (2026-05-16, agent chat)
- Deployed CT171/172 (BLUE active `.94`, GREEN standby `.95`); Netbox; privileged LXC + SSH fixes
- HAProxy `vaultwarden_ha`: BLUE primary, GREEN backup — **not** homelab TrueNAS (separate product)
- NPM proxy **107** for `vault.cloudigan.com` → VIP `10.92.3.33`
- User clarified: **new paid MSP instance**, not TrueNAS cutover; white-label + subscriptions
- **Stripe automation:** stay on **Cloudigan API** (extend D-038 routing); n8n only for optional side workflows
- **Wix MCP:** cannot add DNS (403 `DOMAINS.READ_DNS_ZONES`) — user doing manual A → `174.104.207.3`
- **Pricing:** proposed Starter / Business / Business Plus tiers in product doc (not in Stripe yet)

### Discoveries / Notes
- Nextcloud verified OK — no lockouts; NPM forwards headers via standard include
- CT130 had 3 daily vzdump jobs; local filled root to 92% → fixed
- Ansible `wait_for` port+path bug fixed → `uri` module in `configure-vaultwarden-node.yml`

### Decisions to Promote
- ✅ **D-HOMELAB-006** — Cloudigan Vault MSP product model + Cloudigan API billing (not n8n)

### Mid-day checkpoint (2026-05-16)
- Vault MSP **paused**; resume at `documentation/CLOUDIGAN-VAULT-PRODUCT.md`
- Infra done: CT171/172, HAProxy, NPM 107; pending DNS, Stripe, API vault branch, branding
- No `PLAN.md` in homelab-nexus; no URGENT feedback items

### Blockers / Risks
- Public DNS + NPM SSL verification pending
- `VAULTWARDEN_DB_PASSWORD` must stay in `.env` (not committed)
- Vault webhook + Stripe products not created yet

### Links / Commands
- **Resume here:** `documentation/CLOUDIGAN-VAULT-PRODUCT.md`
- Infra: `documentation/VAULTWARDEN-DEPLOYMENT.md`
- State: `TASK-STATE.md` → Vaultwarden HA plan + paused section
- Verify: `curl -sS https://vault.cloudigan.com/alive` (after DNS)
- SSH: `ssh vaultwarden-blue` / `ssh vaultwarden-green`

## 2026-06-12

_Rolled from NOTES-TODAY.md_

---
date: 2026-06-12
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Scrypted Reolink CX810 integration + NVR recording
- PM2 / decommission cleanup (ldc-tools, quantshift, factorpoint legacy)

### Discoveries / Notes
- Three Reolink CX810 on `10.92.0.184` / `.189` / `.190`; ports HTTP 80, RTSP 554, ONVIF 8000, RTMP 1935 (9000 Baichuan still open)
- `@apocaliss92/scrypted-reolink-native` works before RTSP/ONVIF enabled; add cameras with **unique `uid` = IP** when same model (otherwise one device overwrites)
- NVR mixin id **31** + object detection **35** on cams 60–62; **3/3** licenses; recordings on TrueNAS NFS `/mnt/recordings` (~227 GB after ~1 day continuous)
- Stale Nest dirs (`scrypted-27`–`30`) removed; ~27 GB freed; slow NFS delete on `.events` metadata
- Garage main recording folder tiny vs remote/adaptive — snapshots OK; verify timeline naming/aim
- ldc-tools (CT133/135) + quantshift (CT137/138) stopped; factorpoint `registry-gateway` + `OHIO_SOS_*` env removed

### Decisions to Promote
- Reolink Native plugin + uid-per-IP for multi-CX810 in Scrypted (see DECISIONS D-HOMELAB-010)

### Blockers / Risks
- `cloudigan.com` AD conditional forward on Technitium still pending (from DNS cutover)
- Reolink admin password has `@` — may break RTSP; alphanumeric recommended
- Continuous NVR ~85 GB/camera/day at 2K — set explicit retention days on 21 TB pool when ready

### Links / Commands
- Scrypted: https://scrypted.cloudigan.net
- Verify recordings: `ssh scrypted 'df -h /mnt/recordings; du -sh /mnt/recordings/scrypted-6*'`

## 2026-07-03

_Rolled from session (NOTES-TODAY was empty at roll)_

### Focus
- Kimai Entra SSO repair + user onboarding (Abisai, Alexa)
- Personal Ops Center / unified life calendar research

### Discoveries / Notes
- Kimai AADSTS75011: `requestedAuthnContext: true` blocks MFA/FIDO → set `false`
- Kimai SAML email mapping must use `$` prefix on claim URI or email validation fails
- Kimai 500: Symfony cache owned by root after `rm -rf var/cache` — rebuild as `www-data`
- Alexa exists (id 5, disabled→activated); Abisai not created until mapping fix
- POC calendar: self-hosted read-only MVP; ICS fallback for Thrive/Bethel/congregation without API

### Blockers / Risks
- DNS AD forward still pending
- Abisai/Alexa SSO re-test needed
- Large homelab-nexus git diff still uncommitted (DNS/HHV/mail)

### Links / Commands
- Kimai: https://time.cloudigan.net
- DNS: `dig @10.92.3.11 _ldap._tcp.cloudigan.com SRV +short`

## 2026-07-28

_Rolled from NOTES-TODAY.md_

---
date: 2026-07-28
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- End-day closeout after Proxmox 3-node / TrueNAS / Scrypted / 10G fabric planning session

### Discoveries / Notes
- Scrypted NVR is continuous-only (no motion-only mode); Retention Period = 14 days set; prune of older footage started on CT180
- Interim datastore: TrueNAS `media-pool/vms/proxmox` (4T) → PVE `truenas-proxmox` via `10.92.3.200`
- `truenas-backups` fixed on `10.92.3.200` (was inactive on `.5.200`)
- NFS ~104 MB/s via gateway today — need vlan922 host IPs + SX3016F for real 10G path
- SG3428XMP: 4× SFP+ full (TN LACP 25–26, prox1 dual 27–28). Buy **SX3016F** + **2× X520-DA2** (LinksTek 82599ES clone OK). Keep DAC/SFP+
- Hybrid cluster: NFS for HA/migrate guests only; pin Plex/Scrypted to prox1; no Ceph on PERC; rename prox→prox1 before pvecm

### Decisions to Promote
- D-HOMELAB-012: hybrid NFS + local; SX3016F + X520-DA2 (promoted to DECISIONS.md)

### Blockers / Risks
- Waiting on SX3016F + NICs for equal 10G peers (cluster join can still start on 1G)
- TrueNAS remains SPOF for NFS-backed guests until rebuild/evacuate

### Links / Commands
- Plan: `.cursor/plans/3-node_cluster_architecture_*.plan.md`
- `pvesm status` → `truenas-proxmox`, `truenas-backups`

## 2026-08-13

_Rolled from NOTES-TODAY.md_

---
date: 2026-07-28
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- ✅ App audit + reusable `deploy-bluegreen-app.yml` → Quote Builder provisioned

### Discoveries / Notes
- Handoff gate: provision 10.92.3.0/24 → MCP APPS → drop `.no-auto-deploy`
- Keep/retire (no destroy): LDC, QuantShift, chapter-hub-dev; keep TheoShift/FactorPoint/Chapter Hub/API
- Cursor MCP runs `Cloudy-Work/shared/mcp-servers/homelab-blue-green-mcp/server.js` — sync both copies
- Quote Builder: CT200/201, LIVE=blue, STANDBY=green; `deploy_to_standby` smoke OK
- Operator still: NPM `quotes.cloudigan.net` → `10.92.3.33:80`

### Decisions to Promote
- Reusable BG Ansible + Technitium DNS as standard for new Node/Next.js apps

### Blockers / Risks
- Technitium still default admin (use API token)
- Containers lack GitHub deploy key for HTTPS/SSH pull — stage with `.git` or add deploy key

### Links / Commands
- `cd ansible && ansible-playbook playbooks/deploy-bluegreen-app.yml -e @group_vars/cloudigan_quote_builder_deploy.yml`
- Doc: `documentation/BLUEGREEN-APP-ANSIBLE.md`

## 2026-09-13

_Rolled from NOTES-TODAY.md_

---
date: 2026-09-13
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Close out Omada CT142 recovery + client-ops notes from 2026-09-08 through 2026-09-10

### Discoveries / Notes
- Omada CT142 wedged 2026-09-08: Java in disk wait, RAM 1.9/2 GB, UI ports 8043/8088 down, `omada.cloudigan.net` 502. Wi-Fi APs kept serving (this Mac 802.11ax ch40, -45 dBm, 0% loss).
- Recovered CT142: reboot + RAM 2 GB → 8 GB. `tpeap` active; 8043/8088/8843 listening; UI 200 via direct and NPM. Mongo failed once on first start (OOM) then recovered. Disk 30% used.
- geo-sapnfs-p001 (2026-09-09): hung Ninja remote PTY (~3h on `systemctl status | less`); killed PTY, restarted ninjarmm-agent-9.0.4181-1. Removed leftover Kaseya after failed uninstall/reinstall. Installed `lsof` to stop Ninja MONWRK errors.
- SSH recovery (2026-09-10) from ak1-ansible: root key on GEO-PGSQL-P001, GEO-UB-P001, AK1-UB-P002, GEO-SAP-DB-T001. Still no SSH: ak1-ifw03-p001 (no route), GEO-ETL-D001 (no route), ak1-rtr03-p001 / DGG-UB-P002 / GEO-KALI-P001 (vault pw fail; need console or owner passwords).
- GEO-SAP-DB-T001 root FS was 100% full: deleted 519 old SBX archived redo logs (mtime +7d), unused kernel; 22% / 79G free. Archive dest still `/oracle/SBX/oraarch` on root (saparch LV 147G unused).
- joel-win11 VM105 @ 10.92.4.3: DNS/Netbox/vzdump done 2026-09-02; OS install still needs Proxmox console + VirtIO SCSI, then static IP.

### Decisions to Promote
- D-HOMELAB-015: Omada CT142 stays at 8 GB RAM (2 GB wedges controller; 4 GB still ~full after start)

### Blockers / Risks
- Five client VMs still unreachable over SSH
- joel-win11 OS install unfinished
- Omada DHCP cutover to Technitium still pending (D-HOMELAB-013)

### Links / Commands
- Omada UI: https://omada.cloudigan.net (CT142 10.92.0.34:8043)
- `ssh prox 'pct status 142; pct config 142 | grep memory'`
---

## 2026-09-22

_Rolled from NOTES-TODAY.md_

---
date: 2026-09-22
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- 

### Discoveries / Notes
- prox1 was up; Tailscale accept-routes blackholed LAN. Nodes advertise 10.92.0.0/16 but `--accept-routes=false` plus ip rule pref 5190.
- prox2 (R720xd `78F8XV1`) drained to prox1, X520 installed, cluster 3/3. Guests still on prox1.
- SX3016F adopted `10.92.0.4`, jumbo 9216. Uplink 3428:25. prox2 ports 7/8 trunked. Do not adopt Omada gateway.
- prox2 `10.92.2.6/24` on `enp4s0f0.922` pings and NFS-mounts TrueNAS `10.92.2.200`. storage.cfg still `.3.200`.
- Next: LACP TrueNAS onto SX3016F (spare DAC first, then move 3428 port 26). Then `.2.5`/`.2.7` and remount.

### Decisions to Promote
- 

### Blockers / Risks
- 

### Links / Commands
- 

## 2026-09-25

_Rolled from NOTES-TODAY.md_

---
date: 2026-09-25
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Finish the SX3016F cutover and balance guests across prox1, prox2, and prox3

### Discoveries / Notes
- TrueNAS LAG `truenas` is on SX3016F ports 3 and 4 (native 920, tagged 922–925). Management `10.92.0.3` stayed on the 1G NIC.
- prox3 X520: `enp4s0f0` storage `10.92.2.7`, `enp4s0f1` guest trunk `10.92.3.207` plus 924/925.
- Guests balanced. Pairs stay split. CT131 left on prox1 so the replica would not promote. GPU CTs stayed on prox1.
- Bind-mount CTs migrate only after `mp0` is removed and restored. `/mnt/pve/theoshift-uploads` and `tip-uploads` exist on prox3.
- Jellyfin 10.11.11 needs Intro Skipper `10.11/v1.10.11.24`, not the 12.0 build. Plugin loaded. Analysis is still a dashboard task.

### Decisions to Promote
- D-HOMELAB-017 — host 10G ports stay unbonded; TrueNAS stays LACP

### Blockers / Risks
- prox1 has no `10.92.2.5`. Cluster NFS is still `10.92.3.200`.
- prox2 guest VLANs are still on 1G `eno1`.
- Stopping CT131 can promote CT151.

### Links / Commands
- Jellyfin plugins: `https://jellyfin.cloudigan.net/web/#/dashboard/plugins`
- Scheduled tasks: `https://jellyfin.cloudigan.net/web/#/dashboard/scheduledtasks`

## 2026-10-04

_Rolled from NOTES-TODAY.md_

---
date: 2026-09-30
purpose: Scratchpad for today's discoveries (promote on /end-day)
---

## Today

### Focus
- Move cluster NFS from `10.92.3.200` onto vlan 922

### Discoveries / Notes
- prox1 `vmbr0922` now has `10.92.2.5/24`. Jumbo ping to `10.92.2.200` works.
- NFSv4 reuses an existing session, so each node had to drop every NFS mount before the new server IP took effect. Guests were moved off, then back.
- `storage.cfg` `server` is fixed in the API; edited the file directly to `10.92.2.200`.
- A vzdump of CT132 had been rsyncing since 09:27 and was not growing. Killed it and removed the partial dump so theoshift-green could move.
- prox2 guest bridges `vmbr0923/924/925` moved from `eno1` to `enp4s0f1` (SX3016F `1/0/7`, port description `prox2-f0`, PVID 920). VLAN 923–925 answered ARP on that port before the move. CT139 `10.92.3.32` and gateways `10.92.3.1`, `10.92.4.1`, `10.92.5.1` answered after. Management stayed on `eno1`. 

### Decisions to Promote
- 

### Blockers / Risks
- 

### Links / Commands
- 
