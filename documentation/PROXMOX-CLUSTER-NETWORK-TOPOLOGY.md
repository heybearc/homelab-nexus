# Proxmox 3-Node Cluster - Network Topology Design

**Date:** 2026-03-21  
**Purpose:** Network architecture for 3-node Proxmox cluster expansion  
**Timeline:** 30 days (hardware arriving)

---

## Executive Summary

**Current State:**
- Single Proxmox host (10.92.0.5)
- Single TrueNAS storage (10.92.0.3)
- 28 production containers
- Single point of failure

**Target State:**
- 3-node Proxmox cluster with HA
- Shared storage via TrueNAS NFS
- Redundant networking
- Zero-downtime maintenance capability

---

## Network Topology Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Internet / WAN                                  │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │   Core Switch           │
                    │   10.92.0.1             │
                    └────────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼────────┐    ┌──────────▼─────────┐   ┌────────▼────────┐
│  Proxmox Node 1│    │  Proxmox Node 2    │   │ Proxmox Node 3  │
│  (prox)        │    │  (prox2)           │   │ (prox3)         │
│  10.92.0.5     │    │  10.92.0.6         │   │ 10.92.0.7       │
└───────┬────────┘    └──────────┬─────────┘   └────────┬────────┘
        │                        │                       │
        │  ┌─────────────────────┼───────────────────┐  │
        │  │                     │                   │  │
        │  │  Cluster Network (Corosync)            │  │
        │  │  10.92.1.5, 10.92.1.6, 10.92.1.7       │  │
        │  │  VLAN 10 - Dedicated Cluster Sync      │  │
        │  └─────────────────────┼───────────────────┘  │
        │                        │                       │
        │  ┌─────────────────────┼───────────────────┐  │
        │  │                     │                   │  │
        │  │  Storage Network (NFS/iSCSI)           │  │
        │  │  10.92.2.5, 10.92.2.6, 10.92.2.7       │  │
        │  │  VLAN 20 - TrueNAS Communication       │  │
        │  └─────────────────────┼───────────────────┘  │
        │                        │                       │
        └────────────────────────┼───────────────────────┘
                                 │
                        ┌────────▼────────┐
                        │   TrueNAS       │
                        │   10.92.0.3     │
                        │   (Storage)     │
                        │                 │
                        │ NFS: 10.92.2.3  │
                        └─────────────────┘

