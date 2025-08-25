# Netbox IPAM Management Specification

## Netbox Infrastructure Details

### Service Information
- **Container ID**: 118
- **Hostname**: netbox-ipam
- **IP Address**: 10.92.3.18
- **Web Interface**: http://10.92.3.18:8000
- **Resources**: 2 cores, 2048MB RAM, 8GB storage
- **Storage**: hdd-pool:subvol-118-disk-0
- **Status**: Running and accessible

### Network Configuration
- **Bridge**: vmbr923
- **Gateway**: 10.92.3.1
- **MAC Address**: BC:24:11:7A:76:95
- **Subnet**: 10.92.3.0/24

## IPAM Management Strategy

### Current Network Topology in Netbox

#### Network Segments
1. **Management Network**: 10.92.0.0/23
   - Gateway: 10.92.0.1
   - DNS Server: 10.92.0.10
   - Proxmox Host: 10.92.0.5
   - Jump Host: 10.92.0.6

2. **Services Network**: 10.92.3.0/24
   - Gateway: 10.92.3.1
   - Docker Host: 10.92.3.2
   - All LXC containers: 10.92.3.3-10.92.3.18

### Device Categories for Netbox

#### Infrastructure Devices
1. **Hypervisors**
   - Proxmox Host (10.92.0.5)
   - Device Type: Proxmox VE
   - Role: Hypervisor
   - Platform: Debian Linux

2. **Network Infrastructure**
   - Virtual Bridges: vmbr920, vmbr923, vmbr924
   - DNS Server: 10.92.0.10
   - Gateway: 10.92.0.1, 10.92.3.1

#### Virtual Machines
3. **Production VMs**
   - Docker Host (docker-01): 10.92.3.2
   - Domain Controller (dc-01): Active Directory
   - Windows Workstations: alexa-win, aby-win, cory-win, kennedy-win, win10-test
   - Infrastructure: cloudy-renvis01

4. **Development/Test VMs**
   - veeam-worker (stopped)
   - Cloudy-Lab-* (stopped)

#### LXC Containers
5. **Media Management Stack**
   - Transmission (126): 10.92.3.9
   - SABnzbd (127): 10.92.3.16
   - Sonarr (125): 10.92.3.8
   - Radarr (124): 10.92.3.7
   - Readarr (120): 10.92.3.4
   - Bazarr (117): 10.92.3.15
   - Prowlarr (123): 10.92.3.6

6. **Infrastructure Services**
   - Netbox IPAM (118): 10.92.3.18
   - Nginx Proxy Manager (121): 10.92.3.3
   - AdGuard Home (113): 10.92.3.11
   - Jump Host (119): 10.92.0.6

7. **Monitoring & Management**
   - Homarr Dashboard (112): 10.92.3.10
   - Tautulli (116): 10.92.3.14
   - Overseerr (122): 10.92.3.5

8. **Utility Services**
   - FlareSolverr (115): 10.92.3.13
   - Cloudflare DDNS (114): 10.92.3.12

## Netbox Configuration Standards

### Device Roles
- **Hypervisor**: Proxmox hosts
- **Container Host**: Docker hosts
- **Media Server**: Download clients and media managers
- **Infrastructure**: DNS, proxy, monitoring services
- **Workstation**: End-user Windows machines
- **Network**: Switches, routers, virtual bridges

### Device Types
- **Proxmox VE**: Hypervisor platform
- **LXC Container**: Linux containers
- **Docker Container**: Containerized applications
- **Windows VM**: Windows virtual machines
- **Linux VM**: Linux virtual machines

### Platforms
- **Debian**: LXC containers and Proxmox
- **Ubuntu**: Specific LXC containers
- **Windows**: Windows VMs
- **Docker**: Containerized applications

### Custom Fields
1. **Container ID**: Proxmox container/VM ID
2. **Storage Pool**: Storage backend (hdd-pool, ssd2-lvm, etc.)
3. **CPU Cores**: Allocated CPU cores
4. **Memory MB**: Allocated memory in MB
5. **Storage GB**: Allocated storage in GB
6. **VPN Enabled**: Boolean for VPN-enabled services
7. **NFS Mount**: Boolean for NFS mount presence
8. **Service Port**: Primary service port
9. **Backup Status**: Backup configuration status

## IP Address Management Procedures

