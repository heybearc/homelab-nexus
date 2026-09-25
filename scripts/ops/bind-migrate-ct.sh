#!/bin/bash
# Migrate an LXC that has a host bind mount. PVE will not migrate while mp0 is set.
# Run on the source node.
# Usage: bind-migrate-ct.sh <vmid> <dest> <hostpath> <guestpath>
set -u
id="$1"
dest="$2"
hostpath="$3"
guestpath="$4"
timeout="${5:-120}"
ssh_dest() {
  ssh -o BatchMode=yes -o ConnectTimeout=15 \
    -o HostKeyAlias="$dest" \
    -o UserKnownHostsFile="/etc/pve/nodes/${dest}/ssh_known_hosts" \
    -o GlobalKnownHostsFile=none \
    "root@${dest}" "$@"
}

echo "===== $(date) bind-migrate $id -> $dest mp=$hostpath:$guestpath ====="
if ! pct shutdown "$id" --timeout "$timeout"; then
  pct stop "$id"
fi
pct set "$id" --delete mp0
pct migrate "$id" "$dest"
ssh_dest "pct set $id --mp0 ${hostpath},mp=${guestpath}"
ssh_dest "pct start $id"
echo "OK $id"
