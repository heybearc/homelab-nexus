# DNS redundancy — steps 2–4

**UI hostnames (NPM → `10.92.3.3`):**

| Role | Hostname | NPM upstream |
|------|----------|--------------|
| Technitium primary | `dns.cloudigan.net` | `10.92.3.10:5380` |
| Technitium standby | `dns-2.cloudigan.net` | `10.92.3.203:5380` |
| AdGuard primary | `dnsfilter.cloudigan.net` | `10.92.3.11:3000` |
| AdGuard standby | `dnsfilter-2.cloudigan.net` | `10.92.3.204:3000` |

**DHCP / port 53** uses real service IPs: `10.92.3.11` + `10.92.3.204`.

---

## Step 2 — Technitium zones + secondary AXFR ✅ (done)

Primary (`10.92.3.10`) holds:

- `cloudigan.net` (95 A records from dc-01)
- `theoshift.com`, `quantshift.io`, `factorpoint.io`, `helpfulhirschventures.com`, `ldctools.com` (lab A → `10.92.3.3`)

Standby (`dns-2` / `10.92.3.203`) has **Secondary** zones for all of the above, synced via AXFR.

**Not migrated (stay on dc-01):** `cloudigan.com` (AD), reverse zones, dead bnitoolkit CNAMEs.

**Verify:**

```bash
dig @10.92.3.10  n8n.cloudigan.net +short    # → 10.92.3.79
dig @10.92.3.203 n8n.cloudigan.net +short    # → same (secondary)
dig @10.92.3.10  dns.cloudigan.net +short    # → 10.92.3.3
```

**Re-run import / resync if needed:**

```bash
./scripts/dns/setup-technitium-zone.sh
# Prompts for Technitium password, or set TECHNITIUM_API_TOKEN for automation
```

**TrueNAS alias persistence** (if `.203`/`.204` disappear after reboot):

```bash
ssh truenas 'midclt call interface.update vlan923 '"'"'{
  "aliases": [
    {"type":"INET","address":"10.92.3.200","netmask":24},
    {"type":"INET","address":"10.92.3.203","netmask":24},
    {"type":"INET","address":"10.92.3.204","netmask":24}
  ]
}'"'"'
ssh truenas 'midclt call interface.commit && midclt call interface.checkin'
```

**Fixes applied during setup:**

- Primary must listen on **IPv4 TCP 53** for AXFR (`dnsServerLocalEndPoints=10.92.3.10:53,0.0.0.0:53` + container restart).
- AXFR ACL must include **`10.92.3.200`** (TrueNAS host IP used for outbound Docker traffic) and `10.92.3.203`.

---

## Step 3 — AdGuard primary upstream → Technitium

Open **https://dnsfilter.cloudigan.net** (or `http://10.92.3.11:3000`).

1. **Settings → DNS settings → Upstream DNS servers**
   - Remove `10.92.0.10` (dc-01) if still present.
   - Set upstream to **only** internal Technitium:
     - `10.92.3.10` (primary)
     - `10.92.3.203` (dns-2 fallback)
   - **Do not** add public resolvers (1.1.1.1, etc.) — Technitium handles public via its own forwarders (same pattern as dc-01).

2. **Private reverse DNS / local domains** — leave `cloudigan.net` resolution to upstream Technitium (no rewrites needed for internal A records once upstream is Technitium).

3. **Test** (from a machine using `10.92.3.11` as resolver):

```bash
dig @10.92.3.11 n8n.cloudigan.net +short
# expect 10.92.3.79 from Technitium, not dc-01
```

**Standby** (`dnsfilter-2.cloudigan.net` / `10.92.3.204`) is already configured with upstream `10.92.3.203` + `10.92.3.10`.

---

## Step 4 — Sync blocklists + DHCP cutover

### 4a. Sync AdGuard blocklists to standby

On **primary** (`dnsfilter.cloudigan.net`):

1. **Filters → DNS blocklists** — note enabled lists (URLs).
2. **Settings → General** → **Export settings** (downloads YAML).

On **standby** (`dnsfilter-2.cloudigan.net`):

1. **Settings → General** → **Import settings** — upload the export from primary.
2. Re-enter admin password if prompted.
3. Confirm blocklists match under **Filters**.

Or manually copy the same blocklist URLs on standby.

### 4b. DHCP — phased cutover (Omada)

**Phase 5 — add secondary only (no client impact):**

| DHCP DNS | Value |
|----------|-------|
| DNS #1 | *(leave current — likely `10.92.0.10` or `10.92.3.11`)* |
| DNS #2 | `10.92.3.204` |

**Phase 6 — full cutover:**

| DHCP DNS | Value |
|----------|-------|
| DNS #1 | `10.92.3.11` (AdGuard primary) |
| DNS #2 | `10.92.3.204` (AdGuard standby) |

Remove dc-01 (`10.92.0.10`) from DHCP DNS.

**Test after cutover:**

```bash
# Renew DHCP on a test client, then:
nslookup n8n.cloudigan.net
nslookup google.com
```

**Rollback:**

```bash
./scripts/dns/rollback-dns-cutover.sh
# Then restore Omada DNS #1 → 10.92.0.10 (or prior values)
```

---

## Optional next (step 7)

Point `dns-add-record.sh` / provisioning at Technitium API (`./scripts/dns/technitium-api.sh`) instead of dc-01. Do **not** retire dc-01 until this stack is stable 2+ weeks.
