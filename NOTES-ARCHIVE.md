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
