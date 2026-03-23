# Cloudigan MSP Platform - Governance Analysis & Decisions

**Date:** 2026-03-21  
**Status:** Planning Phase - Architectural Decisions In Progress  
**Criticality:** Business-Critical Production System

---

## Executive Summary

This document tracks the architectural analysis, governance conflicts, and decision-making process for the Cloudigan Unified Self-Hosted MSP Platform. This is a **business-critical system** that will serve as the operational backbone for Cloudigan IT Solutions.

**Key Principle:** We will address each architectural decision systematically, with full documentation and control plane governance compliance.

---

## Critical Decisions Made

### 1. Hosting Strategy ✅ DECIDED

**Decision:** Self-hosted on Proxmox homelab with planned expansion  
**Rationale:** Business accepts infrastructure risk for operational control and cost savings

**Current State:**
- Single Proxmox host at 10.92.0.5
- 28 existing containers
- TrueNAS for storage (10.92.0.3)

**Planned Upgrades (30 days):**
- Add 2 more Proxmox nodes (3-node cluster)
- Potential: Install Proxmox on TrueNAS as second host (needs evaluation)

**Risk Acceptance:**
- User acknowledges single point of failure risk
- Business continuity: Can operate if system down for extended period
- Kaseya monitoring for offsite backup coverage

**Action Items:**
- [ ] Document Proxmox cluster expansion plan
- [ ] Evaluate TrueNAS as Proxmox node (resource impact analysis)
- [ ] Design HA strategy for 3-node cluster
- [ ] Plan network topology for cluster

---

### 2. Identity Provider ✅ DECIDED

**Decision:** Microsoft Entra ID (Business Standard) with Authentik fallback  
**Status:** Research in progress

**User Confirmation:**
- **License Tier:** Business Standard (has SSO capability)
- **Current Usage:** SSO for Kaseya and other apps
- **App Registration:** Can create custom app registrations
- **Fallback:** Open to Authentik for services without Entra ID support

**Current State:**
- Existing M365 tenant with Entra ID Business Standard
- No current SSO implementation in homelab
- Existing apps use NextAuth (TheoShift, LDC Tools, QuantShift)

**Architecture Decision:**
- **Primary:** Entra ID for services with native SAML/OIDC support
- **Secondary:** Authentik (self-hosted) for services without Entra ID support
- **Custom App Registrations:** Create in Entra ID for MSP platform services

**Action Items:**
- [ ] Research Entra ID compatibility for each MSP service (IN PROGRESS)
- [ ] Design hybrid SSO architecture (Entra ID + Authentik)
- [ ] Plan migration path for existing NextAuth apps
- [ ] Document app registration process for MSP services
- [ ] Design Authentik deployment (if needed)

---

### 3. Deployment Pattern ✅ DECIDED

**Decision:** LXC + Ansible (Enhanced LXC Blue-Green Pattern)

**User Confirmation:**
- Confirmed LXC + Ansible approach
- Will add Ansible container to infrastructure (CT190-199 range)
- Question: Should Chef or Terraform be used as well?
- Requirement: Build Ansible playbooks for ALL existing deployed containers

**User Preference:**
- Prefers LXC over Docker (simpler networking, less complexity)
- Past Docker experience: Didn't like networking/configuration complexity
- Desires: Ability to spin up on demand if necessary
- Current pattern: Blue-green deployments with LXC containers

**Options to Evaluate:**

#### Option A: Continue LXC Blue-Green Pattern
**Pros:**
- Familiar, proven in current environment
- Simple networking (bridge mode)
- Low overhead
- Easy to understand and maintain

**Cons:**
- Manual deployment process
- No orchestration layer
- Difficult to scale horizontally
- No built-in service discovery
- Hard to implement "spin up on demand"

#### Option B: Docker Compose on LXC
**Pros:**
- Service orchestration without K8s complexity
- Easy multi-container deployments
- Better than raw Docker networking
- Can still use LXC as host

**Cons:**
- Still Docker networking complexity
- No auto-scaling
- Limited HA capabilities

#### Option C: Kubernetes (K3s/K8s)
**Pros:**
- True orchestration and auto-scaling
- Service discovery built-in
- Rolling updates and rollbacks
- Spin up on demand (HPA)
- Industry standard for multi-service platforms

**Cons:**
- Significant complexity increase
- Steep learning curve
- Overkill for small team?
- Resource overhead

#### Option D: Hybrid Approach (RECOMMENDED)
**Pros:**
- LXC for stateful services (databases, file storage)
- Docker Compose for MSP platform services
- Best of both worlds
- Gradual complexity increase

**Cons:**
- Mixed deployment patterns
- Need to maintain both skillsets

