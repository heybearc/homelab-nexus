# MSP Platform - Entra ID SSO Compatibility Research

**Date:** 2026-03-21  
**Purpose:** Determine which MSP platform services support Microsoft Entra ID SSO  
**License:** Business Standard (has SSO capability via SAML/OIDC)

---

## Executive Summary

**Entra ID Business Standard Capabilities:**
- ✅ SAML 2.0 support
- ✅ OpenID Connect (OIDC) support
- ✅ Custom app registrations
- ✅ SSO for enterprise applications
- ❌ No advanced conditional access (requires P1)

**Compatibility Results:**
- **Native Entra ID Support:** 4/8 services (50%)
- **Authentik Required:** 4/8 services (50%)
- **Recommendation:** Hybrid approach (Entra ID + Authentik)

---

## Service-by-Service Analysis

### 1. Plane (Project Management) ✅ ENTRA ID COMPATIBLE

**SSO Support:** Yes - OIDC  
**Documentation:** https://docs.plane.so/self-hosting/authentication  
**Implementation:** Custom OIDC provider configuration

**Setup:**
1. Create app registration in Entra ID
2. Configure OIDC endpoints in Plane
3. Set redirect URIs
4. Map user attributes

**Entra ID App Registration:**
- **Name:** Cloudigan Plane
- **Redirect URI:** `https://plane.cloudigan.net/auth/callback`
- **Scopes:** `openid`, `profile`, `email`

**Plane Configuration:**
```env
OIDC_PROVIDER_NAME=Microsoft
OIDC_CLIENT_ID=<app-id>
OIDC_CLIENT_SECRET=<client-secret>
OIDC_ISSUER=https://login.microsoftonline.com/<tenant-id>/v2.0
OIDC_AUTHORIZATION_URL=https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
OIDC_TOKEN_URL=https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
OIDC_USERINFO_URL=https://graph.microsoft.com/oidc/userinfo
```

**Status:** ✅ Ready to implement

---

### 2. Zammad (Ticketing) ⚠️ REQUIRES AUTHENTIK

**SSO Support:** Yes - SAML 2.0, but complex configuration  
**Documentation:** https://docs.zammad.org/en/latest/settings/security/third-party.html  
**Issue:** Zammad's SAML implementation is complex and better suited for Authentik

**Why Authentik:**
- Zammad expects specific SAML attribute mappings
- Entra ID SAML requires custom claims configuration
- Authentik provides pre-built Zammad integration
- Easier to manage and troubleshoot

**Recommendation:** Use Authentik as SAML proxy  
**Status:** ⚠️ Use Authentik

---

### 3. BookStack (Documentation) ✅ ENTRA ID COMPATIBLE

**SSO Support:** Yes - SAML 2.0 and OIDC  
**Documentation:** https://www.bookstackapp.com/docs/admin/oidc-auth/  
**Implementation:** Native OIDC support

**Entra ID App Registration:**
- **Name:** Cloudigan BookStack
- **Redirect URI:** `https://bookstack.cloudigan.net/oidc/callback`
- **Scopes:** `openid`, `profile`, `email`

**BookStack Configuration:**
```env
AUTH_METHOD=oidc
OIDC_NAME=Microsoft
OIDC_DISPLAY_NAME_CLAIMS=name
OIDC_CLIENT_ID=<app-id>
OIDC_CLIENT_SECRET=<client-secret>
OIDC_ISSUER=https://login.microsoftonline.com/<tenant-id>/v2.0
OIDC_ISSUER_DISCOVER=true
```

**Status:** ✅ Ready to implement

---

### 4. Twenty CRM ⚠️ REQUIRES AUTHENTIK

**SSO Support:** Limited - OIDC support in development  
**Documentation:** https://twenty.com/developers/section/self-hosting/authentication  
**Issue:** SSO support is new and not fully mature

**Current State:**
- OIDC support added in v0.20+
- Limited documentation
- May have edge cases

**Recommendation:** Use Authentik for stability  
**Status:** ⚠️ Use Authentik (or wait for mature OIDC support)

---

### 5. Kimai (Time Tracking) ✅ ENTRA ID COMPATIBLE

**SSO Support:** Yes - SAML 2.0  
**Documentation:** https://www.kimai.org/documentation/saml.html  
**Implementation:** Native SAML support

**Entra ID App Registration:**
- **Name:** Cloudigan Kimai
- **Type:** Enterprise Application (SAML)
- **Identifier (Entity ID):** `https://kimai.cloudigan.net/auth/saml/metadata`
- **Reply URL:** `https://kimai.cloudigan.net/auth/saml/acs`

**Kimai Configuration:**
```yaml
# config/packages/kimai_saml.yaml
kimai:
    saml:
        activate: true
        title: Microsoft Login
        provider: azure
        connection:
            idp:
                entityId: 'https://sts.windows.net/<tenant-id>/'
                singleSignOnService:
                    url: 'https://login.microsoftonline.com/<tenant-id>/saml2'
                x509cert: '<certificate>'
```

