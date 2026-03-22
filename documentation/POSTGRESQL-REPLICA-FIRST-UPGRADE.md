# PostgreSQL Cluster - Replica-First Upgrade Procedure

**Date:** 2026-03-21  
**Purpose:** Zero-downtime upgrade of PostgreSQL cluster for MSP platform  
**Current:** CT131 (primary) + CT151 (replica)  
**Target:** Upgraded resources with zero downtime

---

## Executive Summary

**Upgrade Strategy:** Replica-first promotion with traffic switch

**Process:**
1. Upgrade CT151 (replica) resources
2. Promote CT151 to primary
3. Switch application traffic to CT151
4. Upgrade CT131 (old primary)
5. Demote CT131 to replica
6. Optionally switch back to CT131

**Benefits:**
- ✅ Zero downtime
- ✅ Rollback capability at each step
- ✅ Test upgraded resources before full cutover
- ✅ Maintain replication throughout

**Estimated Time:** 2-3 hours  
**Risk Level:** Low (proven PostgreSQL procedure)

---

## Current State Analysis

### CT131 (Primary)
```
Role: PostgreSQL Primary
IP: 10.92.3.31
Resources: 2 cores, 4GB RAM, 20GB storage
Databases: ldc_tools, theoshift_scheduler, quantshift, bni_toolkit, netbox
Connections: ~10-20 active
Status: Running, healthy
```

### CT151 (Replica)
```
Role: PostgreSQL Streaming Replica
IP: 10.92.3.32
Resources: 2 cores, 4GB RAM, 20GB storage
Replication: Streaming from CT131
Lag: <1 second
Status: Running, healthy
```

### Application Connections

**Current Connection Strings:**
```
TheoShift: postgresql://postgres@10.92.3.31:5432/theoshift_scheduler
LDC Tools: postgresql://postgres@10.92.3.31:5432/ldc_tools
QuantShift: postgresql://postgres@10.92.3.31:5432/quantshift
BNI Toolkit: postgresql://postgres@10.92.3.31:5432/bni_toolkit
Netbox: postgresql://postgres@10.92.3.31:5432/netbox
```

**Note:** All apps connect directly to CT131 (primary)

---

## Target State

### CT151 (New Primary)
```
Role: PostgreSQL Primary
IP: 10.92.3.32 (unchanged)
Resources: 4 cores, 8GB RAM, 100GB storage
Databases: All (promoted from replica)
Status: Primary, accepting writes
```

### CT131 (New Replica)
```
Role: PostgreSQL Streaming Replica
IP: 10.92.3.31 (unchanged)
Resources: 4 cores, 8GB RAM, 100GB storage
Replication: Streaming from CT151
Status: Replica, read-only
```

---

## Pre-Upgrade Checklist

### 1. Verify Current State
```bash
# Check replication status on primary (CT131)
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"

# Expected output: 1 row showing CT151 connected

# Check replication lag on replica (CT151)
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;'"

# Expected output: <1 second lag
```

### 2. Backup Current Configuration
```bash
# Backup PostgreSQL configuration from CT131
ssh prox "pct exec 131 -- tar -czf /tmp/pg-config-backup.tar.gz /etc/postgresql/17/main/"

# Copy to local machine
scp prox:/tmp/pg-config-backup.tar.gz ~/backups/pg-config-$(date +%Y%m%d).tar.gz

# Backup from CT151
ssh prox "pct exec 151 -- tar -czf /tmp/pg-config-backup.tar.gz /etc/postgresql/17/main/"
scp prox:/tmp/pg-config-backup.tar.gz ~/backups/pg-replica-config-$(date +%Y%m%d).tar.gz
```

### 3. Full Database Backup
```bash
# Run full backup on CT131 (primary)
ssh prox "pct exec 131 -- sudo -u postgres pg_dumpall > /var/backups/postgresql/full-backup-$(date +%Y%m%d-%H%M%S).sql"

# Copy to TrueNAS
ssh prox "pct exec 131 -- cp /var/backups/postgresql/full-backup-*.sql /mnt/truenas-backups/database/"
```

### 4. Document Application Connections
```bash
# List all active connections
ssh prox "pct exec 131 -- sudo -u postgres psql -c \"SELECT datname, usename, application_name, client_addr FROM pg_stat_activity WHERE datname IS NOT NULL;\""

# Save output for reference
```

