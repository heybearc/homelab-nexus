# PostgreSQL Connection Tuning (CT131)

**Last updated:** 2026-06-03  
**Context:** `PostgresTooManyConnections` alerts when idle pool connections approached `max_connections = 100`.

## What we did

| Change | Value |
|--------|--------|
| `max_connections` (CT131) | **200** (`/etc/postgresql/17/main/postgresql.conf`) |
| Prisma apps `connection_limit` | **5** per process |
| Prisma apps `pool_timeout` | **10** seconds |

**Patched live** on: Chapter Hub (CT193/194), TIP Generator (CT190/191), TheoShift, LDC Tools, QuantShift, FactorPoint.

**Not Prisma-tuned (separate pools):** Zammad, Authentik, MSP Vaultwarden (CT171), n8n, Plane, Vikunja — still use their own defaults.

## Patch script (idempotent)

```bash
scripts/postgres/patch-prisma-connection-pool.sh /opt/your-app/.env 5 10
# Then restart the app (pm2 restart <name> --update-env, or systemctl restart …)
```

## Ansible (max_connections only)

```bash
cd ansible && ansible-playbook playbooks/configure-postgresql-connections.yml
```

Chapter Hub deploys pick up pool params via `chapter_hub_database_url` in `ansible/group_vars/chapter_hub_deploy.yml`.

## Verify

```bash
ssh postgresql 'sudo -u postgres psql -tAc "SHOW max_connections;"'
ssh postgresql 'sudo -u postgres psql -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY 1 ORDER BY 2 DESC;"'
```

## PgBouncer (optional, not deployed)

See homelab decision log when added. A pooler sits between apps and Postgres so many app connections multiplex onto fewer server backends.
