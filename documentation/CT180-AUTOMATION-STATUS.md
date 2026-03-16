# CT180 Scrypted - Automation Backfill Status

**Date:** 2026-03-16  
**Container:** CT180 (scrypted)  
**IP:** 10.92.3.15/24

---

## ✅ Completed Automation Components

### 1. DNS Configuration
- **Status:** ✅ Complete
- **Record:** scrypted.cloudigan.net → 10.92.3.3 (NPM)
- **Location:** DC-01 (Windows AD DNS)
- **Verification:** `nslookup scrypted.cloudigan.net 10.92.0.10`
- **Script:** `/scripts/dns/update-dc01-dns.sh`

### 2. Monitoring Agents
- **Status:** ✅ Partial (node_exporter installed, promtail failed)
- **node_exporter:** Running on port 9100
- **promtail:** Installation failed (missing unzip dependency)
- **Metrics endpoint:** http://10.92.3.15:9100/metrics
- **Script:** `/scripts/provisioning/install-monitoring.sh`

**Fix for promtail:**
```bash
ssh root@10.92.3.15
apt-get install -y unzip
# Re-run promtail installation manually
```

### 3. Proxmox Backup Schedule
- **Status:** ✅ Complete (with warning)
- **Schedule:** Daily at 02:00
- **Storage:** local
- **Retention:** keep-last=7, keep-weekly=4, keep-monthly=3
- **Mode:** Snapshot with zstd compression
- **Note:** Warning about starttime/schedule parameter conflict (non-critical)
- **Script:** `/scripts/provisioning/configure-backup.sh`

---

### 4. Netbox IPAM Registration
- **Status:** ✅ Complete (Auto-sync)
- **VM ID:** 32
- **Registered by:** Proxmox→Netbox sync script (CT150)
- **Details:** Auto-discovered with VMID 180, IP 10.92.3.15
- **Tagged:** needs-review (standard for auto-discovered containers)

### 5. NPM Reverse Proxy
- **Status:** ✅ Complete
- **Proxy ID:** 81
- **Domain:** scrypted.cloudigan.net
- **Backend:** 10.92.3.15:10443 (HTTPS)
- **SSL Certificate:** Let's Encrypt (ID: 64)
- **Access:** https://scrypted.cloudigan.net
- **Method:** Created via NPM database, loaded after container reboot

---

## 📊 Automation Compliance Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Container Creation | ✅ Complete | Used official Scrypted installer |
| Network Configuration | ✅ Complete | Static IP on vmbr0923 |
| DNS (DC-01) | ✅ Complete | scrypted.cloudigan.net → 10.92.3.3 (NPM) |
| Netbox IPAM | ✅ Complete | Auto-registered via sync (VM ID 32) |
| NPM Reverse Proxy | ✅ Complete | Proxy ID 81, SSL enabled |
| Monitoring (node_exporter) | ✅ Complete | Port 9100 |
| Monitoring (promtail) | ⚠️ Partial | Needs unzip dependency |
| Proxmox Backup | ✅ Complete | Daily at 02:00 |

**Overall Compliance:** 7/8 components complete (87.5%)

---

## 🎯 Next Actions

### Immediate (Application Setup)
1. Access Scrypted: https://scrypted.cloudigan.net
2. Change default root password (currently: `scrypted`)
3. Configure Google Nest camera integration
4. Mount TrueNAS NFS for recordings storage

### Infrastructure (Optional Cleanup)
1. Fix promtail installation (install unzip, re-run monitoring script)
2. Remove "needs-review" tag from Netbox VM entry
3. Verify all monitoring metrics are being collected

### Credentials Updated in `.env`
- ✅ Netbox URL: http://10.92.3.18
- ✅ Netbox Token: a7b0a8384c7c8c47f599d43731f1aa59f138c809
- ✅ NPM URL: http://10.92.3.3:81
- ✅ NPM Email: admin@cloudigan.com
- ✅ NPM Password: [configured]

---

## 🔧 Quick Reference Commands

**Check DNS:**
```bash
nslookup scrypted.cloudigan.net 10.92.0.10
```

**Check monitoring:**
```bash
curl http://10.92.3.15:9100/metrics | head
```

**Check backup schedule:**
```bash
ssh root@10.92.0.5 "pvesh get /cluster/backup"
```

**Access Scrypted:**
```bash
ssh root@10.92.3.15
# Or via web: https://10.92.3.15:10443/
```

---

## 📝 Related Documentation

- Full deployment details: `CT180-SCRYPTED-DEPLOYMENT.md`
- DNS management: `dns-management-for-renames.md`
- Provisioning pipeline: `/scripts/provisioning/README.md`
- Container naming standard: `container-naming-standard.md`