Container Network (Production):
┌──────────────────────────────────────────────────────────────┐
│  VLAN 923 - Production Containers (10.92.3.0/24)            │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │
│  │ CT131  │ │ CT132  │ │ CT133  │ │ CT150  │ │ CT180  │   │
│  │ PG-SQL │ │ Theo   │ │ LDC    │ │ Monitor│ │Scrypted│   │
│  │.3.31   │ │.3.22   │ │.3.23   │ │.3.2    │ │.3.15   │   │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │
│  ... (28 total containers distributed across nodes)         │
└──────────────────────────────────────────────────────────────┘
```

---

## VLAN Design

### VLAN 1 - Management Network (10.92.0.0/24)
**Purpose:** Proxmox host management, TrueNAS management  
**Devices:**
- Proxmox Node 1: 10.92.0.5
- Proxmox Node 2: 10.92.0.6
- Proxmox Node 3: 10.92.0.7
- TrueNAS: 10.92.0.3
- Core Switch: 10.92.0.1
- AdGuard DNS: 10.92.0.10

**Gateway:** 10.92.0.1  
**DNS:** 10.92.0.10 (AdGuard)  
**Access:** SSH, Proxmox Web UI (8006), TrueNAS Web UI

---

### VLAN 10 - Cluster Network (10.92.1.0/24) **NEW**
**Purpose:** Proxmox cluster communication (Corosync, quorum)  
**Devices:**
- Proxmox Node 1: 10.92.1.5
- Proxmox Node 2: 10.92.1.6
- Proxmox Node 3: 10.92.1.7

**Gateway:** None (isolated network)  
**DNS:** None  
**Traffic:** Cluster heartbeat, quorum, migration  
**Requirements:**
- Low latency (<1ms)
- Dedicated physical interface or VLAN
- No other traffic on this network
- Multicast enabled

**Why Separate:**
- Prevents cluster split-brain scenarios
- Isolates cluster traffic from production
- Improves cluster stability
- Required for proper HA operation

---

### VLAN 20 - Storage Network (10.92.2.0/24) **NEW**
**Purpose:** NFS/iSCSI traffic between Proxmox and TrueNAS  
**Devices:**
- Proxmox Node 1: 10.92.2.5
- Proxmox Node 2: 10.92.2.6
- Proxmox Node 3: 10.92.2.7
- TrueNAS: 10.92.2.3

**Gateway:** None (isolated network)  
**DNS:** None  
**Traffic:** NFS mounts, iSCSI, VM/CT storage  
**Requirements:**
- High bandwidth (10GbE preferred, 1GbE minimum)
- Jumbo frames enabled (MTU 9000)
- Dedicated physical interface or VLAN
- Low latency

**Why Separate:**
- Prevents storage traffic from saturating management network
- Improves VM/CT performance
- Isolates storage from production traffic
- Best practice for shared storage

---

### VLAN 923 - Production Containers (10.92.3.0/24)
**Purpose:** Production container network (existing)  
**Devices:**
- All LXC containers (CT100-189)
- HAProxy VIP: 10.92.3.33
- NPM: 10.92.3.33 (CT121)

**Gateway:** 10.92.3.1  
**DNS:** 10.92.0.10 (AdGuard)  
**Traffic:** Production application traffic  
**Access:** HTTP/HTTPS, application-specific ports

---

## Physical Network Configuration

### Per-Node Network Interfaces

**Minimum Configuration (1GbE):**
```
Node 1, 2, 3:
├── eth0 (1GbE) - Management (VLAN 1: 10.92.0.x)
├── eth0.10 - Cluster (VLAN 10: 10.92.1.x)
├── eth0.20 - Storage (VLAN 20: 10.92.2.x)
└── vmbr0923 - Container bridge (VLAN 923: 10.92.3.x)
```

**Recommended Configuration (Dual NIC):**
```
Node 1, 2, 3:
├── eth0 (1GbE) - Management + Cluster
│   ├── VLAN 1: 10.92.0.x (Management)
│   └── VLAN 10: 10.92.1.x (Cluster)
├── eth1 (1GbE or 10GbE) - Storage + Containers
│   ├── VLAN 20: 10.92.2.x (Storage)
│   └── VLAN 923: 10.92.3.x (Containers)
└── vmbr0923 - Container bridge
```

**Optimal Configuration (Quad NIC or 10GbE):**
```
Node 1, 2, 3:
├── eth0 (1GbE) - Management (VLAN 1)
├── eth1 (1GbE) - Cluster (VLAN 10)
├── eth2 (10GbE) - Storage (VLAN 20)
└── eth3 (1GbE) - Containers (VLAN 923)
```

---

## Proxmox Network Configuration

### /etc/network/interfaces (Node 1 Example)

```bash
# Management Interface
auto eth0
iface eth0 inet static
    address 10.92.0.5/24
    gateway 10.92.0.1
    dns-nameservers 10.92.0.10

# Cluster Network (VLAN 10)
auto eth0.10
iface eth0.10 inet static
    address 10.92.1.5/24
    vlan-raw-device eth0

# Storage Network (VLAN 20)
auto eth0.20
iface eth0.20 inet static
    address 10.92.2.5/24
    vlan-raw-device eth0
    mtu 9000  # Jumbo frames for storage

