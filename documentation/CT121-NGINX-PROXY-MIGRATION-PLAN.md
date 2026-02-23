# CT121 (nginx-proxy) Migration Plan

**Scheduled:** Later tonight (2026-02-23)  
**Migration:** CT121 → CT142  
**Purpose:** Move Nginx Proxy Manager to correct Network Services range (140-149)

---

## Pre-Migration Checklist

⚠️ **CRITICAL: This is the reverse proxy for ALL services**
- All 32 proxy hosts route through this container
- Downtime affects access to all web UIs
- Recommended migration window: Low-traffic period

---

## Migration Steps

### 1. Pre-Migration Safety
```bash
# Create ZFS snapshot
ssh prox "zfs snapshot hdd-pool/subvol-121-disk-0@pre-ctid-migration-$(date +%Y%m%d-%H%M%S)"

# Verify snapshot created
ssh prox "zfs list -t snapshot | grep subvol-121"

# Backup NPM database (already automated daily, but extra safety)
ssh prox "sqlite3 /hdd-pool/subvol-121-disk-0/data/database.sqlite '.backup /tmp/npm-emergency-backup.sqlite'"
```

### 2. Stop Container
```bash
ssh prox "pct stop 121"
ssh prox "pct status 121"  # Verify stopped
```

### 3. Rename ZFS Volume
```bash
ssh prox "zfs rename hdd-pool/subvol-121-disk-0 hdd-pool/subvol-142-disk-0"
ssh prox "zfs list | grep subvol-142"  # Verify renamed
```

### 4. Rename Config File
```bash
ssh prox "sed 's/subvol-121-disk-0/subvol-142-disk-0/g' /etc/pve/lxc/121.conf > /etc/pve/lxc/142.conf"
ssh prox "cat /etc/pve/lxc/142.conf | grep rootfs"  # Verify rootfs updated
ssh prox "rm /etc/pve/lxc/121.conf"
```

### 5. Start Container
```bash
ssh prox "pct start 142"
ssh prox "pct list | grep 142"  # Verify running
```

### 6. Verify NPM Service
```bash
# Wait for NPM to start
sleep 10

# Check NPM admin UI
curl -I http://10.92.3.3:81

# Test a few proxy hosts
curl -I https://grafana.cloudigan.net
curl -I https://netbox.cloudigan.net
curl -I https://theoshift.com
```

### 7. Update Infrastructure
```bash
# Update Netbox VM record (via API)
curl -s -X PATCH -H "Authorization: Token a7b0a8384c7c8c47f599d43731f1aa59f138c809" \
  -H "Content-Type: application/json" \
  -d '{"comments":"Proxmox VMID: 142\nIP: 10.92.3.3\nReverse proxy with SSL management\nMigrated from CT121 on 2026-02-23"}' \
  "http://10.92.3.18/api/virtualization/virtual-machines/[NETBOX_VM_ID]/"

# Update documentation
# - infrastructure-spec.md: CT121 → CT142
# - APP-MAP.md: Update NPM section if needed
```

---

## Verification Checklist

After migration, verify:

- [ ] NPM admin UI accessible: http://10.92.3.3:81
- [ ] All 32 proxy hosts responding
- [ ] SSL certificates working
- [ ] No errors in NPM logs
- [ ] Netbox updated
- [ ] Documentation updated
- [ ] Git commit and push

---

## Rollback Plan

If issues occur:

1. **Stop CT142:**
   ```bash
   ssh prox "pct stop 142"
   ```

2. **Restore from ZFS snapshot:**
   ```bash
   ssh prox "zfs rollback hdd-pool/subvol-142-disk-0@pre-ctid-migration-YYYYMMDD-HHMMSS"
   ssh prox "zfs rename hdd-pool/subvol-142-disk-0 hdd-pool/subvol-121-disk-0"
   ```

3. **Restore config:**
   ```bash
   ssh prox "sed 's/subvol-142-disk-0/subvol-121-disk-0/g' /etc/pve/lxc/142.conf > /etc/pve/lxc/121.conf"
   ssh prox "rm /etc/pve/lxc/142.conf"
   ```

4. **Start CT121:**
   ```bash
   ssh prox "pct start 121"
   ```

---

## Expected Downtime

**Estimated:** 1-2 minutes  
**Impact:** All web UIs inaccessible during migration  
**Mitigation:** Perform during low-traffic window

---

## Post-Migration

**Remaining misaligned containers after this migration:** 0  
**All containers will be in correct ID ranges** ✅

---

**Created:** 2026-02-23  
**Status:** Scheduled for later tonight
