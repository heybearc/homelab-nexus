# Offboard an app

Remove one homelab app completely. Invoke as `/offboard <app-id>`.

## Run

From the homelab-nexus repo root, dry-run first, then apply:

```bash
./scripts/ops/offboard-app.sh <app-id> --fqdn <published-name> --database <db-or-omit>
./scripts/ops/offboard-app.sh <app-id> --fqdn <published-name> --database <db-or-omit> --apply
```

`<app-id>` is the `id` in `monitoring/apps-registry.yaml`. Add `--fqdn` once per name (`auth.cloudigan.net` and `authentik.cloudigan.net`). Add `--database` only when the app has its own database on the Postgres VIP.

The script stops the container, then removes:

- Technitium A and CNAME records
- the NPM proxy host, its nginx file, and a certificate used only by that host
- the NetBox VM, interface, and IP
- Uptime Kuma monitors for the name, URL, or IP
- the registry entry, then redeploys Prometheus, Alertmanager, and Watchdog
- the vzdump job and `vzdump-lxc-<ctid>` archives
- Proxmox snapshots, then the container and its disk
- the app section in `.cloudy-work/_cloudy-ops/context/APP-MAP.md`
- the container id in `scripts/ops/patch-cadence.sh`
- the named Postgres database on the primary

## After the script

1. Public DNS. If `dig NS <zone>` is `*.wixdns.net`, read the Wix zone and delete only that host's record. Show the before/after table and wait for yes before the write. Do not change the apex or `www`.
2. Search the other guests for a live config that still calls the app. Backup copies can go. Do not change a live login that points somewhere else.
3. Say what is left in old docs. Do not rewrite history files unless they are an operational map.

## Do not

- Drop a shared database.
- Delete a certificate that another proxy host still uses.
- Destroy a container that is not the registry `ctid`.