### 5. Notify Stakeholders
- [ ] Schedule maintenance window (if needed)
- [ ] Notify team of upgrade
- [ ] Prepare rollback plan

---

## Upgrade Procedure

### Phase 1: Upgrade CT151 (Replica) Resources

#### Step 1.1: Stop CT151
```bash
# Stop the replica container
ssh prox "pct stop 151"

# Verify stopped
ssh prox "pct status 151"
```

#### Step 1.2: Resize CT151 Resources
```bash
# Increase CPU cores
ssh prox "pct set 151 -cores 4"

# Increase memory
ssh prox "pct set 151 -memory 8192"

# Increase storage
ssh prox "pct resize 151 rootfs +80G"

# Verify changes
ssh prox "pct config 151 | grep -E 'cores|memory|rootfs'"
```

#### Step 1.3: Start CT151 and Verify Replication
```bash
# Start container
ssh prox "pct start 151"

# Wait for startup
sleep 30

# Verify PostgreSQL is running
ssh prox "pct exec 151 -- systemctl status postgresql"

# Verify replication resumed
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
# Expected: t (true - still in recovery/replica mode)

# Check replication lag
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;'"
# Expected: <1 second
```

#### Step 1.4: Update PostgreSQL Configuration on CT151
```bash
# Update max_connections
ssh prox "pct exec 151 -- bash -c 'echo \"max_connections = 250\" >> /etc/postgresql/17/main/postgresql.conf'"

# Update shared_buffers
ssh prox "pct exec 151 -- bash -c 'echo \"shared_buffers = 2GB\" >> /etc/postgresql/17/main/postgresql.conf'"

# Update effective_cache_size
ssh prox "pct exec 151 -- bash -c 'echo \"effective_cache_size = 6GB\" >> /etc/postgresql/17/main/postgresql.conf'"

# Restart PostgreSQL to apply changes
ssh prox "pct exec 151 -- systemctl restart postgresql"

# Verify replication still working
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
```

---

### Phase 2: Promote CT151 to Primary

#### Step 2.1: Verify Replication is Caught Up
```bash
# Check replication lag (should be 0 or <1 second)
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;'"

# Check WAL receive status
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT status, received_lsn FROM pg_stat_wal_receiver;'"
```

#### Step 2.2: Stop Writes on CT131 (Optional - for zero data loss)
```bash
# Set CT131 to read-only mode
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'ALTER SYSTEM SET default_transaction_read_only = on;'"
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT pg_reload_conf();'"

# Wait for replication to catch up completely
sleep 10

# Verify lag is 0
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;'"
```

#### Step 2.3: Promote CT151 to Primary
```bash
# Promote replica to primary
ssh prox "pct exec 151 -- sudo -u postgres pg_ctl promote -D /var/lib/postgresql/17/main"

# Alternative method:
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT pg_promote();'"

# Wait for promotion to complete
sleep 10

# Verify CT151 is now primary (not in recovery)
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
# Expected: f (false - no longer in recovery)

# Verify can write to CT151
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'CREATE TABLE promotion_test (id int); DROP TABLE promotion_test;'"
# Should succeed without errors
```

---

### Phase 3: Switch Application Traffic to CT151 (Zero-Downtime Blue-Green Flow)

**Strategy:** Restart STANDBY containers first, switch traffic, then restart LIVE containers

**Why This Works:**
- STANDBY containers can restart without affecting users
- HAProxy switches traffic to newly-restarted STANDBY (now pointing to new primary)
- Old LIVE containers (still on old primary) can then restart safely
- Zero user-facing downtime

**Procedure:**

#### Step 3.1: Identify Current LIVE/STANDBY Status
```bash
# Check HAProxy to see which containers are LIVE
ssh prox "pct exec 136 -- cat /etc/haproxy/haproxy.cfg | grep -A 5 'backend theoshift'"
ssh prox "pct exec 136 -- cat /etc/haproxy/haproxy.cfg | grep -A 5 'backend ldctools'"
ssh prox "pct exec 136 -- cat /etc/haproxy/haproxy.cfg | grep -A 5 'backend quantshift'"

# Typical setup (verify before proceeding):
# TheoShift: GREEN (CT132) = LIVE, BLUE (CT134) = STANDBY
# LDC Tools: BLUE (CT133) = LIVE, GREEN (CT135) = STANDBY
# QuantShift: BLUE (CT137) = LIVE, GREEN (CT138) = STANDBY
```

