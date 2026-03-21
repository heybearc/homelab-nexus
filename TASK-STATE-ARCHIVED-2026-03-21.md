# homelab-nexus Task State

**Last updated:** 2026-03-20 (12:09 PM)  
**Current branch:** main  
**Working on:** Scrypted NVR - Camera Recording Setup - ✅ COMPLETE

---

## Current Task
**Scrypted NVR - Camera Recording Setup** - ✅ COMPLETE

### What I'm doing right now
Completed Scrypted NVR setup with 4 Nest cameras, Google Device Access integration, 20TB TrueNAS NFS storage for recordings, motion detection, and automated backups. Fixed startup script to prevent configuration loss. System ready for production use with $50/year NVR license vs $156-300/year for Ring+Nest subscriptions. Ring doorbell integration deferred for later.

### Recent completions (2026-03-20)

**Scrypted NVR - Camera Recording Setup (Mar 20):**
- ✅ Installed Google Device Access plugin and configured OAuth credentials
- ✅ Connected 4 Nest cameras (Front Porch, Garage, Driveway, Backyard)
- ✅ Installed Scrypted NVR plugin ($50/year license purchased)
- ✅ Configured 20TB TrueNAS NFS storage at /mnt/recordings
- ✅ Set up NFS mount on Proxmox host with bind mount to container
- ✅ Fixed docker-compose.sh startup script (removed --force-recreate flag)
- ✅ Configured automated backups (Proxmox daily + database backup to TrueNAS)
- ✅ Configured motion detection recording for all cameras
- ✅ Cost analysis: $50/year vs $156-300/year for Ring+Nest subscriptions
- ✅ Verified remote access via https://scrypted.cloudigan.net
- 📝 Documentation: SCRYPTED-GOOGLE-NEST-SETUP.md, SCRYPTED-RECORDING-SETUP.md
- ⏳ Deferred: Ring doorbell integration (ready when needed)

**Cloudigan API - Stripe to Datto RMM Webhook Integration (Mar 17):**
- ✅ Deployed CT181 (cloudigan-api-blue) with HAProxy blue-green routing
- ✅ Implemented Stripe webhook handler for checkout.session.completed events
- ✅ Integrated Datto RMM API with Playwright OAuth automation
- ✅ Auto-refresh OAuth token (100-hour expiry, 1-hour safety buffer)
- ✅ Multi-platform download link generation (Windows, macOS, Linux)
- ✅ Wix CMS integration for customer download data storage
- ✅ Fixed Wix MCP authentication and site ID configuration
- ✅ Infrastructure: NPM SSL termination, HAProxy VIP routing, DNS configured
- ✅ Verified end-to-end: Stripe → Datto → Download Links → Wix CMS
- 📝 Documentation: CLOUDIGAN-WEBHOOK-INTEGRATION-COMPLETE.md, WIX-CMS-COLLECTION-SETUP.md
- ⏳ Pending: Wix thank-you page setup, optional SendGrid email integration

**Proxmox MCP Integration & CT180 Scrypted NVR (Mar 16):**
- ✅ Integrated Proxmox MCP server into Windsurf
- ✅ Deployed CT180 (Scrypted NVR) using official Proxmox installer
- ✅ Configured static IP 10.92.3.15/24 on vmbr0923
- ✅ DNS: scrypted.cloudigan.net → 10.92.3.3 (NPM)
- ✅ Netbox: Auto-registered via Proxmox→Netbox sync (VM ID 32)
- ✅ NPM reverse proxy: Proxy ID 81, SSL enabled
- ✅ Monitoring: node_exporter installed
- ✅ Backup: Daily at 02:00 configured
- ✅ Updated .env with Netbox token and NPM credentials
- ✅ Automation compliance: 7/8 components (87.5%)
- 📝 Documentation: CT180-SCRYPTED-DEPLOYMENT.md, CT180-AUTOMATION-STATUS.md

**TrueNAS Resilver Complete (Mar 9):**
- ✅ Resilver finished successfully (100.98%, 0 errors)
- ✅ Pool status: ONLINE
- ✅ New drive fully integrated and healthy
- ✅ 32TB processed with zero errors

**Cloudigan IT Solutions Repository (Mar 9):**
- ✅ Created new cloudigan repository for business operations
- ✅ Initialized git repository with governance structure
- ✅ Added Cloudy-Work submodule for standards
- ✅ Created directory structure (clients, services, operations, infrastructure, proposals, documentation)
- ✅ Created TASK-STATE.md and IMPLEMENTATION-PLAN.md
- ✅ Created GitHub repository (private) and pushed

---

## Recent Completions (Last 30 Days)

### 2026-03-13 — Infrastructure Maintenance
- Verified TrueNAS resilver complete (pool ONLINE, 0 errors)
- Verified all TrueNAS alerts cleared (no pool degraded or disk faulted alerts)
- Resolved VM 107 stuck reboot loop (killed stuck task, removed lock, force stopped)
- VM 107 ready for clean restart

### 2026-03-05 — TrueNAS Disk Replacement
- Identified failed drive location (Bay 2, serial ZJV28SCB)
- Verified new drive health (serial WV70FDPJ - Seagate Exos X12 enterprise SAS)
- SMART test passed with zero errors (0 power-on hours, brand new condition)
- Replaced failed drive in media-pool
- Resilver started successfully (0 errors, ~8-12 hours to complete)

