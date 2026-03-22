# Network Infrastructure - Cloudigan Lab

**Date:** 2026-03-21  
**Purpose:** Document physical and logical network infrastructure

---

## Physical Network Equipment

### Core Router/Gateway
**Model:** TP-Link ER7206 Omada Gigabit VPN Router  
**Management IP:** TBD  
**Role:** Primary gateway and router  
**Features:**
- Multi-WAN load balancing
- VPN server (IPsec, OpenVPN, L2TP)
- VLAN support
- Firewall and security
- Omada SDN integration

**Configuration:**
- WAN: Internet connection
- LAN: 10.92.0.0/16 network
- VLANs: 1, 10, 20, 923

---

### Core Switch
**Model:** TP-Link 24-Port Gigabit PoE+ Managed Switch  
**Management IP:** TBD  
**Role:** Core L2 switch with VLAN support  
**Features:**
- 24x Gigabit Ethernet ports
- PoE+ support (802.3at)
- VLAN support (802.1Q)
- Link aggregation (LACP)
- QoS support
- Omada SDN integration

**Port Assignments:**
- Port 1-3: Proxmox nodes (trunk, all VLANs)
- Port 4: TrueNAS (trunk, VLANs 1, 20)
- Port 5: HAProxy primary (VLAN 923)
- Port 6-24: Access ports and PoE devices

**VLAN Configuration:**
- VLAN 1: Management (10.92.0.0/24) - Untagged on management ports
- VLAN 10: Cluster (10.92.1.0/24) - Tagged on Proxmox ports
- VLAN 20: Storage (10.92.2.0/24) - Tagged on Proxmox and TrueNAS ports
- VLAN 923: Containers (10.92.3.0/24) - Tagged on Proxmox ports

---

## Network Topology

```
                    Internet
                        │
                        │
                ┌───────▼────────┐
                │   ER7206        │
                │   Gateway       │
                │   10.92.0.1     │
                └───────┬────────┘
                        │
                        │
            ┌───────────▼──────────┐
            │  TP-Link 24-Port     │
            │  PoE+ Switch         │
            │  Core Switch         │
            └───┬───┬───┬───┬──────┘
                │   │   │   │
        ┌───────┘   │   │   └────────┐
        │           │   │            │
    ┌───▼────┐  ┌──▼───▼──┐  ┌─────▼─────┐
    │ Prox1  │  │ Prox2   │  │  Prox3    │
    │10.92.0.5│ │10.92.0.6│  │10.92.0.7  │
    └────────┘  └─────────┘  └───────────┘
        │
        │ (Storage Network - VLAN 20)
        │
    ┌───▼────────┐
    │  TrueNAS   │
    │ 10.92.0.3  │
    │ 10.92.2.3  │
    └────────────┘
```

---

## VLAN Design

### VLAN 1 - Management Network
**Subnet:** 10.92.0.0/24  
**Gateway:** 10.92.0.1 (ER7206)  
**DNS:** 10.92.0.10 (AdGuard)  
**Purpose:** Device management and administration

**Assigned IPs:**
- 10.92.0.1 - ER7206 Gateway
- 10.92.0.3 - TrueNAS Management
- 10.92.0.5 - Proxmox Node 1
- 10.92.0.6 - Proxmox Node 2 (future)
- 10.92.0.7 - Proxmox Node 3 (future)
- 10.92.0.10 - AdGuard DNS
- 10.92.0.20-50 - Reserved for infrastructure

---

### VLAN 10 - Cluster Network
**Subnet:** 10.92.1.0/24  
**Gateway:** None (isolated)  
**Purpose:** Proxmox cluster communication (Corosync)

**Assigned IPs:**
- 10.92.1.5 - Proxmox Node 1 Cluster Interface
- 10.92.1.6 - Proxmox Node 2 Cluster Interface (future)
- 10.92.1.7 - Proxmox Node 3 Cluster Interface (future)

**Traffic:** Corosync heartbeat, quorum, cluster sync  
**Multicast:** 239.192.1.1

---

### VLAN 20 - Storage Network
**Subnet:** 10.92.2.0/24  
**Gateway:** None (isolated)  
**Purpose:** NFS/iSCSI storage traffic

**Assigned IPs:**
- 10.92.2.3 - TrueNAS Storage Interface
- 10.92.2.5 - Proxmox Node 1 Storage Interface
- 10.92.2.6 - Proxmox Node 2 Storage Interface (future)
- 10.92.2.7 - Proxmox Node 3 Storage Interface (future)

**MTU:** 9000 (Jumbo frames enabled)  
**Traffic:** NFS mounts, VM/CT storage access

---

### VLAN 923 - Production Containers
**Subnet:** 10.92.3.0/24  
**Gateway:** 10.92.3.1  
**DNS:** 10.92.0.10 (AdGuard)  
**Purpose:** Production container network

**IP Ranges:**
- 10.92.3.1 - Gateway
- 10.92.3.2-30 - Infrastructure containers
- 10.92.3.31-50 - Database and core services
- 10.92.3.51-100 - Application containers
- 10.92.3.101-200 - Reserved for expansion

