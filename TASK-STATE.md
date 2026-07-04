# Task State - homelab-nexus

**Last updated:** 2026-07-03 (end-day)

---

## Current Task
**DNS post-cutover** — AD conditional forward still blocking domain-joined Windows; Kimai SSO **fixed on server** (verify Abisai/Alexa login)

### What I'm doing right now
Technitium conditional forward `cloudigan.com` → `10.92.0.10` still pending. Kimai Entra SAML repaired on CT111 (authn context, email `$` mapping, cache perms). Personal Ops Center / unified calendar **designed** — build backlog, not started.

### Recent completions
- ✅ **Kimai Entra SSO** — `requestedAuthnContext: false`, email SAML `$` prefix, cache 500 fixed; Alexa activated; repo scripts updated (2026-06-24 / 2026-07-03)
- ✅ **Personal Ops Center research** — read-only MVP spec (Next.js/Prisma/Graph/Google/ICS); Thrive/Bethel/JWPub ICS fallbacks (2026-07-03)
- ✅ **Reolink CX810 → Scrypted + NVR** — Native plugin, cams 60–62, TrueNAS NFS (2026-06-12)
- ✅ **DNS redundancy + DHCP phase 6** — Technitium + dual AdGuard cutover (2026-06-08)
- ✅ **PM2 audit + decommission** — ldc-tools/quantshift stopped; factorpoint legacy env cleaned (2026-06-12)

### Next steps
1. **Technitium conditional forward:** `cloudigan.com` → `10.92.0.10` — `dig @10.92.3.11 _ldap._tcp.cloudigan.com SRV +short`
2. **Kimai:** have Abisai + Alexa retry Microsoft login at https://time.cloudigan.net
3. **Set Technitium production passwords** on dns + dns-2
4. **Git** — commit DNS ansible/docs chunk (large diff still uncommitted)
5. **POC calendar (backlog):** scaffold read-only MVP when ready — Graph + Google + ICS first

### Paused (unchanged)
- **HHV DNS/NPM + Next.js app**
- **Cloudigan Mail Gateway** — NPM + GitHub push
- **Cloudigan Vault MSP**
- **TIP Generator Phase 1**

---

## Known Issues

- **`cloudigan.com` AD DNS not on new stack** — `_ldap._tcp.cloudigan.com` SRV empty via AdGuard until conditional forward added
- **Technitium auth** — `admin`/`admin`; set production passwords
- **Kimai Abisai** — user not created until email mapping fix; re-test SSO
- **Scrypted NVR growth** — ~85 GB/camera/day continuous 2K; set retention when ready
- **NPM cert #30 expired** — tautulli NXDOMAIN (D-HOMELAB-007)
- **cloudigan-mail GitHub** — not pushed
- **dc-01** — keep up 2+ weeks during identity migration
- **TASK-STATE was stale ~3 weeks** — refreshed 2026-07-03

---

## Uncommitted work

- **Large diff:** ansible DNS stack, HHV/mail/monitoring — commit DNS slice after forwarder verify
- **Kimai scripts:** `configure-kimai-entra-saml.sh` etc. — committing with end-day context
- **Intentionally uncommitted:** `files/Logos/`, `.cursor/`, `.windsurf/`
- **`.cloudy-work/PLAN.md`** — updated locally (submodule)

---

## Exact Next Command

```bash
dig @10.92.3.11 _ldap._tcp.cloudigan.com SRV +short
# empty → Technitium UI: conditional forward cloudigan.com → 10.92.0.10
```

**Tomorrow first action:** DNS forward verify, or Kimai SSO re-test for Abisai/Alexa.

---

## Infrastructure quick reference

| Service | Primary | Standby |
|---------|---------|---------|
| AdGuard (DHCP DNS) | `10.92.3.11` | `10.92.3.204` |
| Technitium | `10.92.3.10` | `10.92.3.203` |
| Kimai | CT111 `10.92.3.76` | https://time.cloudigan.net |
| Scrypted NVR | CT180 `10.92.3.15` | recordings → TrueNAS NFS |
| AD DNS (legacy) | dc-01 `10.92.0.10` | `cloudigan.com` zone |

**DHCP DNS:** `#1 10.92.3.11`, `#2 10.92.3.204`