### 2026-03-03 — Governance Sync
- Ran `/sync-governance` across all 5 repos
- Updated LDC Tools, BNI Chapter Toolkit, homelab-nexus submodules
- TheoShift and QuantShift already current
- All repos now at governance commit `64dc113` or later

---

## Recent Completions (Last 14 Days)

### 2026-02-23 to 2026-02-25 — Container Naming Convention Audit - Phase 3 Complete
- Batch 1 (Low Risk): CT119 sandbox-01 → bni-toolkit-dev
- Batch 2 (Infrastructure): CT100 quantshift-primary → quantshift-bot-primary
- Batch 2 (Infrastructure): CT101 quantshift-standby → quantshift-bot-standby
- Batch 3 (Final): CT113 adguard → adguard-dns (migrated to CT140)
- Batch 3 (Final): CT118 netbox → netbox-ipam (migrated to CT141)
- Batch 3 (Final): 3 additional containers renamed
- All DNS automation working (DC-01 + AdGuard)
- All Netbox IPAM records updated
- All infrastructure documentation updated
- Promoted 8 container renames to control plane
- Synced .cloudy-work submodule after promotions

**NPM Backup System:**
- Implemented automated NPM backup to TrueNAS NFS
- Analyzed 2.5 month backup gap
- Created NPM proxy hosts update plan
- Documented NPM container incident (CT121)
- Verified all proxy hosts operational

**Phase 3 Documentation:**
- Created Phase 3 rename session summary
- Created Phase 3 verification report
- Created NPM missing entries analysis
- Created promotion files for control plane sync
- Cleared promotion files after sync

---

## Recent Completions (Last 7 Days)

### 2026-02-21 — Infrastructure Resilience & Cleanup
- TrueNAS integration complete (SSH, API, Prometheus exporter)
- Netbox full buildout (25 VMs, IPs, physical layer, VLANs, services)
- Proxmox→Netbox sync automation (CT150, cron every 15min)
- HAProxy VRRP (VIP 10.92.3.33, CT136 MASTER + CT139 BACKUP)
- PostgreSQL streaming replica (CT131 → CT151, watchdog failover)
- Monitoring stack operational (Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma)
- Proxmox container cleanup (removed 4 unused containers: 130, 112, 117, 122)
- Promoted infrastructure cleanup documentation to control plane

---

## Next Steps

**Optional (Scrypted NVR):**
1. Add Ring doorbell to Scrypted (when ready)
   - Install @scrypted/ring plugin
   - Configure with Ring account credentials
   - Enable NVR recording with motion detection
2. Test camera recordings and verify storage usage
3. Optional: Install HomeKit plugin to expose cameras to Apple Home/Apple TV

**Optional (Cloudigan API):**
1. Update Stripe checkout success URL to include `?session={CHECKOUT_SESSION_ID}`
2. Set up Wix thank-you page with dynamic content (query CMS by session ID)
3. Optional: Add SendGrid email integration for backup delivery

**Optional (Low Priority):**
1. Complete CT121 → CT142 (nginx-proxy) migration
   - Migration plan exists: `documentation/CT121-NGINX-PROXY-MIGRATION-PLAN.md`
   - Expected downtime: 1-2 minutes
   - Not critical - CT121 works fine in current range

**Next Infrastructure Project (Choose One):**
1. **Automated Container Provisioning Pipeline** (High Priority)
   - MCP server now integrated and functional
   - Enhance with full end-to-end automation
   - Auto-assign CTID, Netbox registration, NPM proxy, DNS
   - Reduces deployment from 30+ min to <5 min

2. **Backup Automation for All Containers** (Medium Priority)
   - Extend NPM backup approach to all 25+ containers
   - Automated backup schedule, retention, verification

3. **Infrastructure-as-Code Templates** (Medium Priority)
   - Terraform/Ansible templates for container provisioning
   - Version-controlled infrastructure, repeatable deployments

4. **TrueNAS OS Update** (Medium Priority)
   - Pool healthy, resilver complete
   - Update to latest Fangtooth release

---

## Known Issues

**Affecting current work:**

None - All systems operational for development work.

**Infrastructure issues (see IMPLEMENTATION-PLAN.md for full list):**
- TrueNAS OS update pending (Fangtooth - safe to apply now that pool is healthy)
- Readarr service issues (non-critical)
- SABnzbd VPN configuration incomplete (non-critical)

---

## Exact Next Command

**For next session:**

```bash
# Run start-day to load context
/start-day
```

**Immediate Options:**

1. **Add Ring Doorbell to Scrypted** (Optional)
   - Install @scrypted/ring plugin in Scrypted
   - Configure with Ring account credentials
   - Enable NVR recording with motion detection
   - Test two-way audio and doorbell notifications

2. **Automated Container Provisioning Pipeline** (High Priority)
   - End-to-end automation for new container deployment
   - Auto-assign CTID, Netbox registration, NPM proxy, AdGuard DNS
   - Reduces deployment from 30+ min to <5 min

3. **Apply TrueNAS OS Update** (Medium Priority)
   - Pool is healthy, resilver complete, new drive stable (11 days)
   - Update: TrueNAS SCALE Fangtooth
   - Quick process via TrueNAS UI

4. **Backup Automation for All Containers** (Medium Priority)
5. **Infrastructure-as-Code Templates** (Medium Priority)
