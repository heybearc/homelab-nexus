# Control Plane Promotion Commit Guidelines

**Purpose:** Ensure control plane commits clearly distinguish between actual infrastructure changes and documentation-only updates  
**Last Updated:** 2026-02-23

---

## Commit Message Format

### Infrastructure Changes (Actual Physical Changes)

Use `infra()` prefix when promoting **actual infrastructure changes**:

```
infra(scope): brief description

INFRASTRUCTURE CHANGE - Not just documentation:
- List actual physical changes made to infrastructure
- Include systems affected (Proxmox, DNS, Netbox, etc.)
- Note verification performed

Control plane documentation updated to reflect actual infrastructure:
- List doc files updated
- Explain what changed in docs

Affects: [affected apps/repos]
Breaking: [Yes/No with explanation]
Testing: [testing requirements]

Infrastructure verified across N systems:
✓ System 1 (what was verified)
✓ System 2 (what was verified)

Promoted from: [source repo/file]
```

**Example:**
```
infra(ct119): container renamed from sandbox-01 to bni-toolkit-dev

INFRASTRUCTURE CHANGE - Not just documentation:
- Container CT119 physically renamed in Proxmox
- DNS A records updated on DC-01 (old removed, new added)
- Netbox IPAM records updated (VM name and IP DNS name)
- NPM proxy configuration verified (no changes needed)
- AdGuard DNS rewrites verified (none exist)

Control plane documentation updated to reflect actual infrastructure:
- APP-MAP.md: Container name sandbox-01 → bni-toolkit-dev
- development-contract.md: Container assignments updated
- sandbox-app-support.md: All references updated

Affects: BNI Chapter Toolkit (bni-chapter-toolkit repo)
Breaking: No (IP and public domain unchanged)
Testing: App verification tests should pass

Infrastructure verified across 5 systems:
✓ Proxmox (hostname, IP, status)
✓ DC-01 DNS (A records)
✓ NPM (proxy hosts)
✓ AdGuard (DNS rewrites)
✓ Netbox IPAM (VM and IP records)

Promoted from: homelab-nexus/PROMOTE-TO-CONTROL-PLANE.md
```

---

### Documentation-Only Changes

Use `docs()` prefix when **only updating documentation** with no infrastructure changes:

```
docs(scope): brief description

Documentation update only - no infrastructure changes.

Updated:
- List files changed
- Explain what was documented

Reason: [why docs were updated]
```

**Example:**
```
docs(bni-toolkit): add deployment troubleshooting guide

Documentation update only - no infrastructure changes.

Updated:
- Added troubleshooting section to D-024-IMPLEMENTATION-BNI-TOOLKIT.md
- Documented common PM2 restart issues
- Added database connection debugging steps

Reason: Support team requested troubleshooting reference
```

---

## When to Use Each Prefix

### Use `infra()` when:
- ✅ Container renamed/moved/created/destroyed
- ✅ DNS records added/removed/changed
- ✅ IP addresses changed
- ✅ Network configuration modified
- ✅ Services deployed/removed
- ✅ Database created/migrated
- ✅ Load balancer rules changed
- ✅ SSL certificates updated
- ✅ Firewall rules modified
- ✅ Any physical infrastructure change

**Key indicator:** If you had to SSH into a server or use an API to make a change, it's `infra()`

### Use `docs()` when:
- ✅ Adding new documentation
- ✅ Updating existing docs for clarity
- ✅ Fixing typos or formatting
- ✅ Adding examples or explanations
- ✅ Documenting existing (unchanged) infrastructure
- ✅ Creating runbooks or guides
- ✅ Updating comments or notes

**Key indicator:** If you only edited markdown files and didn't touch infrastructure, it's `docs()`

---

## Other Prefixes

### `feat()` - New Feature
```
feat(app): add new feature

Description of feature added to application code
```

### `fix()` - Bug Fix
```
fix(app): resolve issue with X

Description of bug and fix
```