**Ansible vs Chef vs Terraform:**
- **Ansible:** ✅ RECOMMENDED - Agentless, simple, YAML-based, perfect for LXC provisioning
- **Chef:** ❌ NOT RECOMMENDED - Agent-based, Ruby DSL, overkill for this use case
- **Terraform:** ⚠️ COMPLEMENTARY - Good for infrastructure provisioning, but Ansible better for config management
- **Decision:** Use Ansible only, optionally add Terraform later for multi-cloud scenarios

**Action Items:**
- [ ] Deploy Ansible control node (CT190 or similar)
- [ ] Create Ansible playbooks for existing production containers
- [ ] Migrate existing provisioning scripts to Ansible
- [ ] Design Ansible inventory structure
- [ ] Create Ansible roles for common patterns (Node.js app, PHP app, etc.)
- [ ] Document Ansible deployment procedures

---

### 4. Timeline & Phasing ✅ DECIDED

**Decision:** Phased approach starting with anchor services

**User Statement:** "Start with the anchor of the system as is laid out in the above plan"

**Anchor Services (Phase 1):**
- BookStack (Documentation/Client Hub) - Primary navigation hub
- Plane (Project Management) - Execution layer
- Authentik/Entra ID (Identity) - SSO foundation

**Rationale:**
- BookStack = Central hub for all client information
- Plane = Core operational tool for task management
- Identity = Foundation for all other services

**Action Items:**
- [ ] Define detailed phase breakdown
- [ ] Identify dependencies between services
- [ ] Create implementation timeline
- [ ] Design rollout strategy per phase

---

### 5. Budget & Hardware Planning ✅ DECIDED

**Decision:** Self-hosted, no budget constraints for infrastructure

**Hardware Planning:**
- **Servers Ordered:** 2 additional Proxmox nodes arriving within 30 days
- **Network Topology:** User requested network topology design
- **Timeline:** 30-day window for cluster expansion

**User Statement:** "I am not worried about budget as I am self hosting this"

**Implications:**
- Can invest in hardware (Proxmox nodes, storage, networking)
- No cloud hosting costs
- Software: Open-source preferred, commercial licenses acceptable if needed
- Focus on operational efficiency over cost optimization

**Action Items:**
- [ ] Design 3-node Proxmox cluster network topology (IN PROGRESS)
- [ ] Document cluster configuration (HA, quorum, fencing)
- [ ] Plan storage strategy (Ceph vs NFS vs local)
- [ ] Design VLAN segmentation for cluster
- [ ] Identify any required commercial licenses
- [ ] Plan TrueNAS integration with cluster

---

## Database Strategy ✅ DECIDED

**Decision:** Upgrade existing PostgreSQL cluster (CT131/CT151)

**User Confirmation:**
- Confirmed: Upgrade existing PostgreSQL cluster
- Question: How does cluster operate? Can we upgrade replica first, switch traffic, then upgrade primary?
- Willing to stand up new cluster if needed, but prefer to use existing

**Current State:**
- PostgreSQL primary: CT131
- PostgreSQL replica: CT151
- Existing databases: ldc_tools, theoshift_scheduler, quantshift, bni_toolkit, netbox

**Required PostgreSQL Upgrade Strategy:**
- **Current Setup:** CT131 (primary) + CT151 (streaming replica)
- **Upgrade Approach:** Replica-first upgrade with traffic switch
- **Process:**
  1. Upgrade CT151 (replica) to new resources
  2. Promote CT151 to primary (switch traffic via HAProxy or app config)
  3. Upgrade CT131 (old primary)
  4. Demote CT131 to replica
  5. Switch back if desired, or keep CT151 as primary
- **Benefits:** Zero-downtime upgrade, rollback capability

**Action Items:**
- [x] Check current PostgreSQL resource usage (COMPLETED - see MSP-PLATFORM-DATABASE-ANALYSIS.md)
- [ ] Document replica-first upgrade procedure
- [ ] Test replica promotion process
- [ ] Plan traffic switch mechanism (application config vs HAProxy)
- [ ] Design database naming convention (follow D-011)
- [ ] Plan backup strategy extension

**MSP Platform Databases:**
1. ✅ `cloudigan_plane` - Project management (DEPLOYED - CT131)
2. `cloudigan_zammad` - Ticketing (PLANNED)
3. `cloudigan_bookstack` - Documentation (PLANNED)
4. `cloudigan_twenty` - CRM (PLANNED)
5. `cloudigan_kimai` - Time tracking (PLANNED - complements Plane)
6. `cloudigan_documenso` - E-signature (PLANNED)
7. `cloudigan_n8n` - Automation (PLANNED)
8. `cloudigan_authentik` - Identity (PLANNED - if not using Entra ID direct)

