# Promotion Complete

All Phase 3 final batch container renames have been promoted to the control plane.

**Promoted:** 5 containers (CT118, CT121, CT132, CT134, CT150)
**Updated:** APP-MAP.md with new container names, IPs, and infrastructure services
**Committed:** Control plane changes pushed to GitHub

## Decision: Specialized container deployment via vendor installers
**Type:** decision
**Target:** DECISIONS.md
**Affects:** infrastructure
**Date:** 2026-03-16

**Context:** Deployed CT180 (Scrypted NVR) using official Scrypted Proxmox installation script instead of custom MCP provisioning pipeline. Scrypted requires specific pre-configured container image, hardware passthrough (GPU/Coral), and optimized configuration that vendor installer handles automatically.

**Discovery/Decision:** For specialized containers with vendor-provided installers (Scrypted, Plex, etc.), use official installation scripts instead of generic provisioning pipeline. Backfill standard automation components (Netbox, NPM, DNS, monitoring, backups) after deployment.

**Rationale:** 
- Vendor installers provide production-ready configurations optimized for the application
- Hardware passthrough and special volumes are pre-configured correctly
- Pre-installed software eliminates complex setup steps
- Reduces deployment time and configuration errors
- Standard automation can be added post-deployment

**Impact:** 
- MCP provisioning pipeline remains for standard containers
- Specialized containers use vendor installers + automation backfill
- Document exceptions in deployment guides
- Automation scripts work independently for post-deployment integration

**Pattern:**
1. Deploy using vendor installer (e.g., Scrypted Proxmox script)
2. Backfill automation: DNS, Netbox, NPM, monitoring, backups
3. Document deployment method and any deviations

**References:** CT180-SCRYPTED-DEPLOYMENT.md, CT180-AUTOMATION-STATUS.md

Phase 3 container rename project: COMPLETE (8/8 containers)
