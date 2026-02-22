# Promote to Control Plane

## Infrastructure: Proxmox Container Cleanup (Feb 21, 2026)
**Type:** infrastructure
**Target:** `_cloudy-ops/docs/infrastructure/`
**Affects:** homelab-nexus
**Date:** 2026-02-21

**Context:** Removed unused LXC containers from Proxmox infrastructure to free up resources and simplify management.

**Discovery/Change:**
Cleaned up 4 unused containers from Proxmox host:
- Audiobookshelf (ID: 130) - No longer needed, functionality not being used
- Homarr Dashboard (ID: 112) - Replaced by other monitoring solutions
- Bazarr (ID: 117) - Subtitle management not actively used
- Overseerr (ID: 122) - Request management not actively used

**Impact:**
- Container count reduced from 27 to 23 (15% reduction)
- Storage freed: ~25GB (estimated)
- Simplified infrastructure management
- Reduced resource overhead on Proxmox host

**Action Items:**
- Update infrastructure-spec.md to remove references to deleted containers
- Document remaining 23 containers and their purposes
- Consider further optimization opportunities

**References:**
- Proxmox Host: 10.92.0.5
- Container IDs removed: 130, 112, 117, 122
- Related systems still operational: Plex (128), Transmission (126)
