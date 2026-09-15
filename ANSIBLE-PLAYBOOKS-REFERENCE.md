# Ansible Playbooks Quick Reference

**⚠️ IMPORTANT: We have a dedicated ansible-playbooks repository!**

---

## 📍 Location

**Local:** `/Users/cory/Projects/ansible-playbooks`  
**GitHub:** https://github.com/heybearc/ansible-playbooks  
**Semaphore UI:** https://ansible.cloudigan.net

**Storage (D-HOMELAB-014):** All new LXCs and VMs go on TrueNAS NFS `truenas-proxmox`. Shared playbooks assert this.

---

## 🚀 Deploy New Container (Most Common Task)

### Via Semaphore UI (Recommended)
1. Go to https://ansible.cloudigan.net
2. Click **Task Templates**
3. Find **"Deploy Proxmox Container"**
4. Click **Run**
5. Enter variables:
   - `container_name`: omada-controller
   - `container_function`: network
   - `container_ip`: 10.92.3.16
   - `container_domain`: omada.cloudigan.net
   - `container_port`: 8043

### Via Command Line
```bash
cd /Users/cory/Projects/ansible-playbooks

ansible-playbook playbooks/deploy-proxmox-container.yml \
  -e "container_name=omada-controller" \
  -e "container_function=network" \
  -e "container_ip=10.92.3.16" \
  -e "container_domain=omada.cloudigan.net" \
  -e "container_port=8043"
```

---

## HHV blue-green (helpfulhirschventures.com)

```bash
cd /Users/cory/Projects/homelab-nexus
source .env   # NETBOX_TOKEN; optional HHV_DB_PASSWORD
cd ansible && ansible-playbook playbooks/deploy-hhv-containers.yml
```

See **documentation/HHV-DEPLOYMENT.md**.

---

## Windows 11 workstation (justin-win11)

```bash
cd /Users/cory/Projects/homelab-nexus
set -a && source .env && set +a
cd ansible && ansible-playbook playbooks/deploy-windows11-vm.yml
```

Creates VM105 on VLAN 924 (`10.92.4.3`) on **TrueNAS** `truenas-proxmox`, binds the Netbox IP, and adds Technitium `justin-win11.cloudigan.net`. OS install is via Proxmox console.

See **documentation/WINDOWS11-JUSTIN-DEPLOYMENT.md**.

---

## Jellyfin media LXC

```bash
cd /Users/cory/Projects/homelab-nexus
set -a && source .env && set +a
# TECHNITIUM_API_TOKEN required for jellyfin.cloudigan.net A → NPM
cd ansible && ansible-playbook playbooks/deploy-jellyfin.yml
```

See **documentation/JELLYFIN-DEPLOYMENT.md**.

---

## Ops Hub stack (ops.cloudigan.net)

```bash
cd /Users/cory/Projects/homelab-nexus
set -a && source .env && set +a
cd ansible && ansible-playbook playbooks/deploy-ops-stack.yml
```

Registers CT202 in Netbox, Technitium A records (`ops` + `push` → NPM), and NPM proxies.  
See **documentation/OPS-HUB-DEPLOYMENT.md**.

---

## DNS — Technitium authoritative (D-HOMELAB-013)

```bash
cd /Users/cory/Projects/homelab-nexus
set -a && source .env && set +a   # TECHNITIUM_API_TOKEN
./scripts/provisioning/dns-add-record.sh <host> <ip>
./scripts/dns/sync-dc-a-records-to-technitium.sh   # optional re-sync from dc-01
```

**DHCP must use** `10.92.3.10` + `10.92.3.203` (not AdGuard) — see **documentation/DNS-TECHNITIUM-AUTHORITATIVE.md**.  
Legacy migration notes: **documentation/DNS-REDUNDANCY-MIGRATION.md**.

---

## DNS redundancy (legacy AdGuard-in-DHCP path)

