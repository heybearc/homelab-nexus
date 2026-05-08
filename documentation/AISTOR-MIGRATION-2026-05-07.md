# Nextcloud Object Store Migration: MinIO → AIStor

**Date executed:** 2026-05-07
**Operator:** Cursor agent (Claude) via `midclt` over SSH
**Host:** TrueNAS SCALE (`truenas` / `10.92.0.3`)
**Downtime:** ~5 minutes
**Result:** ✅ Success — Nextcloud back online, all data intact

---

## Why

TrueNAS deprecated the community **MinIO** app in April 2026 (see truenas/apps#3451) because upstream MinIO Community moved to source-only / maintenance mode. Nextcloud at `https://nextcloud.cloudigan.net` uses MinIO as its **primary** S3 object store — every uploaded file lives as a `urn:oid:<id>` object in bucket `nc-data` (1.1 TB / 137,336 objects). Nextcloud's `oc_filecache` table holds pointers into MinIO that must keep resolving, so a regression here is catastrophic.

See [DECISIONS.md → D-HOMELAB-003](../DECISIONS.md) for the option analysis.

---

## What we migrated to

**MinIO AIStor (Free tier)** — same company, same on-disk format, drop-in compatible.

- Image: `quay.io/minio/aistor/minio:RELEASE.2026-05-04T23-02-27Z`
- TrueNAS app: `aistor` (train `stable`, version `1.1.12`)
- Free tier: single-node, no capacity cap, suitable for homelab/personal use per MinIO's [Free agreement](https://www.min.io/legal/aistor-free-agreement).

---

## Pre-migration state

| Item | Value |
|---|---|
| TrueNAS app | `minio` (community v1.4.6) |
| Image | `minio/minio:...` |
| Data path on host | `/mnt/media-pool/minio` |
| Data ownership | uid:gid `473:473` (legacy `minio` user) |
| Bucket layout | `.minio.sys/`, `nc-data/` (137,336 entries, 1.1 TB), `nextcloud-data/` (empty), `plane-uploads/` (empty) |
| Network | `10.92.5.200:9000` (S3 API), `:9001` (console), bridge (host_ips bind) |
| Credentials | `admin` / `Cloudy_92!` |
| Nextcloud env | `OBJECTSTORE_S3_HOST=10.92.5.200`, `OBJECTSTORE_S3_PORT=9000`, `OBJECTSTORE_S3_BUCKET=nc-data`, `OBJECTSTORE_S3_KEY=admin`, `OBJECTSTORE_S3_SECRET=Cloudy_92!` (existing config preserved verbatim) |

---

## Execution steps (all via `midclt` from `truenas` shell)

### 1. Snapshots (rollback)

```bash
midclt call zfs.snapshot.create '{"dataset":"media-pool/minio","name":"pre-aistor-20260507","recursive":false}'
midclt call zfs.snapshot.create '{"dataset":"media-pool/ix-apps/app_mounts/nextcloud","name":"pre-aistor-20260507","recursive":true}'
```

Rollback (if ever needed):

```bash
midclt call zfs.snapshot.rollback '{"id":"media-pool/minio@pre-aistor-20260507","options":{"force":true}}'
```

### 2. Stop apps

```bash
midclt -q call -j app.stop nextcloud
midclt -q call -j app.stop minio
```

`app.stop` returns a job id; wait for completion. Confirm via `app.query`.

### 3. Chown data for the new app's run-as user

AIStor's TrueNAS app schema enforces `run_as.user >= 568` (the `apps` user). The legacy MinIO data was 473:473.

```bash
midclt -q call -j filesystem.chown '{
  "path":"/mnt/media-pool/minio",
  "uid":568,"gid":568,
  "options":{"recursive":true,"traverse":false}
}'
```

Took ~10 seconds for 137k entries (metadata only — no data movement).

### 4. Install AIStor

Build the values payload (the install JSON, with the license JWT inside):

```python
import json, os
values = {
  'aistor': {
    'root_user': 'admin',
    'root_password': 'Cloudy_92!',
    'license_key': os.environ['LIC'],   # AIStor Free JWT from SUBNET
    'additional_envs': [],
  },
  'run_as': {'user': 568, 'group': 568},
  'network': {
    'api_port': {'bind_mode':'published','port_number':9000,'host_ips':['10.92.5.200']},
    'console_port': {'bind_mode':'published','port_number':9001,'host_ips':['10.92.5.200']},
    'certificate_id': None,
    'networks': [],
    # NOTE: do NOT include dns_opts here — schema rejects it
  },
  'storage': {
    'data': {
      'type': 'host_path',
      'host_path_config': {'acl_enable': False, 'path': '/mnt/media-pool/minio'},
    },
    'additional_storage': [],
  },
  'labels': [],
  'resources': {'limits': {'cpus': 2, 'memory': 4096}},
}
payload = {
  'app_name': 'aistor',
  'catalog_app': 'aistor',
  'train': 'stable',
  'version': '1.1.12',
  'values': values,
}
open('/tmp/aistor_app_create.json','w').write(json.dumps(payload))
```

Run the install:

```bash
midclt -q call -j app.create "$(cat /tmp/aistor_app_create.json)"
```

Wait for the job to complete, then poll `app.query` until state is `RUNNING`.

### 5. Verify

```bash
curl -sS -o /dev/null -w '%{http_code}' http://10.92.5.200:9000/minio/health/live   # → 200
curl -sS -o /dev/null -w '%{http_code}' http://10.92.5.200:9001/                    # → 200
ls /mnt/media-pool/minio/nc-data | wc -l                                            # → 137336
```

### 6. Start Nextcloud

```bash
midclt -q call -j app.start nextcloud
```

Wait for `RUNNING`, then:

```bash
curl -sS -o /dev/null -w '%{http_code}' http://10.92.5.200:9002/login   # → 200
```

### 7. Cleanup

```bash
midclt -q call -j app.delete minio   # data on disk untouched
```

---

## Gotchas & footnotes

1. **`midclt` job-id capture**: `midclt -q call -j <method>` prints progress lines + the integer job id at the end. Capture with `grep -oE '^[0-9]+$' | tail -1`. Don't pipe through `awk` blindly — progress bars contain ANSI escapes.
2. **`network.dns_opts` is rejected** by the AIStor schema even though the legacy MinIO config exposes it. Drop it from the payload.
3. **License is required**. AIStor `RELEASE.2026-05-04` boots into *offline mode* (all S3 ops 403) without a valid license. Get the Free-tier JWT from <https://subnet.min.io>.
4. **uid 473** legacy data on disk is invisible to TrueNAS host — the user resolves to `UNKNOWN` because there's no host-side `minio` user account anymore. Chown was still needed for AIStor's `apps` user (568) to read it.
5. **`truenas_admin` does not have passwordless sudo or docker access.** Everything was done through `midclt` (the middleware API), which runs as root internally and accepts our admin's authenticated unix-socket session.
6. **Snapshots are cheap.** Both snapshots used 0 bytes at creation (CoW); they only grow as data diverges. Drop them after a week of stability.

---

## Outstanding follow-ups

- [ ] **NPM proxy header fix** for `nextcloud.cloudigan.net` (proxy host 46 on CT121). Currently missing `X-Forwarded-For`/`X-Forwarded-Proto`, which made every client share Nextcloud's bruteforce counter and triggered "Too many requests" lockouts. Logs show `uninitialized "trust_forwarded_proto"` warnings.
- [ ] **Rotate AIStor license JWT** — was pasted into agent chat. Re-download from SUBNET and update via UI or `midclt app.update aistor`.
- [ ] **Drop snapshots** after 7 days clean: `media-pool/minio@pre-aistor-20260507` and `media-pool/ix-apps/app_mounts/nextcloud@pre-aistor-20260507`.

---

## Recovery / rollback

If something goes wrong with AIStor in the next 7 days:

1. Stop AIStor: `midclt -q call -j app.stop aistor`
2. Rollback snapshot: `midclt call zfs.snapshot.rollback '{"id":"media-pool/minio@pre-aistor-20260507","options":{"force":true}}'`
3. Reinstall the old `minio` community app from the catalog (if still listed) and reconfigure it with host_path `/mnt/media-pool/minio`, ports 9000/9001, root credentials `admin` / `Cloudy_92!`, run_as 473:473.
4. Chown data back: `midclt -q call -j filesystem.chown '{"path":"/mnt/media-pool/minio","uid":473,"gid":473,"options":{"recursive":true}}'`
5. Start Nextcloud.

After the 7-day window passes and the migration is confirmed stable, the rollback path is gone (snapshots can be dropped).