### New Container Deployment
1. **Pre-Deployment Planning**
   ```bash
   # Check available IPs in Netbox
   # Reserve IP address for new service
   # Document planned resource allocation
   ```

2. **IP Assignment Process**
   - Check Netbox for next available IP in 10.92.3.0/24
   - Reserve IP address with planned hostname
   - Add device entry with specifications
   - Deploy container with reserved IP
   - Update Netbox with actual deployment details

3. **Post-Deployment Validation**
   - Verify IP connectivity
   - Update Netbox with final configuration
   - Add service-specific custom fields
   - Document any special requirements (VPN, NFS, etc.)

### Container Migration Tracking
1. **Docker to LXC Migration**
   - Mark Docker container as "Decommissioning"
   - Create new LXC entry with "Planned" status
   - Track migration progress in Netbox comments
   - Update status to "Active" when migration complete
   - Archive Docker container entry

### Network Change Management
1. **IP Address Changes**
   - Update Netbox before making changes
   - Document reason for change
   - Validate no conflicts exist
   - Update DNS records if applicable

2. **Service Port Changes**
   - Update custom fields in Netbox
   - Document port conflicts
   - Update proxy configurations

## Automation Integration

### API Integration Points
1. **Proxmox Integration**
   ```python
   # Sync container inventory with Netbox
   # Update resource allocations
   # Track container lifecycle
   ```

2. **DNS Integration**
   ```python
   # Sync hostname/IP mappings
   # Update AdGuard Home configurations
   # Maintain reverse DNS records
   ```

3. **Monitoring Integration**
   ```python
   # Export device inventory for monitoring
   # Update service discovery configurations
   # Track service dependencies
   ```

### Automated Workflows
1. **Daily Sync Tasks**
   - Sync Proxmox container status
   - Update resource utilization
   - Validate IP assignments
   - Check for configuration drift

2. **Change Detection**
   - Monitor for new containers
   - Detect IP conflicts
   - Alert on unauthorized changes
   - Track resource exhaustion

## Backup and Recovery

### Netbox Data Protection
1. **Database Backups**
   - Daily automated backups
   - Store in multiple locations
   - Test restore procedures monthly

2. **Configuration Export**
   - Export device configurations
   - Backup custom field definitions
   - Document API tokens and integrations

### Disaster Recovery
1. **Service Restoration**
   - Restore Netbox container from backup
   - Validate database integrity
   - Restore API integrations
   - Verify network connectivity

2. **Data Validation**
   - Compare with Proxmox inventory
   - Validate IP assignments
   - Check service dependencies
   - Update any drift detected

## Reporting and Analytics

### Standard Reports
1. **IP Utilization**
   - Subnet usage statistics
   - Available IP ranges
   - Growth projections

2. **Resource Allocation**
   - CPU/Memory utilization by service type
   - Storage consumption trends
   - Container density analysis

3. **Service Dependencies**
   - Network service mapping
   - VPN-enabled services inventory
   - NFS mount dependencies

### Custom Dashboards
1. **Infrastructure Overview**
   - Total containers/VMs
   - Resource utilization
   - Service health status

2. **Migration Tracking**
   - Docker to LXC progress
   - Decommissioning timeline
   - Resource optimization opportunities

## Security and Access Control

### User Roles
1. **Administrator**: Full Netbox access
2. **Infrastructure**: Read/write for infrastructure objects
3. **Read-Only**: View-only access for reporting

### API Security
1. **Token Management**
   - Rotate API tokens regularly
   - Limit token permissions
   - Monitor API usage

2. **Network Security**
   - Restrict Netbox access to management network
   - Use HTTPS for web interface
   - Implement proper authentication

## Integration with Proxmox Infrastructure Spec

### Cross-Reference Points
1. **Container Inventory**: Sync with main infrastructure spec
2. **Network Configuration**: Maintain consistency with documented topology
3. **Service Dependencies**: Track relationships documented in main spec
4. **Change Management**: Follow validation rules from main spec

### Workflow Integration
1. **Before Infrastructure Changes**
   - Check Netbox for IP conflicts
   - Validate resource availability
   - Update planned changes

2. **After Infrastructure Changes**
   - Update Netbox with actual configuration
   - Validate against infrastructure spec
   - Document any deviations

This Netbox IPAM specification provides comprehensive management for the Proxmox infrastructure while maintaining consistency with the main infrastructure specification document.