# Container Bridge (VLAN 923)
auto vmbr0923
iface vmbr0923 inet static
    address 10.92.3.254/24
    bridge-ports eth0.923
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
```

**Node 2:** Change IPs to .6  
**Node 3:** Change IPs to .7

---

## TrueNAS Network Configuration

### Interfaces

```
Primary Interface (Management):
- IP: 10.92.0.3/24
- Gateway: 10.92.0.1
- DNS: 10.92.0.10

Storage Interface (NFS):
- IP: 10.92.2.3/24
- No gateway (isolated)
- MTU: 9000 (jumbo frames)
```

### NFS Exports

```
/mnt/media-pool/data/proxmox-backups
- Allowed Networks: 10.92.2.0/24
- Maproot User: root
- Maproot Group: wheel

/mnt/media-pool/data/vm-storage (if using shared VM storage)
- Allowed Networks: 10.92.2.0/24
- Maproot User: root
- Maproot Group: wheel
```

---

## Cluster Configuration

### Corosync Configuration

```bash
# /etc/pve/corosync.conf
totem {
    version: 2
    cluster_name: cloudigan-cluster
    transport: knet
    crypto_cipher: aes256
    crypto_hash: sha256
    
    interface {
        linknumber: 0
        bindnetaddr: 10.92.1.0
        mcastaddr: 239.192.1.1
        mcastport: 5405
    }
}

nodelist {
    node {
        name: prox
        nodeid: 1
        quorum_votes: 1
        ring0_addr: 10.92.1.5
    }
    node {
        name: prox2
        nodeid: 2
        quorum_votes: 1
        ring0_addr: 10.92.1.6
    }
    node {
        name: prox3
        nodeid: 3
        quorum_votes: 1
        ring0_addr: 10.92.1.7
    }
}

quorum {
    provider: corosync_votequorum
    expected_votes: 3
    two_node: 0
}
```

### Cluster Creation Commands

```bash
# On Node 1 (existing prox):
pvecm create cloudigan-cluster --link0 10.92.1.5

# On Node 2 (new prox2):
pvecm add 10.92.1.5 --link0 10.92.1.6

# On Node 3 (new prox3):
pvecm add 10.92.1.5 --link0 10.92.1.7

# Verify cluster status:
pvecm status
pvecm nodes
```

---

## High Availability Configuration

### HA Groups

```bash
# Create HA group for critical services
ha-manager groupadd critical-services \
    --nodes "prox:2,prox2:2,prox3:1" \
    --nofailback 0

# Add containers to HA group
ha-manager add ct:131 --group critical-services --state started
ha-manager add ct:132 --group critical-services --state started
ha-manager add ct:150 --group critical-services --state started
```

### Fencing Configuration

**Watchdog Timer:**
```bash
# Enable watchdog on all nodes
echo "softdog" >> /etc/modules
modprobe softdog
```

**Fencing Policy:**
- Automatic fencing on node failure
- Watchdog timeout: 60 seconds
- HA manager will restart failed containers on surviving nodes

---

## Storage Configuration

### Shared Storage via TrueNAS NFS

```bash
# Add TrueNAS NFS storage to cluster
pvesm add nfs truenas-vm-storage \
    --server 10.92.2.3 \
    --export /mnt/media-pool/data/vm-storage \
    --content images,rootdir \
    --options vers=4.2

# Add TrueNAS backup storage (already exists)
pvesm add nfs truenas-backups \
    --server 10.92.2.3 \
    --export /mnt/media-pool/data/proxmox-backups \
    --content backup
```

### Local Storage (Per-Node)

```bash
# Each node keeps local storage for:
# - ISO images
# - Container templates
# - Temporary files

