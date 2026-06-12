# Task State - homelab-nexus

**Last updated:** 2026-06-12 (mid-day)

---

## Current Task
**DNS post-cutover + Scrypted Reolink NVR** — DNS AD forward still pending; Reolink recording live

### What I'm doing right now
Reolink CX810 ×3 in Scrypted (Driveway/Garage/Front Porch) with NVR recording to TrueNAS. DNS stack live; still need **`cloudigan.com` → dc-01** conditional forward for AD clients.

### Recent completions
- ✅ **Reolink CX810 → Scrypted** — `@apocaliss92/scrypted-reolink-native`, cams 60–62, snapshots OK
- ✅ **Scrypted NVR** — mixin enabled 3/3; recordings on `/mnt/recordings` (TrueNAS NFS)
- ✅ **Stale Nest recordings removed** — old `scrypted-27`–`30` dirs cleared
- ✅ **PM2 audit fixes** — cloudigan-api, cloudigan-mail, factorpoint; `pm2 save` + startup on app CTs
- ✅ **Decommissioned** — ldc-tools + quantshift CTs stopped; factorpoint `registry-gateway` + `OHIO_SOS_*` env removed
- ✅ **DNS redundancy stack** — Technitium + dual AdGuard, zones, DHCP phase 6 cutover (2026-06-08)

### Next steps
1. **Technitium conditional forward:** `cloudigan.com` → `10.92.0.10` (dc-01)
2. **Scrypted tuning (optional):** Reolink motion zones; explicit NVR retention days; verify Garage timeline
3. **Set Technitium production passwords** on dns + dns-2
4. **Client server identity** — AD users → local or Entra
5. **DNS phase 7** — provisioning scripts → Technitium API
6. **Git** — commit DNS ansible/docs chunk; HHV/mail still paused

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP** — Stripe/public launch
- **TIP Generator Phase 1**

---

## Known Issues

- **`cloudigan.com` AD DNS not on new stack** — AdGuard/Technitium return public Wix DNS; `_ldap._tcp.cloudigan.com` SRV empty → domain logons may fail until conditional forward added
- **Technitium auth reset** — both servers at `admin`/`admin` + `corya`/`TempCory-DNS-2026`; user must set production passwords and skip 2FA until stable
- **dc-01 must stay up** — AD zone `cloudigan.com`, domain-joined machines; do not decommission for 2+ weeks
- **NPM cert #30 expired** — tautulli NXDOMAIN blocks renewal (D-HOMELAB-007)
- **cloudigan-mail GitHub** — not pushed
- **Authentik Embedded Outpost** — cosmetic unhealthy

---

## Uncommitted work (end-day)

- **Ready to commit (focused chunks):** `ansible/` DNS stack, `scripts/dns/*`, `documentation/DNS-REDUNDANCY-MIGRATION.md`, `STEPS-2-4.md`, `.env.example`
- **Intentionally uncommitted:** `files/Logos/`, `.cursor/`, `.windsurf/`
- **Not committed tonight** — large mixed diff spanning DNS + HHV + mail + monitoring; commit DNS slice first after forwarder verify

---

## Exact Next Command

```bash
# Verify client DNS after DHCP cutover (from any LAN machine)
nslookup n8n.cloudigan.net
nslookup theoshift.com

# Confirm AD gap (should be empty until forward added)
dig @10.92.3.11 _ldap._tcp.cloudigan.com SRV +short

# After adding cloudigan.com forward on Technitium — should return dc-01 SRV
```

**Next action:** Technitium → conditional forward `cloudigan.com` → `10.92.0.10`; optional Scrypted NVR retention + Reolink motion zones.

---

## Infrastructure quick reference

| Service | Primary | Standby | UI hostname |
|---------|---------|---------|-------------|
| AdGuard (DHCP DNS) | `10.92.3.11` | `10.92.3.204` | dnsfilter / dnsfilter-2 |
| Technitium | `10.92.3.10` | `10.92.3.203` | dns / dns-2 |
| AD DNS (legacy) | `10.92.0.10` dc-01 | — | `cloudigan.com` zone |

**DHCP DNS:** `#1 10.92.3.11`, `#2 10.92.3.204`