#### Step 3.2: Update and Restart STANDBY Containers (No User Impact)
```bash
# TheoShift BLUE (STANDBY) - CT134
ssh prox "pct exec 134 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/theoshift/.env"
ssh prox "pct exec 134 -- pm2 restart theoshift-blue"
sleep 10
ssh prox "pct exec 134 -- curl -s http://localhost:3001/api/health | grep -i database"
# Verify: Should show connected to 10.92.3.32

# LDC Tools GREEN (STANDBY) - CT135
ssh prox "pct exec 135 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/ldc-tools/.env"
ssh prox "pct exec 135 -- pm2 restart ldctools-green"
sleep 10
ssh prox "pct exec 135 -- curl -s http://localhost:3001/api/health | grep -i database"

# QuantShift GREEN (STANDBY) - CT138
ssh prox "pct exec 138 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/quantshift/.env"
ssh prox "pct exec 138 -- pm2 restart quantshift-green"
sleep 10
ssh prox "pct exec 138 -- curl -s http://localhost:3001/api/health | grep -i database"
```

#### Step 3.3: Switch HAProxy Traffic to STANDBY (Now on New Primary)
```bash
# Use existing blue-green deployment MCP tool or manual HAProxy update

# TheoShift: Switch from GREEN (old primary) to BLUE (new primary)
# This makes BLUE the new LIVE
ssh prox "pct exec 136 -- sed -i 's/server theoshift-green 10.92.3.22:3001 check/server theoshift-green 10.92.3.22:3001 check backup/' /etc/haproxy/haproxy.cfg"
ssh prox "pct exec 136 -- sed -i 's/server theoshift-blue 10.92.3.24:3001 check backup/server theoshift-blue 10.92.3.24:3001 check/' /etc/haproxy/haproxy.cfg"
ssh prox "pct exec 136 -- systemctl reload haproxy"

# LDC Tools: Switch from BLUE (old primary) to GREEN (new primary)
ssh prox "pct exec 136 -- sed -i 's/server ldctools-blue 10.92.3.23:3001 check/server ldctools-blue 10.92.3.23:3001 check backup/' /etc/haproxy/haproxy.cfg"
ssh prox "pct exec 136 -- sed -i 's/server ldctools-green 10.92.3.25:3001 check backup/server ldctools-green 10.92.3.25:3001 check/' /etc/haproxy/haproxy.cfg"
ssh prox "pct exec 136 -- systemctl reload haproxy"

# QuantShift: Switch from BLUE (old primary) to GREEN (new primary)
ssh prox "pct exec 136 -- sed -i 's/server quantshift-blue 10.92.3.27:3001 check/server quantshift-blue 10.92.3.27:3001 check backup/' /etc/haproxy/haproxy.cfg"
ssh prox "pct exec 136 -- sed -i 's/server quantshift-green 10.92.3.28:3001 check backup/server quantshift-green 10.92.3.28:3001 check/' /etc/haproxy/haproxy.cfg"
ssh prox "pct exec 136 -- systemctl reload haproxy"

# Verify traffic switched
curl -s https://theoshift.cloudigan.net/api/health | grep -i database
curl -s https://ldctools.cloudigan.net/api/health | grep -i database
curl -s https://quantshift.cloudigan.net/api/health | grep -i database
```

#### Step 3.4: Update and Restart OLD LIVE Containers (Now STANDBY, No User Impact)
```bash
# TheoShift GREEN (now STANDBY) - CT132
ssh prox "pct exec 132 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/theoshift/.env"
ssh prox "pct exec 132 -- pm2 restart theoshift-green"
sleep 10
ssh prox "pct exec 132 -- curl -s http://localhost:3001/api/health | grep -i database"

# LDC Tools BLUE (now STANDBY) - CT133
ssh prox "pct exec 133 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/ldc-tools/.env"
ssh prox "pct exec 133 -- pm2 restart ldctools-blue"
sleep 10
ssh prox "pct exec 133 -- curl -s http://localhost:3001/api/health | grep -i database"

# QuantShift BLUE (now STANDBY) - CT137
ssh prox "pct exec 137 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/quantshift/.env"
ssh prox "pct exec 137 -- pm2 restart quantshift-blue"
sleep 10
ssh prox "pct exec 137 -- curl -s http://localhost:3001/api/health | grep -i database"
```

