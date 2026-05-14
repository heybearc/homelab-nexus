# Architecture Decision Records

## D-CLOUDIGAN-001: Stripe-Datto Webhook Integration Architecture
**Date:** 2026-03-17
**Context:** Need automated Datto RMM site creation and agent download link delivery after Stripe checkout completion
**Decision:** Implemented webhook-based integration with dual delivery: Wix CMS for dynamic thank-you page + optional SendGrid email backup
**Consequences:** 
- Customers get immediate access to download links via dynamic page
- All customer download data stored in Wix CMS for future reference
- Datto OAuth token auto-refreshes every 100 hours via Playwright automation
- Infrastructure: CT181 container with HAProxy blue-green routing and NPM SSL termination

## D-CLOUDIGAN-002: Multi-Platform Download Link Generation
**Date:** 2026-03-17
**Context:** Customers need RMM agents for Windows, macOS, and Linux
**Decision:** Generate all three platform download links on every checkout, store in Wix CMS
**Consequences:** 
- Single webhook creates all platform links: `https://{platform}.rmm.datto.com/download-agent/{os}/{siteUid}`
- Customers can download for any platform without additional requests
- Thank-you page can display all options dynamically

## D-CLOUDIGAN-003: Wix CMS as Customer Download Registry
**Date:** 2026-03-17
**Context:** Need persistent storage for customer download links accessible from Wix site
**Decision:** Use Wix CMS collection "CustomerDownloads" with public read permissions
**Consequences:**
- Download links accessible via session ID from Stripe redirect
- Data persists for customer reference and support purposes
- Enables dynamic thank-you page without additional backend
- Field mapping: `dattoSiteUid`, `macOsDownloadLink` (capital O) required for Wix schema

## D-CLOUDIGAN-004: Datto OAuth Token Auto-Refresh Strategy
**Date:** 2026-03-17
**Context:** Datto OAuth tokens expire after 100 hours, manual refresh not scalable
**Decision:** Implemented automatic token refresh with 1-hour safety buffer using Playwright
**Consequences:**
- Token cached in `/opt/cloudigan-api/.datto-token.json`
- Every API call checks expiration, auto-refreshes if <1 hour remaining
- No manual intervention required for production operation
- Webhook remains operational 24/7 without downtime

## D-CLOUDIGAN-005: Authentik Identity Provider Branding & User Onboarding
**Date:** 2026-04-22
**Context:** Authentik needed Cloudigan branding and a scalable user onboarding system for staff/client access to internal apps
**Decision:** Custom brand at `auth.cloudigan.net` domain with Cloudigan logo/favicon; invitation-based enrollment with group auto-assignment from invite `fixed_data`
**Consequences:**
- Cloudigan branding applied to all auth flows (logo, favicon, "Welcome to Cloudigan!" titles)
- Three groups: `cloudigan-admins`, `cloudigan-staff`, `cloudigan-clients`
- Invites specify target group in `fixed_data: {"group": "cloudigan-staff"}` — expression policy assigns on enrollment
- TIP Generator access controlled via group bindings (admins + staff only)
- API token stored as `AUTHENTIK_API_TOKEN` in `.env` for programmatic invite creation
- Outpost "unhealthy" warning is cosmetic (WebSocket loopback) — non-blocking

## D-HOMELAB-001: TIP Generator Phased Rollout Strategy
**Date:** 2026-04-17
**Context:** Need AI-powered system to generate Technical Implementation Plans from customer discovery data and service orders
**Decision:** Build web application with phased rollout: v1 single-user → v2 team collaboration
**Consequences:**
- **v1 Focus:** Personal use with remote access, single reusable Word template, draft management
- **Template Intelligence:** Auto-detect structure, styles, colors from Word template on startup
- **AI Strategy:** Claude API with template-aware prompts for section-by-section generation
- **Tech Stack:** React + FastAPI + PostgreSQL (familiar, proven, scalable)
- **Authentication:** Authentik OAuth or M365 OAuth for remote access
- **v2 Expansion:** Team collaboration, blue-green deployment, multiple templates
- **Timeline:** 4 weeks for v1 (planning → deployment)
- **Plan Location:** `~/.windsurf/plans/tip-generator-webapp-424e2d.md`