# Node 1: local-lvm, hdd-pool (existing)
# Node 2: local-lvm (new)
# Node 3: local-lvm (new)
```

---

## Migration Strategy

### Container Distribution

**Current (Single Node):**
- All 28 containers on Node 1

**Target (3-Node Cluster):**
- Node 1: 10 containers (critical services)
- Node 2: 9 containers (production apps)
- Node 3: 9 containers (media + dev)

**Distribution Plan:**

**Node 1 (prox) - Critical Infrastructure:**
- CT131 - PostgreSQL Primary
- CT136 - HAProxy Primary
- CT141 - Netbox
- CT150 - Monitoring Stack
- CT180 - Scrypted NVR
- CT181 - Cloudigan API Blue
- CT182 - Cloudigan API Green
- CT190 - Ansible (new)
- CT200 - Authentik (new)
- CT201 - BookStack Blue (new)

**Node 2 (prox2) - Production Apps:**
- CT132 - TheoShift Green
- CT133 - LDC Tools Blue
- CT134 - TheoShift Blue
- CT135 - LDC Tools Green
- CT137 - QuantShift Blue
- CT138 - QuantShift Green
- CT151 - PostgreSQL Replica
- CT202 - BookStack Green (new)
- CT203 - Plane Blue (new)

**Node 3 (prox3) - Media & Development:**
- CT100 - QuantShift Bot Primary
- CT101 - QuantShift Bot Standby
- CT115 - QA-01
- CT119 - BNI Toolkit Dev
- CT120-129 - Media Stack (10 containers)
- CT139 - HAProxy Standby
- CT140 - AdGuard
- CT204 - Plane Green (new)

---

## Migration Procedure

### Phase 1: Prepare New Nodes (Day 1)

1. **Rack and cable new servers**
2. **Install Proxmox VE on Node 2 and Node 3**
3. **Configure network interfaces** (management, cluster, storage)
4. **Join nodes to cluster**
5. **Configure shared storage**
6. **Test cluster communication**

### Phase 2: Migrate Containers (Day 2-3)

1. **Migrate non-critical containers first** (media stack)
   ```bash
   pct migrate 120 prox3 --online
   ```

2. **Migrate development containers**
   ```bash
   pct migrate 115 prox3 --online
   pct migrate 119 prox3 --online
   ```

3. **Migrate production apps** (blue-green pairs)
   ```bash
   # Migrate standby first, test, then migrate live
   pct migrate 134 prox2 --online  # TheoShift Blue (standby)
   # Test, then migrate green
   pct migrate 132 prox2 --online  # TheoShift Green (live)
   ```

4. **Migrate critical infrastructure last**
   ```bash
   pct migrate 151 prox2 --online  # PostgreSQL Replica
   # Keep CT131 (primary) on Node 1
   ```

### Phase 3: Enable HA (Day 4)

1. **Configure HA groups**
2. **Add critical containers to HA**
3. **Test failover scenarios**
4. **Document HA procedures**

---

## Firewall Rules

### Cluster Network (VLAN 10)
```
Allow: Corosync (UDP 5404-5405)
Allow: Cluster multicast (239.192.1.1)
Deny: All other traffic
```

### Storage Network (VLAN 20)
```
Allow: NFS (TCP 2049)
Allow: NFS mountd (TCP/UDP 111, 20048)
Allow: SSH (TCP 22) - for management
Deny: All other traffic
```

### Management Network (VLAN 1)
```
Allow: SSH (TCP 22)
Allow: Proxmox Web UI (TCP 8006)
Allow: SPICE/VNC (TCP 3128, 5900-5999)
Allow: DNS (UDP 53)
Deny: All other traffic from internet
```

---

## Monitoring & Alerting

### Cluster Health Monitoring

**Prometheus Metrics:**
- Cluster quorum status
- Node availability
- Corosync ring status
- Storage connectivity
- HA service status

**Grafana Dashboards:**
- Proxmox Cluster Overview
- Node Resource Usage
- Storage Performance
- HA Service Status

**Alerts:**
- Node offline
- Quorum lost
- Storage unavailable
- HA failover occurred
- High resource usage

---

## Backup Strategy

### Cluster Configuration Backup

```bash
# Backup cluster configuration daily
pvecm backup /mnt/pve/truenas-backups/cluster-config/cluster-backup-$(date +%Y%m%d).tar.gz

