# GitHub Verification Procedures

## Overview
This document outlines the verification steps required before performing any GitHub repository operations to ensure proper authentication and connectivity.

## Pre-Requisites
- Personal Access Token (PAT) configured in `~/.git-credentials`
- GitHub account: `heybearc`
- Account ID: 97983672

## Verification Steps

### 1. GitHub API Connectivity Test
Before any repository operations, verify GitHub API connectivity:

```bash
# Test GitHub API connectivity using stored PAT
curl -H "Authorization: token $(cat ~/.git-credentials | grep github | cut -d: -f3 | cut -d@ -f1)" https://api.github.com/user
```

**Expected Response:**
- Status: 200 OK
- Login: `heybearc`
- Account type: `User`
- Private repos available

### 2. Repository Access Verification
Verify access to existing repositories:

```bash
# List user repositories
curl -H "Authorization: token $(cat ~/.git-credentials | grep github | cut -d: -f3 | cut -d@ -f1)" https://api.github.com/user/repos
```

### 3. Authentication Status Check
Verify current authentication status:

```bash
# Check current git configuration
git config --global user.name
git config --global user.email
git config --list | grep credential
```

## Account Information
- **Username**: heybearc
- **Account ID**: 97983672
- **Plan**: Free (10,000 private repos available)
- **Current Usage**: 8 private repos, 3 public repos
- **Disk Usage**: ~1GB

## Troubleshooting

### PAT Issues
If authentication fails:
1. Check PAT expiration date
2. Verify PAT scopes include `repo` permissions
3. Regenerate PAT if necessary
4. Update `~/.git-credentials` with new token

### Connectivity Issues
If API calls fail:
1. Check internet connectivity
2. Verify GitHub service status
3. Test with basic curl to github.com
4. Check firewall/proxy settings

## Security Notes
- Never commit PAT tokens to repositories
- Use environment variables or credential managers
- Regularly rotate PAT tokens
- Monitor account access logs

## Automation Integration
This verification should be integrated into:
- Repository creation scripts
- Automated deployment pipelines
- Infrastructure automation tools
- Backup and sync procedures

---

*Last Updated: 2025-07-11*
*Verified: GitHub API connectivity successful*
