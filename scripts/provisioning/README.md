# Automated Container Provisioning Pipeline

**Purpose:** End-to-end automation for new container deployment  
**Created:** 2026-03-14  
**Status:** Active

---

## Overview

This pipeline automates the complete deployment process for new Proxmox LXC containers, including:

1. **Auto-assign CTID** - Automatically assigns next available CTID from appropriate range
2. **Proxmox LXC Creation** - Creates and starts container with specified resources
3. **Netbox IPAM Registration** - Registers VM, interface, and IP in Netbox
4. **NPM Reverse Proxy** - Creates proxy host entry with optional SSL
5. **DNS Registration** - Adds A record to AdGuard Home
6. **Monitoring Setup** - Installs node_exporter and promtail
7. **Backup Configuration** - Configures Proxmox backup schedule
8. **Documentation** - Generates deployment record

---

## Quick Start

### 1. Configure Environment

```bash
cd /Users/cory/Projects/homelab-nexus
cp .env.example .env
# Edit .env with your credentials
```

### 2. Basic Deployment

```bash
./scripts/provisioning/provision-container.sh \
  --name scrypted-nvr \
  --function utility \
  --ip 10.92.3.15
```

### 3. Full Deployment with Proxy

```bash
./scripts/provisioning/provision-container.sh \
  --name scrypted-nvr \
  --function utility \
  --ip 10.92.3.15 \
  --domain scrypted.cloudigan.net \
  --port 11443 \
  --ssl \
  --memory 4096 \
  --cores 2
```

---

## Function Categories & CTID Ranges

| Function | CTID Range | Description |
|----------|------------|-------------|
| `bot` | 100-109 | Bot & automation containers |
| `dev` | 110-119 | Development & testing |
| `media` | 120-129 | Media management stack |
| `core` | 130-139 | Core infrastructure |
| `network` | 140-149 | Network & proxy services |
| `monitoring` | 150-159 | Monitoring & observability |
| `storage` | 160-169 | Storage & backup |
| `security` | 170-179 | Security & access |
| `utility` | 180-189 | Utility services |

---

## Usage Examples

### Development Container
```bash
./scripts/provisioning/provision-container.sh \
  --name test-app \
  --function dev \
  --ip 10.92.3.50 \
  --memory 2048 \
  --cores 2
```

### Media Service
```bash
./scripts/provisioning/provision-container.sh \
  --name radarr \
  --function media \
  --ip 10.92.3.51 \
  --domain radarr.cloudigan.net \
  --port 7878 \
  --ssl
```

### Infrastructure Service
```bash
./scripts/provisioning/provision-container.sh \
  --name redis-cache \
  --function core \
  --ip 10.92.3.52 \
  --privileged \
  --memory 4096
```

### Utility Service (Scrypted Example)
```bash
./scripts/provisioning/provision-container.sh \
  --name scrypted-nvr \
  --function utility \
  --ip 10.92.3.15 \
  --domain scrypted.cloudigan.net \
  --port 11443 \
  --ssl \
  --memory 4096 \
  --cores 2 \
  --disk 32 \
  --privileged
```

---

## Command-Line Options

### Required
- `--name <name>` - Container hostname (e.g., scrypted-nvr)
- `--function <function>` - Function category (see table above)
- `--ip <ip>` - IP address (e.g., 10.92.3.15)

### Optional
- `--ctid <id>` - Specific CTID (auto-assigned if not provided)
- `--memory <MB>` - RAM in MB (default: 2048)
- `--cores <num>` - CPU cores (default: 2)
- `--disk <GB>` - Disk size in GB (default: 32)
- `--privileged` - Create privileged container (default: unprivileged)
- `--domain <domain>` - Domain for NPM proxy
- `--port <port>` - Backend port for NPM proxy (default: 80)
- `--ssl` - Enable SSL for NPM proxy

### Skip Options
- `--no-netbox` - Skip Netbox registration
- `--no-npm` - Skip NPM proxy creation
- `--no-dns` - Skip DNS registration
- `--no-monitoring` - Skip monitoring setup
- `--no-backup` - Skip backup configuration

### Other
- `--dry-run` - Show what would be done without executing
- `-h, --help` - Show usage information

---

## Pipeline Components

### 1. provision-container.sh
Main orchestration script that coordinates all deployment steps.

### 2. netbox-register.sh
Registers container in Netbox IPAM:
- Creates VM record
- Creates network interface
- Assigns IP address
- Sets DNS name

### 3. npm-create-proxy.sh
Creates NPM reverse proxy entry:
- Creates proxy host
- Configures forwarding
- Requests SSL certificate (if enabled)

### 4. dns-add-record.sh
Adds DNS A record to AdGuard Home.

### 5. install-monitoring.sh
Installs monitoring agents:
- node_exporter (port 9100)
- promtail (log shipping to Loki)

### 6. configure-backup.sh
Configures Proxmox backup schedule:
- Daily backups at 2:00 AM
- 7 daily, 4 weekly, 3 monthly retention
- Snapshot mode with zstd compression

---

## Post-Deployment

After deployment completes:

1. **SSH to container:**
   ```bash
   ssh root@<ip-address>
   ```

2. **Install application:**
   ```bash
   # Install Docker, configure services, etc.
   ```

3. **Verify monitoring:**
   - Check Grafana for new host
   - Verify metrics: `curl http://<ip>:9100/metrics`
   - Check Loki for logs

4. **Test proxy (if configured):**
   ```bash
   curl https://<domain>
   ```

5. **Update documentation:**
   - Add to `infrastructure-spec.md`
   - Add to `APP-MAP.md` (control plane)
   - Create service runbook if needed

6. **Review deployment record:**
   ```bash
   cat /tmp/ct<ctid>-deployment.md
   ```

---

## Troubleshooting

### Netbox Registration Fails
- Verify `NETBOX_TOKEN` in `.env`
- Check Netbox API is accessible: `curl http://10.92.3.11/api/`
- Verify cluster ID and site ID in script

### NPM Proxy Creation Fails
- Verify `NPM_PASSWORD` in `.env`
- Check NPM is accessible: `curl http://10.92.3.33:81`
- Verify domain is not already in use

### DNS Registration Fails
- Verify `ADGUARD_PASSWORD` in `.env`
- Check AdGuard is accessible: `curl http://10.92.3.10`

### Monitoring Installation Fails
- Check container has internet access
- Verify Loki URL is correct
- Check systemd services: `systemctl status node_exporter promtail`

### Backup Configuration Fails
- Verify Proxmox backup storage exists
- Check backup schedule: `pvesh get /cluster/backup`

---

## Standards Compliance

This pipeline enforces:

1. **Container Naming Convention** - `{function}-{role}[-{instance}]`
2. **CTID Range Assignment** - Auto-assigns from correct range
3. **Netbox IPAM** - All containers registered
4. **NPM Proxy** - Standardized reverse proxy setup
5. **DNS Registration** - Consistent DNS naming
6. **Monitoring** - All containers monitored
7. **Backups** - All containers backed up
8. **Documentation** - Deployment records generated

---

## Future Enhancements

- [ ] Terraform/Ansible integration
- [ ] Container templates (pre-configured stacks)
- [ ] Automated testing after deployment
- [ ] Rollback capability
- [ ] Multi-host support
- [ ] Custom resource profiles (small/medium/large)
- [ ] Integration with Uptime Kuma
- [ ] Automated SSL certificate renewal

---

**Last Updated:** 2026-03-14  
**Maintained By:** Infrastructure Team  
**Status:** Active - Ready for production use