```bash
cd /Users/cory/Projects/homelab-nexus
source .env   # NETBOX_TOKEN (Technitium password is in UI, not .env)
./scripts/dns/migrate-dns-phase.sh 0   # bootstrap dc-01 records first
cd ansible && ansible-playbook playbooks/deploy-dns-stack.yml
./scripts/dns/migrate-dns-phase.sh 2   # import zone from dc-01
```

See **documentation/DNS-REDUNDANCY-MIGRATION.md**. Prefer D-HOMELAB-013 cutover instead.

---

## Monitoring lifecycle (all apps)

**Registry:** `monitoring/apps-registry.yaml`  
**Sync after deploy/decommission:** `./scripts/monitoring/sync-monitoring-stack.sh`  
**Full guide:** **documentation/APP-MONITORING-LIFECYCLE.md**

---

## Vaultwarden HA pair (homelab-nexus wrapper)

Uses **deploy-proxmox-container.yml** twice + Netbox IP plan + Postgres + Docker.

```bash
cd /Users/cory/Projects/homelab-nexus
source .env   # NETBOX_TOKEN, VAULTWARDEN_DB_PASSWORD
cd ansible
ansible-playbook playbooks/deploy-vaultwarden-containers.yml
```

See **documentation/VAULTWARDEN-DEPLOYMENT.md**.

---

## Chapter Hub blue-green (homelab-nexus wrapper)

```bash
cd /Users/cory/Projects/homelab-nexus
source .env   # NETBOX_TOKEN, CHAPTER_HUB_DB_PASSWORD
cd ansible
ansible-playbook playbooks/deploy-chapter-hub-containers.yml
```

See **documentation/CHAPTER-HUB-DEPLOYMENT.md**.

---

## Cloudigan Mail Gateway blue-green (homelab-nexus wrapper)

```bash
cd /Users/cory/Projects/homelab-nexus
source .env   # NETBOX_TOKEN, M365_CLIENT_ID, M365_TENANT_ID, M365_CLIENT_SECRET
cd ansible
ansible-playbook playbooks/deploy-cloudigan-mail-containers.yml
```

See **documentation/CLOUDIGAN-MAIL-DEPLOYMENT.md**.

DNS-only:

```bash
ansible-playbook playbooks/cloudigan-mail-dns.yml
```

---

## 📋 Available Playbooks

### Infrastructure
- **deploy-proxmox-container.yml** - Deploy LXC with full automation
- **deploy-proxmox-vm.yml** - Deploy VM with full automation

### System Management
- **system-update.yml** - Update all packages
- **health-check.yml** - Check system health
- **fix-python-modules.yml** - Bootstrap Python

### Database
- **postgresql-status.yml** - Check DB health
- **postgresql-failover.yml** - Failover to replica
- **configure-postgresql-connections.yml** - Set `max_connections` on CT131 (default 200). See `documentation/POSTGRESQL-CONNECTION-TUNING.md`

### Automation
- **sync-semaphore-templates.yml** - Sync playbooks to Semaphore UI

---

## 🔄 After Adding New Playbooks

**MUST DO:** Sync to Semaphore so they appear in the UI

```bash
# 1. Update metadata in semaphore-auto-template.py
# 2. Push to GitHub
# 3. Run sync:

cd /Users/cory/Projects/ansible-playbooks
ansible-playbook playbooks/sync-semaphore-templates.yml \
  -e "semaphore_password=YOUR_PASSWORD"
```

Or run "Sync Semaphore Templates" task in Semaphore UI.

---

## 📚 Full Documentation

- **ansible-playbooks/README.md** - Quick start guide
- **ansible-playbooks/README-DEPLOYMENT.md** - Detailed examples
- **homelab-nexus/documentation/ANSIBLE-SEMAPHORE-PLAYBOOKS.md** - Semaphore guide

---

## 💡 Remember

1. ✅ **Use Semaphore UI** - Easier, has history, Teams notifications
2. ✅ **Playbooks are in separate repo** - Not in homelab-nexus
3. ✅ **Sync after changes** - Run sync-semaphore-templates.yml
4. ✅ **Full automation** - Netbox, NPM, DNS, monitoring, backups all automatic

---

**Last Updated:** March 29, 2026