**Status:** ✅ Ready to implement

---

### 6. Documenso (E-Signature) ⚠️ REQUIRES AUTHENTIK

**SSO Support:** Limited - OAuth2 support only  
**Documentation:** https://documenso.com/docs/self-hosting/authentication  
**Issue:** No native SAML/OIDC support yet

**Current State:**
- OAuth2 generic provider support
- No specific Entra ID integration
- Community-driven SSO development

**Recommendation:** Use Authentik as OAuth2 proxy  
**Status:** ⚠️ Use Authentik

---

### 7. n8n (Automation) ⚠️ REQUIRES AUTHENTIK

**SSO Support:** Yes - SAML 2.0 (Enterprise feature)  
**Documentation:** https://docs.n8n.io/hosting/authentication/saml/  
**Issue:** SAML SSO is an **Enterprise feature** (paid license required)

**Options:**
1. Purchase n8n Enterprise license (~$500/year)
2. Use Authentik for SSO
3. Use local authentication (admin only)

**Recommendation:** Use Authentik (n8n is internal tool, not customer-facing)  
**Status:** ⚠️ Use Authentik (avoid license cost)

---

### 8. Authentik (Identity Provider) N/A

**SSO Support:** N/A - This IS the identity provider  
**Purpose:** Provides SSO for services without native Entra ID support  
**Integration:** Can federate with Entra ID as upstream IdP

**Authentik Configuration:**
- Use Entra ID as upstream OIDC provider
- Authentik acts as SAML/OIDC proxy for downstream services
- Single sign-on flow: User → Entra ID → Authentik → Service

**Status:** ✅ Deploy as SSO proxy

---

## Recommended Architecture

### Hybrid SSO Approach

```
                    ┌─────────────────┐
                    │  Microsoft      │
                    │  Entra ID       │
                    │  (Business Std) │
                    └────────┬────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
         Direct OIDC/SAML          Federated Auth
                │                         │
    ┌───────────┴──────────┐    ┌────────┴────────┐
    │                      │    │                 │
┌───▼────┐  ┌──────▼──────┐  ┌─▼────────┐  ┌────▼─────┐
│ Plane  │  │  BookStack  │  │ Authentik│  │  Kimai   │
│ (OIDC) │  │   (OIDC)    │  │  (Proxy) │  │  (SAML)  │
└────────┘  └─────────────┘  └────┬─────┘  └──────────┘
                                   │
                        ┌──────────┼──────────┐
                        │          │          │
                   ┌────▼───┐ ┌───▼────┐ ┌──▼──────┐
                   │ Zammad │ │ Twenty │ │Documenso│
                   │ (SAML) │ │ (OIDC) │ │ (OAuth2)│
                   └────────┘ └────────┘ └─────────┘
```

**Flow:**
1. **Entra ID Native (4 services):**
   - Plane → Direct OIDC to Entra ID
   - BookStack → Direct OIDC to Entra ID
   - Kimai → Direct SAML to Entra ID
   - n8n → (Optional) Direct SAML if Enterprise license purchased

2. **Authentik Proxy (4 services):**
   - Authentik federates with Entra ID (upstream)
   - Zammad → SAML via Authentik
   - Twenty → OIDC via Authentik
   - Documenso → OAuth2 via Authentik
   - n8n → SAML via Authentik (if no Enterprise license)

---

## Implementation Plan

### Phase 1: Entra ID App Registrations (1 hour)

1. **Create App Registrations:**
   ```
   - Cloudigan Plane (OIDC)
   - Cloudigan BookStack (OIDC)
   - Cloudigan Kimai (SAML Enterprise App)
   ```

2. **Configure Redirect URIs:**
   - Plane: `https://plane.cloudigan.net/auth/callback`
   - BookStack: `https://bookstack.cloudigan.net/oidc/callback`
   - Kimai: `https://kimai.cloudigan.net/auth/saml/acs`

3. **Set API Permissions:**
   - `openid`
   - `profile`
   - `email`
   - `User.Read` (optional)

4. **Generate Client Secrets:**
   - Store in 1Password vault: `MSP-Platform-SSO`

---

### Phase 2: Deploy Authentik (2 hours)

1. **Create LXC Container:**
   ```bash
   ./scripts/provisioning/provision-container.sh \
     --name authentik \
     --function security \
     --ip 10.92.3.75 \
     --domain auth.cloudigan.net \
     --port 9000 \
     --ssl \
     --memory 4096 \
     --cores 2 \
     --disk 32
   ```

2. **Install Authentik:**
   - Use Docker Compose (Authentik requires Docker)
   - Configure PostgreSQL connection to CT131
   - Set up Redis for caching

3. **Configure Entra ID Federation:**
   - Add Entra ID as OIDC source in Authentik
   - Test authentication flow