**Action Items:**
- [ ] Run resource analysis on CT131/CT151
- [ ] Calculate estimated database sizes
- [ ] Decide: Extend existing cluster vs new cluster
- [ ] Document database provisioning plan

---

## Secrets Management Strategy ✅ DECIDED

**Decision:** 1Password (vendor-hosted) + container-local .env files

**Architecture:**

### Client Secrets (1Password)
- Customer/client credentials
- Client system passwords
- Client API keys
- Managed via 1Password vaults (one per client)

### Platform Secrets (Container-Local)
- Service database credentials
- Inter-service API keys
- Internal system secrets
- Stored in `.env` files per container (existing pattern)

### Automation (n8n)
- n8n accesses 1Password via API for client secrets
- n8n uses environment variables for platform secrets
- Clear separation maintained

**Governance Compliance:**
- ✅ Follows Decision D-005 (container-local secrets)
- ✅ Follows Decision D-033 (database credentials in control plane)
- ✅ Maintains clear boundary: Client secrets ≠ Platform secrets

**Action Items:**
- [ ] Document 1Password API integration pattern
- [ ] Design n8n secret access workflows
- [ ] Create secret rotation strategy
- [ ] Document emergency access procedures

---

## Security & Compliance Responses

### 1. Data Sovereignty & Protection ✅ ADDRESSED

**User Response:**
- Self-hosted = full data control
- Protected by Kaseya RMM
- Business has appropriate insurance coverage

**Implications:**
- No third-party data processors
- Full GDPR/compliance control
- Kaseya provides monitoring layer

### 2. Backup & DR ✅ ADDRESSED

**User Response:**
- Plenty of storage space for backups
- Kaseya can serve as offsite backup solution

**Action Items:**
- [ ] Extend Proxmox backup strategy to MSP platform containers
- [ ] Configure Kaseya offsite backup replication
- [ ] Define RPO/RTO targets for MSP platform
- [ ] Document DR procedures

### 3. Access Control ✅ ADDRESSED

**User Response:**
- Small business, manageable manually
- n8n automation for onboarding workflows

**Action Items:**
- [ ] Design user onboarding automation (n8n)
- [ ] Document role-based access control model
- [ ] Create access provisioning workflows
- [ ] Plan for future team growth

### 4. Audit Logging ⚠️ FUTURE CONSIDERATION

**User Response:**
- Good question, track as platform grows

**Action Items:**
- [ ] Document audit logging requirements
- [ ] Identify services with built-in audit logs
- [ ] Plan centralized logging (future phase)
- [ ] Create audit log retention policy

### 5. Encryption ✅ NEEDS EVALUATION

**User Response:**
- Wants at-rest and in-transit encryption
- Needs to understand overhead

**Action Items:**
- [ ] Research encryption overhead for each service
- [ ] Design TLS/SSL strategy (Nginx Proxy Manager)
- [ ] Evaluate at-rest encryption options (LUKS, ZFS encryption)
- [ ] Document encryption architecture

### 6. Business Continuity & Acceptable Downtime ✅ DECIDED

**User Response:**
- **Acceptable Downtime:** 24 hours currently acceptable
- **Future:** Will need to decrease as business grows
- **Context:** Uses Zoho for invoicing/payments (separate system)
- **Customer Access:** Ticketing system desired, contract/agreement signing needed
- **Internal Tools:** Can operate if MSP platform down for extended period

**Implications:**
- **Current:** 24-hour RTO acceptable, allows for maintenance windows
- **Future:** Plan for <4 hour RTO as business scales
- **HA Strategy:** 3-node cluster provides redundancy without over-engineering
- **Priority Services:** Ticketing (Zammad) and e-signature (Documenso) most critical for customers

**Design Decisions:**
- Use 3-node Proxmox cluster for redundancy (when hardware arrives)
- PostgreSQL streaming replication for database HA
- HAProxy for load balancing and failover
- Good backups more important than complex HA initially
- Plan for future HA improvements as business grows

---

## Open Questions & Pushback

### 🚨 CRITICAL PUSHBACK: Proxmox on TrueNAS

**User Idea:** "Install Proxmox on TrueNAS to be a second host"

**My Strong Recommendation: DO NOT DO THIS**

**Reasons:**
1. **Resource Contention:** TrueNAS is your storage backend. Running VMs on it creates circular dependency.
2. **Single Point of Failure:** If TrueNAS fails, you lose both storage AND compute.
3. **Performance Impact:** TrueNAS optimized for storage, not virtualization.
4. **Complexity:** Nested virtualization or bare metal Proxmox on TrueNAS hardware?
5. **Best Practice Violation:** Separate storage and compute layers.