### `chore()` - Maintenance
```
chore(submodule): sync governance updates

Description of routine maintenance
```

### `policy()` - Policy/Decision
```
policy(deployment): establish blue-green deployment standard

New policy or decision documented
```

---

## Examples from Real Promotions

### ✅ Good - Infrastructure Change
```
infra(ct101): container renamed from quantshift-standby to quantshift-bot-standby

INFRASTRUCTURE CHANGE - Not just documentation:
- Container CT101 physically renamed in Proxmox
- DNS A records updated on DC-01
- Netbox IPAM records updated
- HAProxy backend configuration verified

Control plane documentation updated to reflect actual infrastructure:
- APP-MAP.md: Updated container name and routing
- DECISIONS.md: Updated D-LOCAL-008 with new naming

Affects: QuantShift bot (quantshift repo)
Breaking: No (IP unchanged, HAProxy routes updated)
Testing: Bot should reconnect automatically

Infrastructure verified across 5 systems:
✓ Proxmox ✓ DC-01 DNS ✓ NPM ✓ AdGuard ✓ Netbox

Promoted from: homelab-nexus/PROMOTE-TO-CONTROL-PLANE.md
```

### ✅ Good - Documentation Only
```
docs(theoshift): document HAProxy health check configuration

Documentation update only - no infrastructure changes.

Updated:
- Added HAProxy health check section to theoshift-infrastructure.md
- Documented current health check endpoints
- Added troubleshooting for failed health checks

Reason: Team needed reference for health check behavior
```

### ❌ Bad - Ambiguous
```
docs(infrastructure): update CT119 container name from sandbox-01 to bni-toolkit-dev

Infrastructure change promotion from homelab-nexus:
- Container CT119 renamed as part of naming standardization
- Updated APP-MAP.md: container name and IP
```

**Problem:** Uses `docs()` prefix but describes actual infrastructure change. Should use `infra()` and clearly state "INFRASTRUCTURE CHANGE - Not just documentation"

---

## Checklist for Infrastructure Promotions

Before committing infrastructure changes to control plane:

- [ ] Used `infra()` prefix (not `docs()`)
- [ ] First line clearly states "INFRASTRUCTURE CHANGE - Not just documentation"
- [ ] Listed all actual physical changes made
- [ ] Listed all systems affected and verified
- [ ] Separated infrastructure changes from doc updates
- [ ] Specified affected apps/repos
- [ ] Noted if breaking change
- [ ] Included testing requirements
- [ ] Listed verification performed
- [ ] Referenced source promotion file

---

## Why This Matters

**For Operations:**
- Quickly identify actual infrastructure changes vs doc updates
- Understand scope of changes without reading full diff
- Track infrastructure evolution over time
- Audit trail for compliance

**For Development:**
- Know when infrastructure changed vs docs clarified
- Understand testing requirements
- Identify breaking changes
- Plan app updates accordingly

**For Governance:**
- Clear separation of concerns
- Proper change management
- Risk assessment
- Rollback planning

---

## Template for PROMOTE-TO-CONTROL-PLANE.md

When creating promotion files, clearly indicate if infrastructure changed:

```markdown
# [Infrastructure Change | Documentation Update]: Brief Title

**Date:** YYYY-MM-DD
**Type:** [Infrastructure Change | Documentation Update | Policy | Decision]
**Scope:** [what this affects]

---

## Summary

[Clear statement of what changed - infrastructure or docs]

---

## Infrastructure Changes (if applicable)

### Actual Physical Changes Made
- System 1: what changed
- System 2: what changed

### Systems Verified
- ✅ System 1 (what was verified)
- ✅ System 2 (what was verified)

---

## Control Plane Updates Needed

### Files to Update
1. **file1.md** - what to change
2. **file2.md** - what to change

---

## Testing Required

[What needs to be tested after promotion]

---
```

---

**Remember:** Infrastructure changes are significant events. Make them clearly visible in commit history.