## D-HOMELAB-003: Nextcloud Object Store Migration MinIO → AIStor (Free)
**Date:** 2026-05-07
**Context:** TrueNAS deprecated the community MinIO app in April 2026 because upstream MinIO transitioned to source-only/maintenance mode. Our Nextcloud instance (`10.92.5.200:9002`) uses MinIO as its **primary** S3 object store for ~1.1 TB / 137,336 objects in bucket `nc-data` (Nextcloud `oc_filecache` rows reference these by object key). A regression here breaks file access for all users.
**Decision:** Migrate to **MinIO AIStor (Free tier)** in-place against the existing on-disk data, keeping the same host path, ports, and root credentials so Nextcloud's stored S3 config required zero changes.
**Alternatives considered:**
- **SeaweedFS** — mature, Apache 2.0; rejected due to documented Nextcloud PROPFIND/dir-create instability with 100k+ objects.
- **Garage** — lovely but AGPLv3 and would have required full S3-to-S3 data migration (different on-disk format) for 1.1 TB.
- **VersityGW** — POSIX-on-S3 gateway changes storage semantics; not safe for an existing populated dataset.
- **RustFS** — too new for production data of this size.
**Consequences:**
- AIStor reuses the MinIO on-disk format → zero data movement; just remounted `/mnt/media-pool/minio` from `/export` → `/data` and chowned 473:473 → 568:568 for the AIStor `apps` user.
- Same `MINIO_ROOT_USER=admin` / same password / same `nc-data` bucket / same ports (9000 API, 9001 console) on `10.92.5.200` → Nextcloud `OBJECTSTORE_S3_*` env vars unchanged.
- Free-tier license is no-cost but **required** — without one, AIStor RELEASE.2026-05-04 boots in offline mode and blocks all S3 ops. License JWT is stored in the TrueNAS app config (`aistor.license_key`).
- Free tier limits: single-node only (fine for homelab), no multi-site replication, no object tiering, no `mc support`. Acceptable for our usage.
- Old `minio` app deleted from TrueNAS Apps; data preserved on disk + ZFS snapshot `media-pool/minio@pre-aistor-20260507` as rollback.
- Performed via `midclt` (TrueNAS middleware API) entirely from this agent — no UI clicks.
- **Migration runbook:** `documentation/AISTOR-MIGRATION-2026-05-07.md`.

## D-HOMELAB-004: Vaultwarden MSP HA — Primary + Backup, Not Active/Active
**Date:** 2026-05-12
**Context:** Plan to offer Vaultwarden as an MSP-style service on **`vault.cloudigan.com`** (`.com` branding) behind NPM and HAProxy, with redundancy expectations.
**Decision:** Use **one active Vaultwarden** at a time. HAProxy (or equivalent) routes to a **primary** backend with a **`backup`** peer and HTTP health checks on **`/alive`**. Standby holds replicated **PostgreSQL** (or promoted replica on failover) and replicated **`DATA_FOLDER`** / ZFS sync—**not** two independent writers serving the same logical instance concurrently.
**Alternatives considered:**
- **Round-robin / active-active to two Vaultwarden processes** — rejected: unsupported multi-writer semantics for Vaultwarden’s on-disk state + DB; high risk of corruption or subtle client bugs.
- **Single node + DR only** — acceptable **v1**; document RPO/RTO honestly if HA deferred.
**Consequences:**
- Marketing language should say **failover / DR**, not live/live clustering, unless architecture changes to a vendor-supported clustered Bitwarden deployment.
- **`DOMAIN`** must match the public URL users enter in Bitwarden (e.g. `https://vault.cloudigan.com`).
- White label remains **server-side** (SMTP, templates, web vault assets); clients stay Bitwarden-branded apps.

## D-HOMELAB-002: TIP Generator Template Management Approach
**Date:** 2026-04-17
**Context:** Word template needs to be reusable across projects with style preservation
**Decision:** Server-side template file with intelligent parsing, not per-project upload
**Consequences:**
- Single template stored at `/data/tip-generator/templates/active-template.docx`
- Template parsed on application startup to extract structure, styles, colors
- Section taxonomy cached for fast generation
- Template updates: replace file on server (v2: admin UI)
- AI generates content that preserves original template formatting
- Export clones template and populates with AI content
- Ensures consistent branding and styling across all generated TIPs