**Better Alternatives:**
- Purchase 2 dedicated Proxmox nodes (even low-cost mini PCs)
- Use TrueNAS purely for shared storage (NFS/iSCSI)
- Build proper 3-node Proxmox cluster with separate hardware

**Action Item:**
- [ ] Discuss hardware options for 2 additional Proxmox nodes

---

### 🚨 CRITICAL PUSHBACK: "Business Critical" + "Can Operate If Down"

**Contradiction Detected:**

You stated:
- "Business/production use and should be treated as critical"
- "Accessible anywhere in the world"
- "Can operate if system down for extended period"

**Question:** Which is it?

**Scenarios:**
- **Scenario A:** MSP platform is down for 24 hours. Can you:
  - Access client documentation?
  - Track project tasks?
  - Respond to support tickets?
  - Bill for time worked?

- **Scenario B:** MSP platform is down for 1 week. Impact on business operations?

**Recommendation:**
- Define "business-critical" more precisely
- Set acceptable downtime thresholds
- Design HA strategy accordingly
- Don't over-engineer if truly non-critical

**Action Item:**
- [ ] Define precise uptime requirements and acceptable downtime

---

### ⚠️ QUESTION: Entra ID Licensing

**Current Unknown:** What Entra ID license tier do you have?

**License Tiers:**
- **Free:** Basic auth, no SSO
- **P1 ($6/user/month):** SSO, conditional access, MFA
- **P2 ($9/user/month):** Advanced features

**For SSO to work, you need P1 minimum.**

**Action Item:**
- [ ] Confirm current Entra ID license tier
- [ ] Evaluate cost if upgrade needed
- [ ] Consider Authentik as free alternative

---

### ⚠️ QUESTION: MSP Service Compatibility

**Unknown:** Do all proposed services support Entra ID SSO?

**Services to Research:**
1. Plane - SAML/OIDC support?
2. Zammad - SSO support?
3. BookStack - SAML/OIDC support?
4. Twenty CRM - SSO support?
5. Kimai - SSO support?
6. Documenso - SSO support?
7. n8n - SSO support?

**Action Item:**
- [ ] Research SSO compatibility for each service
- [ ] Document fallback auth strategy for unsupported services

---

## Next Steps - Prioritized

### Immediate (This Week)
1. ✅ Document user decisions (this file)
2. [ ] Analyze PostgreSQL cluster capacity
3. [ ] Research deployment pattern options (LXC vs Docker vs K3s)
4. [ ] Research Entra ID SSO compatibility for each MSP service
5. [ ] Define precise uptime requirements

### Short-Term (Next 2 Weeks)
6. [ ] Make deployment pattern decision
7. [ ] Design database strategy
8. [ ] Create detailed architecture document
9. [ ] Plan Proxmox cluster expansion (hardware specs)
10. [ ] Design Phase 1 implementation plan

### Medium-Term (Next 30 Days)
11. [ ] Implement Phase 1 (BookStack + Plane + Identity)
12. [ ] Deploy 2 additional Proxmox nodes
13. [ ] Configure Proxmox cluster HA
14. [ ] Extend backup strategy to MSP platform

---

## Decision Log

| Date | Decision | Rationale | Status |
|------|----------|-----------|--------|
| 2026-03-21 | Self-hosted on Proxmox | Operational control, cost savings | ✅ Decided |
| 2026-03-21 | Use Entra ID for SSO | Existing M365 tenant | ⚠️ Pending research |
| 2026-03-21 | Phased rollout approach | Risk mitigation, incremental value | ✅ Decided |
| 2026-03-21 | No budget constraints | Self-hosted infrastructure | ✅ Decided |
| 2026-03-21 | 1Password + .env secrets | Separation of client/platform secrets | ✅ Decided |
| 2026-03-21 | Deployment pattern | TBD - needs evaluation | ⚠️ Pending |
| 2026-03-21 | Database strategy | TBD - needs capacity analysis | ⚠️ Pending |

---

## Files to Create

1. `MSP-PLATFORM-ARCHITECTURE.md` - Detailed technical architecture
2. `MSP-PLATFORM-DEPLOYMENT-PATTERN.md` - Deployment strategy analysis
3. `MSP-PLATFORM-DATABASE-DESIGN.md` - Database architecture
4. `MSP-PLATFORM-PHASE1-PLAN.md` - Phase 1 implementation plan
5. ADR: `D-MSP-001` - MSP Platform Hosting Strategy
6. ADR: `D-MSP-002` - MSP Platform Deployment Pattern
7. ADR: `D-MSP-003` - MSP Platform Identity Provider

---

**Status:** Analysis complete, awaiting deployment pattern decision and database capacity analysis.