#### Step 3.5: Update Non-Blue-Green Applications
```bash
# BNI Toolkit (CT119) - Single instance, brief restart
ssh prox "pct exec 119 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/bni-toolkit/.env"
ssh prox "pct exec 119 -- pm2 restart bni-toolkit-dev"

# Netbox (CT141) - Single instance, brief restart
ssh prox "pct exec 141 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/netbox/netbox/netbox/configuration.py"
ssh prox "pct exec 141 -- systemctl restart netbox"
```

**Result:** 
- ✅ Zero downtime for TheoShift, LDC Tools, QuantShift (blue-green apps)
- ⚠️ ~30 seconds downtime for BNI Toolkit and Netbox (single-instance apps)
- ✅ All applications now connected to new primary (CT151)

# LDC Tools (CT133, CT135)
ssh prox "pct exec 133 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/ldc-tools/.env"
ssh prox "pct exec 133 -- pm2 restart ldctools-blue"

ssh prox "pct exec 135 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/ldc-tools/.env"
ssh prox "pct exec 135 -- pm2 restart ldctools-green"

# QuantShift (CT137, CT138)
ssh prox "pct exec 137 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/quantshift/.env"
ssh prox "pct exec 137 -- pm2 restart quantshift-blue"

ssh prox "pct exec 138 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/quantshift/.env"
ssh prox "pct exec 138 -- pm2 restart quantshift-green"

# BNI Toolkit (CT119)
ssh prox "pct exec 119 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/bni-toolkit/.env"
ssh prox "pct exec 119 -- pm2 restart bni-toolkit-dev"

# Netbox (CT141)
ssh prox "pct exec 141 -- sed -i 's/10.92.3.31/10.92.3.32/g' /opt/netbox/netbox/netbox/configuration.py"
ssh prox "pct exec 141 -- systemctl restart netbox"
```

#### Option B: Use HAProxy for Database Load Balancing (Future Enhancement)

**Pros:**
- Zero downtime switching
- Can switch back instantly
- Centralized connection management

**Cons:**
- Adds complexity
- Requires HAProxy configuration
- Additional hop in connection path

**Not implementing now, but documenting for future:**
```bash
# HAProxy configuration for PostgreSQL
listen postgres-primary
    bind 10.92.3.30:5432
    mode tcp
    option pgsql-check user postgres
    server pg-primary 10.92.3.32:5432 check
    server pg-replica 10.92.3.31:5432 check backup
```

---

### Phase 4: Verify Application Connectivity

```bash
# Test each application can connect to new primary

# TheoShift
ssh prox "pct exec 132 -- curl -s http://localhost:3001/api/health | grep -i database"

# LDC Tools
ssh prox "pct exec 133 -- curl -s http://localhost:3001/api/health | grep -i database"

# QuantShift
ssh prox "pct exec 137 -- curl -s http://localhost:3001/api/health | grep -i database"

# Netbox
ssh prox "pct exec 141 -- curl -s http://localhost:8000/api/ | head -5"

# Check active connections on CT151
ssh prox "pct exec 151 -- sudo -u postgres psql -c \"SELECT count(*), datname FROM pg_stat_activity WHERE datname IS NOT NULL GROUP BY datname;\""
# Should show connections from all apps
```

---

### Phase 5: Upgrade CT131 (Old Primary)

#### Step 5.1: Stop CT131
```bash
# Stop the old primary
ssh prox "pct stop 131"

# Verify stopped
ssh prox "pct status 131"
```

#### Step 5.2: Resize CT131 Resources
```bash
# Increase CPU cores
ssh prox "pct set 131 -cores 4"

# Increase memory
ssh prox "pct set 131 -memory 8192"

# Increase storage
ssh prox "pct resize 131 rootfs +80G"

# Verify changes
ssh prox "pct config 131 | grep -E 'cores|memory|rootfs'"
```

#### Step 5.3: Reconfigure CT131 as Replica
```bash
# Start container
ssh prox "pct start 131"