**Key Services:**
- 10.92.3.2 - Monitoring Stack (CT150)
- 10.92.3.11 - Netbox (CT141)
- 10.92.3.15 - Scrypted NVR (CT180)
- 10.92.3.31 - PostgreSQL Primary (CT131)
- 10.92.3.32 - PostgreSQL Replica (CT151)
- 10.92.3.33 - HAProxy VIP
- 10.92.3.90 - Ansible Control (CT183)

---

## DNS Configuration

### Internal DNS (AdGuard Home)
**IP:** 10.92.0.10  
**Role:** Primary internal DNS server  
**Zones:**
- cloudigan.net (internal)
- Local container hostnames

**Key Records:**
- theoshift.cloudigan.net → 10.92.3.33 (HAProxy VIP)
- ldctools.cloudigan.net → 10.92.3.33 (HAProxy VIP)
- quantshift.cloudigan.net → 10.92.3.33 (HAProxy VIP)
- ansible.cloudigan.net → 10.92.3.90
- netbox.cloudigan.net → 10.92.3.11
- scrypted.cloudigan.net → 10.92.3.15

---

### External DNS (Wix)
**Provider:** Wix DNS Management  
**Purpose:** Public DNS for external services

**Public Records:**
- cloudigan.net → Public IP
- *.cloudigan.net → Public IP (wildcard for subdomains)

---

## Firewall Rules (ER7206)

### WAN → LAN
```
Default: DENY all
Allow: Established/Related connections
Allow: Specific port forwards (if needed)
```

### LAN → WAN
```
Default: ALLOW all
NAT: Enabled
```

### Inter-VLAN Routing
```
VLAN 1 (Management) → All VLANs: ALLOW
VLAN 923 (Containers) → VLAN 1: ALLOW (for DNS, gateway)
VLAN 923 (Containers) → VLAN 20: ALLOW (for storage access)
VLAN 10 (Cluster) → Isolated (no routing)
VLAN 20 (Storage) → Isolated (no routing except from management)
```

---

## Network Services

### DHCP
**Server:** ER7206  
**Scope:** 10.92.0.100-10.92.0.200 (management VLAN only)  
**Reservations:** All infrastructure devices use static IPs

### NTP
**Server:** ER7206 (syncs to internet NTP)  
**Clients:** All Proxmox nodes, TrueNAS, containers

### Monitoring
**Prometheus:** CT150 (10.92.3.2)  
**Grafana:** CT150 (10.92.3.2)  
**Targets:**
- All Proxmox nodes (node_exporter)
- All containers (node_exporter)
- TrueNAS (custom exporter)
- Network devices (SNMP)

---

## Network Performance

### Bandwidth
- WAN: TBD (ISP dependent)
- LAN: 1 Gbps (all ports)
- Storage Network: 1 Gbps (upgrade to 10 Gbps recommended)

### Latency
- Management Network: <1ms
- Cluster Network: <1ms (critical)
- Storage Network: <2ms
- Container Network: <1ms

---

## Future Enhancements

### Short-Term
- [ ] Document ER7206 management IP
- [ ] Document switch management IP
- [ ] Configure SNMP monitoring
- [ ] Set up network performance monitoring

### Medium-Term
- [ ] Implement 10GbE for storage network
- [ ] Add redundant gateway (ER7206 #2)
- [ ] Implement link aggregation for Proxmox nodes
- [ ] Add UPS monitoring integration

### Long-Term
- [ ] Implement SDN with Omada controller
- [ ] Add dedicated backup network (VLAN 30)
- [ ] Implement network segmentation for MSP clients
- [ ] Add IDS/IPS capabilities

---

## Troubleshooting

### Common Issues

**Issue:** Container cannot reach internet  
**Check:**
1. Gateway configured correctly (10.92.3.1)
2. DNS configured correctly (10.92.0.10)
3. Firewall rules allow VLAN 923 → WAN

**Issue:** Slow storage performance  
**Check:**
1. MTU set to 9000 on storage network
2. Network utilization on VLAN 20
3. NFS mount options (vers=4.2)

**Issue:** Cluster communication failure  
**Check:**
1. VLAN 10 configured on all nodes
2. Multicast enabled on switch
3. Corosync service running
4. Firewall not blocking UDP 5404-5405

---

## Network Diagrams

### Physical Cabling
```
[ER7206] ─── Port 1 ─── [Switch Port 1] (Uplink)
[Prox1]  ─── eth0   ─── [Switch Port 2] (Trunk: VLANs 1,10,20,923)
[Prox2]  ─── eth0   ─── [Switch Port 3] (Trunk: VLANs 1,10,20,923)
[Prox3]  ─── eth0   ─── [Switch Port 4] (Trunk: VLANs 1,10,20,923)
[TrueNAS]─── eth0   ─── [Switch Port 5] (Trunk: VLANs 1,20)
```

### Logical Network Flow
```
Internet → ER7206 → Switch → Proxmox Nodes → Containers
                  ↓
              TrueNAS (Storage)
```

---

**Last Updated:** 2026-03-21  
**Maintained By:** Infrastructure Team  
**Status:** Active - Production Network
