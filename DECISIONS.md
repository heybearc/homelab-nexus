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