# Wait for startup
sleep 30

# Stop PostgreSQL
ssh prox "pct exec 131 -- systemctl stop postgresql"

# Remove old data directory (BACKUP FIRST!)
ssh prox "pct exec 131 -- mv /var/lib/postgresql/17/main /var/lib/postgresql/17/main.old"

# Create new data directory
ssh prox "pct exec 131 -- mkdir -p /var/lib/postgresql/17/main"
ssh prox "pct exec 131 -- chown -R postgres:postgres /var/lib/postgresql/17/main"

# Use pg_basebackup to clone from new primary (CT151)
ssh prox "pct exec 131 -- sudo -u postgres pg_basebackup -h 10.92.3.32 -U replication -D /var/lib/postgresql/17/main -Fp -Xs -P -R"

# Note: -R flag automatically creates standby.signal and replication config
```

#### Step 5.4: Configure Replication on CT131
```bash
# Verify standby.signal exists
ssh prox "pct exec 131 -- ls -la /var/lib/postgresql/17/main/standby.signal"

# Update postgresql.conf for replica settings
ssh prox "pct exec 131 -- bash -c 'cat >> /etc/postgresql/17/main/postgresql.conf << EOF
max_connections = 250
shared_buffers = 2GB
effective_cache_size = 6GB
hot_standby = on
EOF'"

# Start PostgreSQL
ssh prox "pct exec 131 -- systemctl start postgresql"

# Verify replication started
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
# Expected: t (true - in recovery/replica mode)

# Check replication status on new primary (CT151)
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"
# Should show CT131 connected
```

---

### Phase 6: Verification and Testing

#### Step 6.1: Verify Replication Health
```bash
# On primary (CT151), check replication status
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT client_addr, state, sync_state, replay_lag FROM pg_stat_replication;'"

# On replica (CT131), check replication lag
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;'"
```

#### Step 6.2: Test Write on Primary
```bash
# Create test table on primary (CT151)
ssh prox "pct exec 151 -- sudo -u postgres psql -d postgres -c 'CREATE TABLE upgrade_test (id serial, test_time timestamp DEFAULT now());'"

# Insert test data
ssh prox "pct exec 151 -- sudo -u postgres psql -d postgres -c 'INSERT INTO upgrade_test DEFAULT VALUES;'"

# Verify data replicated to replica (CT131)
ssh prox "pct exec 131 -- sudo -u postgres psql -d postgres -c 'SELECT * FROM upgrade_test;'"

# Cleanup
ssh prox "pct exec 151 -- sudo -u postgres psql -d postgres -c 'DROP TABLE upgrade_test;'"
```

#### Step 6.3: Monitor Application Performance
```bash
# Check application logs for database errors
ssh prox "pct exec 132 -- pm2 logs theoshift-green --lines 50 --nostream | grep -i error"
ssh prox "pct exec 133 -- pm2 logs ldctools-blue --lines 50 --nostream | grep -i error"

# Check database connection pool status
ssh prox "pct exec 151 -- sudo -u postgres psql -c \"SELECT count(*), state FROM pg_stat_activity GROUP BY state;\""
```

---

## Rollback Procedures

### Rollback Option 1: Switch Back to CT131 (If CT131 Still Primary)

**When:** During Phase 3, if issues detected after promoting CT151

```bash
# Demote CT151 back to replica
ssh prox "pct exec 151 -- systemctl stop postgresql"

# Promote CT131 back to primary
ssh prox "pct exec 131 -- sudo -u postgres pg_ctl promote -D /var/lib/postgresql/17/main"

# Reconfigure CT151 as replica (repeat Phase 5 steps for CT151)
```

### Rollback Option 2: Restore from Backup (If Data Corruption)

**When:** If database corruption detected

```bash
# Stop both containers
ssh prox "pct stop 131"
ssh prox "pct stop 151"

# Restore from full backup
ssh prox "pct exec 131 -- sudo -u postgres psql -f /var/backups/postgresql/full-backup-YYYYMMDD-HHMMSS.sql"