4. **Create Authentik Applications:**
   - Zammad (SAML provider)
   - Twenty (OIDC provider)
   - Documenso (OAuth2 provider)
   - n8n (SAML provider)

---

### Phase 3: Service Configuration (4 hours)

**Direct Entra ID Services:**
1. Configure Plane OIDC
2. Configure BookStack OIDC
3. Configure Kimai SAML
4. Test authentication flows

**Authentik Proxy Services:**
1. Configure Zammad SAML via Authentik
2. Configure Twenty OIDC via Authentik
3. Configure Documenso OAuth2 via Authentik
4. Configure n8n SAML via Authentik
5. Test authentication flows

---

### Phase 4: User Provisioning (2 hours)

1. **Entra ID Users:**
   - Create user accounts in Entra ID
   - Assign to app registrations
   - Set up groups for role-based access

2. **Authentik Users:**
   - Users auto-created on first login (federated from Entra ID)
   - Configure attribute mappings
   - Set up groups and permissions

3. **Service-Level Permissions:**
   - Configure admin roles in each service
   - Map Entra ID groups to service roles
   - Test permission inheritance

---

## Security Considerations

### 1. Single Sign-On Benefits
- ✅ Centralized user management
- ✅ Single password for all MSP services
- ✅ Easier offboarding (disable in Entra ID)
- ✅ MFA enforcement at Entra ID level

### 2. Authentik Security
- ⚠️ Authentik becomes critical infrastructure
- ⚠️ If Authentik down, 4 services lose authentication
- ✅ Mitigation: High availability for Authentik
- ✅ Mitigation: Local admin accounts as backup

### 3. Session Management
- Configure session timeouts consistently
- Implement logout across all services
- Use secure cookies (SameSite, HttpOnly)

---

## Cost Analysis

### Entra ID Business Standard
- **Current:** Already owned
- **Cost:** $0 additional
- **Limitations:** No conditional access (requires P1)

### Authentik
- **License:** Free (open source)
- **Infrastructure:** 1 LXC container (4GB RAM, 2 cores)
- **Cost:** $0

### n8n Enterprise (Optional)
- **License:** ~$500/year for SAML SSO
- **Decision:** Skip, use Authentik instead
- **Savings:** $500/year

**Total Additional Cost:** $0

---

## Migration Path for Existing Apps

### Current Apps (NextAuth-based)
- TheoShift
- LDC Tools
- QuantShift
- BNI Chapter Toolkit

**Options:**
1. **Keep NextAuth** - No migration needed, separate auth
2. **Migrate to Entra ID** - Replace NextAuth with Entra ID OIDC
3. **Hybrid** - NextAuth for public users, Entra ID for admin/staff

**Recommendation:** Keep NextAuth for now, migrate later if needed

**Rationale:**
- NextAuth works well for current apps
- MSP platform is separate concern
- Avoid unnecessary migration complexity
- Can integrate later via Authentik if desired

---

## Testing Plan

### 1. Authentication Flow Testing
- [ ] Test Entra ID login for Plane
- [ ] Test Entra ID login for BookStack
- [ ] Test Entra ID login for Kimai
- [ ] Test Authentik federation with Entra ID
- [ ] Test Zammad login via Authentik
- [ ] Test Twenty login via Authentik
- [ ] Test Documenso login via Authentik
- [ ] Test n8n login via Authentik

### 2. Authorization Testing
- [ ] Test admin role assignment
- [ ] Test user role assignment
- [ ] Test group-based permissions
- [ ] Test cross-service access

### 3. Failure Scenarios
- [ ] Test Entra ID unavailable (should fail gracefully)
- [ ] Test Authentik unavailable (local admin access works)
- [ ] Test session timeout behavior
- [ ] Test logout across services

---

## Documentation Requirements

### For Each Service
1. SSO configuration guide
2. User provisioning procedure
3. Troubleshooting steps
4. Local admin access procedure (emergency)

### For Administrators
1. Entra ID app registration guide
2. Authentik configuration guide
3. User onboarding workflow
4. User offboarding workflow

---

## Rollback Plan

If SSO implementation fails:

1. **Immediate:** Enable local authentication on all services
2. **Short-term:** Use service-specific user accounts
3. **Long-term:** Re-evaluate SSO strategy

**Local Admin Accounts:**
- Maintain local admin account on each service
- Store credentials in 1Password
- Test monthly to ensure access

---

## Next Steps

1. ✅ Research complete (this document)
2. [ ] Review with user and get approval
3. [ ] Create Entra ID app registrations
4. [ ] Deploy Authentik container
5. [ ] Configure SSO for Phase 1 services (BookStack + Plane)
6. [ ] Test and validate
7. [ ] Roll out to remaining services
8. [ ] Document procedures
9. [ ] Train users

---

**Status:** Research complete, ready for implementation  
**Estimated Implementation Time:** 8-10 hours  
**Risk Level:** Low (proven technologies, fallback options available)