# Backup to TrueNAS
rsync -av /etc/pve/ truenas:/mnt/media-pool/data/proxmox-backups/cluster-config/
```

### Container Backups

- Continue existing backup strategy (see PROXMOX-BACKUP-STRATEGY.md)
- Backups stored on TrueNAS (shared across cluster)
- All nodes can access backup storage

---

## Disaster Recovery

### Single Node Failure

**Scenario:** Node 2 fails  
**Impact:** Containers on Node 2 unavailable  
**Recovery:**
1. HA manager automatically restarts critical containers on Node 1 or 3
2. Non-HA containers remain offline until Node 2 restored
3. Manual migration if needed: `pct migrate <ctid> prox3`

**RTO:** 2-5 minutes (automatic HA failover)

### Two Node Failure

**Scenario:** Node 2 and Node 3 fail  
**Impact:** Only Node 1 containers available  
**Recovery:**
1. Cluster loses quorum (2/3 nodes down)
2. Manual intervention required
3. Restore from backups to Node 1
4. Rebuild cluster when nodes available

**RTO:** 1-4 hours (manual recovery)

### Complete Cluster Failure

**Scenario:** All 3 nodes fail  
**Impact:** Complete outage  
**Recovery:**
1. Rebuild Proxmox cluster from scratch
2. Restore containers from TrueNAS backups
3. Reconfigure networking and HA

**RTO:** 4-8 hours (full rebuild)

---

## Testing Plan

### Pre-Production Testing

1. **Network Connectivity**
   - [ ] Ping test all VLANs
   - [ ] Bandwidth test storage network
   - [ ] Latency test cluster network

2. **Cluster Functionality**
   - [ ] Verify quorum
   - [ ] Test node shutdown/restart
   - [ ] Test cluster communication

3. **Storage Performance**
   - [ ] NFS mount test
   - [ ] Read/write performance test
   - [ ] Concurrent access test

4. **HA Failover**
   - [ ] Simulate node failure
   - [ ] Verify container migration
   - [ ] Test automatic restart

5. **Backup/Restore**
   - [ ] Test container backup
   - [ ] Test container restore
   - [ ] Verify backup accessibility from all nodes

---

## Implementation Timeline

**Week 1: Hardware Setup**
- Day 1-2: Rack servers, cable network
- Day 3-4: Install Proxmox on new nodes
- Day 5: Configure networking and join cluster

**Week 2: Migration**
- Day 1: Migrate media stack containers
- Day 2: Migrate development containers
- Day 3: Migrate production apps
- Day 4: Configure HA
- Day 5: Testing and validation

**Week 3: Optimization**
- Day 1-2: Performance tuning
- Day 3-4: Documentation updates
- Day 5: Final testing and sign-off

**Week 4: Production**
- Monitor cluster stability
- Fine-tune HA policies
- Train on cluster management

---

## Cost Estimate

**Hardware (Already Ordered):**
- 2x Proxmox nodes: $TBD

**Network Equipment (If Needed):**
- Managed switch with VLAN support: $200-500
- Additional network cables: $50-100

**Software:**
- Proxmox VE: Free (open source)
- Corosync/Pacemaker: Free (included)

**Total Additional Cost:** $250-600 (network equipment only)

---

## Success Criteria

✅ **Cluster Formation:**
- All 3 nodes joined to cluster
- Quorum established
- Corosync communication verified

✅ **High Availability:**
- HA enabled for critical containers
- Automatic failover tested and working
- RTO <5 minutes for HA services

✅ **Performance:**
- No degradation in container performance
- Storage network throughput >100MB/s
- Cluster network latency <1ms

✅ **Reliability:**
- 30-day uptime test passed
- Zero unplanned failovers
- All monitoring alerts functional

---

**Next Steps:**
1. Review topology with user
2. Order any missing network equipment
3. Prepare installation media for new nodes
4. Create detailed migration runbook
5. Schedule maintenance window for migration

**Status:** Design complete, ready for implementation upon hardware arrival