# Reconfigure replication
# (Follow Phase 5 steps to set up CT151 as replica)
```

---

## Post-Upgrade Tasks

### 1. Update Documentation
```bash
# Update APP-MAP.md
# Update infrastructure-spec.md
# Update this procedure with lessons learned
```

### 2. Update Backup Scripts
```bash
# Verify backup scripts point to correct primary
# Test backup/restore with new configuration
```

### 3. Monitor for 24 Hours
```bash
# Watch for:
# - Replication lag
# - Application errors
# - Performance degradation
# - Resource usage
```

### 4. Cleanup Old Data (After 1 Week)
```bash
# Remove old data directory from CT131
ssh prox "pct exec 131 -- rm -rf /var/lib/postgresql/17/main.old"
```

---

## Performance Comparison

### Before Upgrade
```
CT131 (Primary): 2 cores, 4GB RAM, 20GB storage
CT151 (Replica): 2 cores, 4GB RAM, 20GB storage
Max Connections: 100
Shared Buffers: 128MB (default)
```

### After Upgrade
```
CT151 (Primary): 4 cores, 8GB RAM, 100GB storage
CT131 (Replica): 4 cores, 8GB RAM, 100GB storage
Max Connections: 250
Shared Buffers: 2GB
Effective Cache: 6GB
```

**Expected Improvements:**
- 2x CPU capacity
- 2x memory capacity
- 5x storage capacity
- 2.5x connection capacity
- 16x shared buffer size

---

## Troubleshooting

### Issue: Replication Not Starting After Promotion

**Symptoms:** CT131 not connecting to CT151 after demotion

**Solution:**
```bash
# Check replication user exists on CT151
ssh prox "pct exec 151 -- sudo -u postgres psql -c \"SELECT * FROM pg_user WHERE usename='replication';\""

# If missing, create replication user
ssh prox "pct exec 151 -- sudo -u postgres psql -c \"CREATE USER replication WITH REPLICATION PASSWORD 'secure_password';\""

# Update pg_hba.conf on CT151
ssh prox "pct exec 151 -- bash -c 'echo \"host replication replication 10.92.3.31/32 md5\" >> /etc/postgresql/17/main/pg_hba.conf'"
ssh prox "pct exec 151 -- systemctl reload postgresql"
```

### Issue: Applications Can't Connect After Switch

**Symptoms:** Connection refused errors

**Solution:**
```bash
# Verify PostgreSQL listening on correct interface
ssh prox "pct exec 151 -- sudo -u postgres psql -c \"SHOW listen_addresses;\""

# Should be '*' or '0.0.0.0'

# Check pg_hba.conf allows connections
ssh prox "pct exec 151 -- cat /etc/postgresql/17/main/pg_hba.conf | grep -v '^#'"

# Verify firewall not blocking
ssh prox "pct exec 151 -- ss -tlnp | grep 5432"
```

### Issue: High Replication Lag

**Symptoms:** Replica falling behind primary

**Solution:**
```bash
# Check network connectivity
ssh prox "pct exec 131 -- ping -c 5 10.92.3.32"

# Check WAL sender/receiver status
ssh prox "pct exec 151 -- sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"
ssh prox "pct exec 131 -- sudo -u postgres psql -c 'SELECT * FROM pg_stat_wal_receiver;'"

# Increase wal_sender_timeout if needed
ssh prox "pct exec 151 -- bash -c 'echo \"wal_sender_timeout = 120s\" >> /etc/postgresql/17/main/postgresql.conf'"
ssh prox "pct exec 151 -- systemctl reload postgresql"
```

---

## Success Criteria

✅ **Upgrade Complete:**
- CT151 promoted to primary successfully
- CT131 reconfigured as replica successfully
- All applications connected to new primary
- Replication lag <1 second
- No data loss
- No application errors

✅ **Performance:**
- Resource usage within expected ranges
- Application response times unchanged or improved
- Database query performance stable

✅ **High Availability:**
- Replication working correctly
- Failover capability maintained
- Backup/restore tested

---

**Estimated Timeline:**
- Phase 1 (Upgrade CT151): 30 minutes
- Phase 2 (Promote CT151): 15 minutes
- Phase 3 (Switch Traffic): 30 minutes
- Phase 4 (Verify): 15 minutes
- Phase 5 (Upgrade CT131): 45 minutes
- Phase 6 (Final Verification): 15 minutes

**Total:** 2.5 hours

**Status:** Procedure documented, ready for execution
