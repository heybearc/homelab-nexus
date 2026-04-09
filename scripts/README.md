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

### n8n Automation
- `n8n-api-client.py` - Python client for n8n API interaction
- `n8n-workflow-examples.py` - Pre-built workflow templates for homelab tasks

**n8n Quick Start:**
```bash
# Test connection
python scripts/n8n-api-client.py test-connection

# List workflows
python scripts/n8n-api-client.py list-workflows

# View workflow templates
python scripts/n8n-workflow-examples.py
```

See `@/Users/cory/Projects/homelab-nexus/documentation/N8N-API-INTEGRATION.md` for full documentation.

### Vikunja Task Management
- `vikunja-api-client.py` - Python client for Vikunja API interaction

**Vikunja Quick Start:**
```bash
# Test connection
python scripts/vikunja-api-client.py test-connection

# List projects
python scripts/vikunja-api-client.py list-projects

# List tasks
python scripts/vikunja-api-client.py list-tasks

# Create task
python scripts/vikunja-api-client.py create-task <project-id> "Task title"
```

See `@/Users/cory/Projects/homelab-nexus/documentation/VIKUNJA-API-INTEGRATION.md` for full documentation.

### LibreTranslate Translation
- `libretranslate-api-client.py` - Python client for LibreTranslate API interaction

**LibreTranslate Quick Start:**
```bash
# Test connection
python scripts/libretranslate-api-client.py test-connection

# List supported languages
python scripts/libretranslate-api-client.py languages

# Translate text
python scripts/libretranslate-api-client.py translate "Hello world" en es

# Detect language
python scripts/libretranslate-api-client.py detect "Bonjour"
```

See `@/Users/cory/Projects/homelab-nexus/documentation/LIBRETRANSLATE-API-INTEGRATION.md` for full documentation.

## Contributing

When adding new scripts:
1. Use descriptive names and proper categorization
2. Include proper error handling and logging
3. Document script purpose and usage
4. Test thoroughly before committing
5. Update this README if adding new categories
