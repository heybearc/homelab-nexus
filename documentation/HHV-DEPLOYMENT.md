# HHV Deployment

Helpful Hirsch Ventures site: **https://helpfulhirschventures.com**

| Item | Value |
|------|-------|
| App repo | https://github.com/heybearc/hhv |
| Containers | CT198 blue / CT199 green |
| Path | `/opt/hhv` |
| Port | 3001 |
| PM2 | `hhv-blue` / `hhv-green` |
| Ansible | `ansible/playbooks/deploy-hhv-containers.yml` |

The in-tree `hhv-website` Node placeholder was removed; deploy from `heybearc/hhv`. Health: `GET /health`.
