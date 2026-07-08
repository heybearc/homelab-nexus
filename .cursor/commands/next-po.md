# Next TD Synnex PO

Allocate the next purchase order number for TD Synnex and return **only** that PO — no extra commentary.

## Run

From the homelab-nexus repo root:

```bash
./scripts/procurement/next-synnex-po.sh
```

Use allocate mode (default). Do **not** use `--peek` unless the user explicitly asks to preview without consuming a number.

## Response format

Reply with a single line — the PO only, for example:

```
Cloud-PO-0020
```

## If it fails

- Counter not initialized → run `./scripts/procurement/next-synnex-po.sh --set 19` (or the user's last issued sequence number), then retry.
- Redis unreachable → mention `redis-shared` / SSH; script falls back via SSH when local `redis-cli` is missing.

## Related

- Preview without allocating: `./scripts/procurement/next-synnex-po.sh --peek`
- Show raw counter: `./scripts/procurement/next-synnex-po.sh --current`
