# PostgreSQL Cluster Capacity Analysis for MSP Platform

**Date:** 2026-03-21  
**Purpose:** Determine if existing PostgreSQL cluster can support MSP platform databases

---

## Current PostgreSQL Cluster Status

### Primary Database Server (CT131)

**Hardware Resources:**
- **CPU:** 2 cores
- **RAM:** 4GB (3.6GB available)
- **Storage:** 20GB total, 2.8GB used (14% utilization, 18GB free)
- **PostgreSQL Version:** 17.6

**Current Resource Usage:**
- **Memory:** 408MB used / 4GB total (10% utilization)
- **CPU:** Low utilization (idle most of the time)
- **Disk I/O:** Moderate (48.4% wait time observed, but likely backup-related)

**Database Configuration:**
- **Max Connections:** 100
- **Current Databases:** 5 active + 2 templates
- **Total Database Size:** ~60MB (very small)

**Existing Databases:**
1. `theoshift_scheduler` - 18MB
2. `ldc_tools` - 11MB
3. `quantshift` - 11MB
4. `bni_toolkit` - 9.3MB
5. `postgres` - 7.5MB

### Replica Database Server (CT151)

**Status:** Active streaming replica (not analyzed in detail, mirrors primary)

---

## MSP Platform Database Requirements

### Estimated Database Needs

#### 1. BookStack (Documentation)
- **Type:** MySQL/MariaDB preferred, PostgreSQL supported
- **Estimated Size:** 500MB - 2GB (with documents, images)
- **Connections:** 10-20 concurrent
- **Load:** Low-Medium (read-heavy)

#### 2. Plane (Project Management)
- **Type:** PostgreSQL required
- **Estimated Size:** 1GB - 5GB (projects, tasks, attachments)
- **Connections:** 20-50 concurrent
- **Load:** Medium (read/write balanced)

#### 3. Zammad (Ticketing)
- **Type:** PostgreSQL required
- **Estimated Size:** 2GB - 10GB (tickets, attachments, history)
- **Connections:** 20-40 concurrent
- **Load:** Medium-High (write-heavy during ticket creation)

#### 4. Twenty CRM
- **Type:** PostgreSQL required
- **Estimated Size:** 500MB - 2GB (contacts, opportunities)
- **Connections:** 10-20 concurrent
- **Load:** Low-Medium

#### 5. Kimai (Time Tracking)
- **Type:** MySQL/MariaDB preferred, PostgreSQL supported
- **Estimated Size:** 200MB - 1GB (time entries)
- **Connections:** 5-15 concurrent
- **Load:** Low

#### 6. Documenso (E-Signature)
- **Type:** PostgreSQL required
- **Estimated Size:** 500MB - 3GB (documents, signatures)
- **Connections:** 5-10 concurrent
- **Load:** Low-Medium

#### 7. n8n (Automation)
- **Type:** PostgreSQL supported
- **Estimated Size:** 200MB - 1GB (workflows, executions)
- **Connections:** 5-10 concurrent
- **Load:** Low

#### 8. Authentik (Identity - if not using Entra ID)
- **Type:** PostgreSQL required
- **Estimated Size:** 100MB - 500MB (users, sessions)
- **Connections:** 10-30 concurrent
- **Load:** Medium (authentication requests)

---

## Capacity Analysis

### Storage Capacity

**Current Usage:** 2.8GB / 20GB (14%)  
**Available:** 18GB

**MSP Platform Estimated Total:** 5GB - 25GB (depending on usage)

**Scenarios:**
- **Light Usage (5-10 clients):** ~5-10GB
- **Medium Usage (20-30 clients):** ~10-15GB
- **Heavy Usage (50+ clients):** ~20-25GB

**Recommendation:** 
- ✅ **Current 20GB is INSUFFICIENT for long-term growth**
- ⚠️ **Expand to 50GB minimum, 100GB recommended**
- Action: Resize CT131 rootfs to 50-100GB

### Memory Capacity

**Current Usage:** 408MB / 4GB (10%)  
**Available:** 3.6GB

