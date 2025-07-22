# Homelab Automation Scripts

This directory contains automation scripts for managing the Proxmox homelab infrastructure.

## Directory Structure

- `proxmox/` - Proxmox host management and VM/LXC operations
- `containers/` - LXC container management and configuration
- `networking/` - Network configuration, DNS, and VPN management
- `media-stack/` - Media server automation (Plex, SABnzbd, Sonarr, etc.)
- `maintenance/` - Backup, cleanup, and maintenance scripts

## Usage Guidelines

1. **Always test scripts in a safe environment first**
2. **Review credentials and IP addresses before execution**
3. **Update infrastructure spec after making changes**
4. **Use proper error handling and logging**

## Infrastructure Reference

All scripts should reference the infrastructure specification:
- Location: `../documentation/infrastructure-spec.md`
- Network: 10.92.3.0/24
- DNS: 10.92.0.10 (primary)
- Proxmox Host: 10.92.0.5

## Script Categories

### Proxmox Management
- `nvidia_driver_install.sh` - NVIDIA GPU driver installation
- `vm_analysis_template.sh` - VM analysis and configuration template
- `vm_fstab_config.sh` - VM storage and fstab configuration

### Container Management
- `dns_audit_fix.sh` - DNS configuration audit and repair
- `lxc_network_check.sh` - LXC network connectivity verification

### Media Stack
- `plex_claim.sh` - Plex server claiming automation
- `sabnzbd_usenet_fix.sh` - SABnzbd Usenet connectivity fixes
- `calibre_web_migration.sh` - Calibre-Web migration automation

### Networking
- `network_diagnosis.sh` - Comprehensive network troubleshooting
- `vpn_killswitch_setup.sh` - VPN killswitch configuration

### Maintenance
- `proxmox_cleanup.sh` - Proxmox host cleanup and maintenance
- `service_backup.sh` - Service configuration backup

## Contributing

When adding new scripts:
1. Use descriptive names and proper categorization
2. Include proper error handling and logging
3. Document script purpose and usage
4. Test thoroughly before committing
5. Update this README if adding new categories
