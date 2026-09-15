# Blue-green app Ansible (reusable)

**Playbook:** [`ansible/playbooks/deploy-bluegreen-app.yml`](../ansible/playbooks/deploy-bluegreen-app.yml)  
**Defaults:** [`ansible/group_vars/bluegreen_app_defaults.yml`](../ansible/group_vars/bluegreen_app_defaults.yml)  
**First consumer:** Quote Builder — [`ansible/group_vars/cloudigan_quote_builder_deploy.yml`](../ansible/group_vars/cloudigan_quote_builder_deploy.yml)

## What it does

1. Creates blue + green LXCs on `10.92.3.0/24` / `vmbr0923` (D-020) via `ansible-playbooks/.../deploy-proxmox-container.yml` on **`truenas-proxmox`** (D-HOMELAB-014)
2. Registers Netbox (when `NETBOX_TOKEN` set)
3. Installs Node 20 + PM2, stages app (`bg_src_local` or `bg_repo`), builds, starts PM2
4. Monitoring agents + `apps-registry.yaml` sync
5. HAProxy ACLs/backends + deployment-state JSON (blue LIVE initially)
6. Technitium A records: `app`, `blue.app`, `green.app` → VIP / node IPs

## Add a new app

1. Copy `group_vars/cloudigan_quote_builder_deploy.yml` → `group_vars/<app>_deploy.yml`
2. Set CTIDs/IPs (free on Proxmox), domain, PM2 names (`<app>-blue` / `<app>-green`, D-025), path, repo
3. Run:

```bash
cd ansible
ansible-playbook playbooks/deploy-bluegreen-app.yml -e @group_vars/<app>_deploy.yml
```

4. Add SSH Host aliases in `.cloudy-work/ssh_config_master.conf`
5. Register MCP in **both** control-plane copies of `homelab-blue-green-mcp/server.js` (homelab-nexus `.cloudy-work` **and** `Cloudy-Work/shared/...` — Cursor runs the Cloudy-Work path):
   - `deploymentStateFile` map
   - `APPS` entry
   - tool `enum` lists
   - `getMainRoutingAcl` if needed
6. Restart Cursor MCP (or kill the `server.js` process so Cursor respawns)
7. Remove app-repo `.no-auto-deploy` if present
8. Smoke: MCP `get_deployment_status` → `deploy_to_standby`
9. Operator: NPM proxy → HAProxy VIP `10.92.3.33:80` for public HTTPS

## Var contract

| Var | Purpose |
|-----|---------|
| `bg_app_id` | MCP id / registry id |
| `bg_domain` | Public hostname (e.g. `quotes.cloudigan.net`) |
| `bg_acl` | HAProxy ACL (default `is_<app_id with _>`) |
| `bg_blue` / `bg_green` | `{ name, ctid, ip, pm2_name }` |
| `bg_path` | Container app path |
| `bg_repo` / `bg_src_local` | Git URL and/or local stage path |
| `bg_deploy_type` | `nextjs` (default) or `node-service` |
| `bg_port` / `bg_health_path` | Listen port and HAProxy check path |

## Resume after partial run

If LXCs already exist and only HAProxy/DNS/monitoring remain:

```bash
cd ansible && ansible-playbook playbooks/finish-quote-builder.yml
```

(Adapt or delete once generalized; Quote Builder only.)

## Non-goals

- Does not rewrite HHV / chapter-hub / mail playbooks
- Does not create public NPM / external brand DNS (operator)
- Vaultwarden / non-Node stacks stay on dedicated playbooks