**MSP Platform Estimated Requirements:**
- PostgreSQL shared_buffers: 1-2GB (25-50% of RAM recommended)
- Active connections: 100-200 concurrent
- Working memory per connection: 4-8MB

**Calculation:**
- Base PostgreSQL: 500MB
- Shared buffers: 1.5GB
- Connection overhead (150 connections × 6MB): 900MB
- OS overhead: 500MB
- **Total Estimated:** 3.4GB

**Recommendation:**
- ⚠️ **Current 4GB RAM is TIGHT but workable for initial deployment**
- ✅ **Expand to 8GB for comfortable headroom**
- Action: Increase CT131 memory to 8GB

### Connection Capacity

**Current Max:** 100 connections  
**Current Usage:** ~10-20 connections

**MSP Platform Estimated:**
- 8 services × 15 avg connections = 120 connections
- Peak usage: 150-200 connections

**Recommendation:**
- ⚠️ **Current 100 max_connections is INSUFFICIENT**
- ✅ **Increase to 200-300 connections**
- Action: Update PostgreSQL config `max_connections = 250`

### CPU Capacity

**Current:** 2 cores, low utilization

**MSP Platform Impact:**
- Moderate increase in query load
- Background jobs (backups, maintenance)
- Concurrent writes from multiple services

**Recommendation:**
- ✅ **Current 2 cores SUFFICIENT for initial deployment**
- Consider 4 cores if performance issues arise
- Monitor CPU usage after deployment

---

## Database Architecture Options

### Option 1: Single Shared PostgreSQL Cluster (RECOMMENDED)

**Architecture:**
```
CT131 (Primary) - PostgreSQL 17.6
├── theoshift_scheduler (existing)
├── ldc_tools (existing)
├── quantshift (existing)
├── bni_toolkit (existing)
├── cloudigan_plane (new)
├── cloudigan_zammad (new)
├── cloudigan_bookstack (new)
├── cloudigan_twenty (new)
├── cloudigan_kimai (new)
├── cloudigan_documenso (new)
├── cloudigan_n8n (new)
└── cloudigan_authentik (new)

CT151 (Replica) - Streaming replication
```

**Pros:**
- ✅ Centralized management
- ✅ Efficient resource utilization
- ✅ Single backup strategy
- ✅ Follows existing pattern (Decision D-011)
- ✅ Streaming replication for HA

**Cons:**
- ⚠️ Single point of failure (mitigated by replica)
- ⚠️ Resource contention possible
- ⚠️ All services affected if PostgreSQL fails

**Resource Adjustments Needed:**
- Increase RAM: 4GB → 8GB
- Increase Storage: 20GB → 50-100GB
- Increase max_connections: 100 → 250

**Recommendation:** ✅ **Use this option**

---

### Option 2: Dedicated MSP Platform PostgreSQL Cluster

**Architecture:**
```
CT131 (Existing Apps)
├── theoshift_scheduler
├── ldc_tools
├── quantshift
└── bni_toolkit

CT200 (MSP Platform Primary)
├── cloudigan_plane
├── cloudigan_zammad
├── cloudigan_bookstack
├── cloudigan_twenty
├── cloudigan_kimai
├── cloudigan_documenso
├── cloudigan_n8n
└── cloudigan_authentik

CT201 (MSP Platform Replica)
```

**Pros:**
- ✅ Isolation between existing apps and MSP platform
- ✅ Independent scaling
- ✅ Failure isolation
- ✅ Easier to migrate MSP platform to cloud later

**Cons:**
- ❌ Duplicate infrastructure
- ❌ More containers to manage
- ❌ Higher resource usage
- ❌ More complex backup strategy

**Resource Requirements:**
- New CT200: 4 cores, 8GB RAM, 100GB storage
- New CT201: 4 cores, 8GB RAM, 100GB storage
- Total: 8 cores, 16GB RAM, 200GB storage

**Recommendation:** ⚠️ **Only if you want strict isolation**

---

### Option 3: Per-Service Databases (NOT RECOMMENDED)

**Architecture:**
```
CT131 - Existing apps
CT200 - Plane database
CT201 - Zammad database
CT202 - BookStack database
... (8 separate database containers)
```

**Pros:**
- ✅ Maximum isolation
- ✅ Independent scaling per service

**Cons:**
- ❌ Massive operational overhead
- ❌ 8+ database containers to manage
- ❌ Complex backup strategy
- ❌ Inefficient resource usage
- ❌ Violates simplicity principle

**Recommendation:** ❌ **Do NOT use this approach**

---

## Final Recommendation

### ✅ Use Option 1: Single Shared PostgreSQL Cluster

**Rationale:**
1. Follows existing architecture pattern
2. Efficient resource utilization
3. Simpler to manage and backup
4. Proven approach (current apps already share CT131)
5. Streaming replication provides HA
6. Aligns with "do not over-engineer" principle

**Required Actions:**

#### Immediate (Before MSP Platform Deployment)
1. **Resize CT131 Storage**
   ```bash
   # Increase rootfs from 20GB to 100GB
   pct resize 131 rootfs +80G
   ```

2. **Increase CT131 Memory**
   ```bash
   # Update container config
   pct set 131 -memory 8192
   ```

3. **Update PostgreSQL Configuration**
   ```bash
   # Edit /etc/postgresql/17/main/postgresql.conf
   max_connections = 250
   shared_buffers = 2GB
   effective_cache_size = 6GB
   maintenance_work_mem = 512MB
   ```

4. **Restart PostgreSQL**
   ```bash
   pct exec 131 -- systemctl restart postgresql
   ```

5. **Verify Replica Sync**
   ```bash
   # Check CT151 replication status
   pct exec 151 -- sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
   ```

#### During MSP Platform Deployment
6. **Create Databases** (following D-011 naming convention)
   ```sql
   CREATE DATABASE cloudigan_plane OWNER postgres;
   CREATE DATABASE cloudigan_zammad OWNER postgres;
   CREATE DATABASE cloudigan_bookstack OWNER postgres;
   CREATE DATABASE cloudigan_twenty OWNER postgres;
   CREATE DATABASE cloudigan_kimai OWNER postgres;
   CREATE DATABASE cloudigan_documenso OWNER postgres;
   CREATE DATABASE cloudigan_n8n OWNER postgres;
   CREATE DATABASE cloudigan_authentik OWNER postgres;
   ```

7. **Create Service Users** (principle of least privilege)
   ```sql
   CREATE USER plane_user WITH PASSWORD 'secure_password';
   GRANT ALL PRIVILEGES ON DATABASE cloudigan_plane TO plane_user;
   -- Repeat for each service
   ```

8. **Update Backup Strategy**
   - Extend existing PostgreSQL backup script to include new databases
   - Verify backups include MSP platform databases

---

## Monitoring & Maintenance

### Metrics to Monitor
- Database size growth
- Connection count
- Query performance
- Disk I/O
- Memory usage
- Replication lag

### Maintenance Tasks
- Weekly VACUUM ANALYZE
- Monthly database size review
- Quarterly performance tuning
- Regular backup testing

---

## Migration Path (If Needed Later)

If you decide to move MSP platform to dedicated cluster later:

1. Create new CT200/CT201 PostgreSQL cluster
2. Use `pg_dump` to export MSP databases
3. Import to new cluster
4. Update application connection strings
5. Verify functionality
6. Decommission old databases

This keeps options open without over-engineering upfront.

---

## Summary

**Decision:** ✅ **Use existing PostgreSQL cluster (CT131/CT151) with resource upgrades**

**Required Upgrades:**
- RAM: 4GB → 8GB
- Storage: 20GB → 100GB
- Max Connections: 100 → 250

**Estimated Cost:** $0 (resource reallocation within existing infrastructure)

**Timeline:** 30 minutes to implement upgrades

**Risk:** Low (proven architecture, simple upgrades)

---

**Next Steps:**
1. Implement resource upgrades to CT131
2. Update PostgreSQL configuration
3. Test with increased load
4. Proceed with MSP platform deployment
