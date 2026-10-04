#!/bin/bash
# Park prox1 guests that can leave. GPU and Postgres are handled separately.
set -u
echo "===== $(date -Is) drain prox1 movable start ====="
for id in 111 127 130 145 189 192; do
  echo "===== $(date -Is) ct $id ====="
  if timeout 240 pct migrate "$id" prox3 --restart; then
    echo "OK $id"
  else
    echo "FAIL $id"
  fi
done
bind_move() {
  id="$1"
  hostpath="$2"
  guestpath="$3"
  echo "===== $(date -Is) bind $id ====="
  if ! timeout 150 pct shutdown "$id" --timeout 90; then
    pct stop "$id"
  fi
  pct set "$id" --delete mp0
  if timeout 240 pct migrate "$id" prox3; then
    ssh -o BatchMode=yes -o ConnectTimeout=15 -o HostKeyAlias=prox3 \
      -o UserKnownHostsFile=/etc/pve/nodes/prox3/ssh_known_hosts \
      -o GlobalKnownHostsFile=none \
      root@10.92.0.7 "pct set $id --mp0 ${hostpath},mp=${guestpath} && pct start $id"
    echo "OK $id"
  else
    echo "FAIL $id"
  fi
}
bind_move 120 /mnt/pve/media-pool /mnt/data
bind_move 124 /mnt/pve/media-pool /mnt/data
bind_move 125 /mnt/pve/media-pool /mnt/data
bind_move 129 /mnt/pve/media-pool /mnt/data
bind_move 134 /mnt/pve/theoshift-uploads /mnt/theoshift-uploads
bind_move 190 /mnt/pve/tip-uploads /mnt/tip-uploads
echo "===== $(date -Is) vm 107 ====="
if timeout 600 qm migrate 107 prox3 --online; then echo "OK 107"; else echo "FAIL 107"; fi
echo "===== $(date -Is) vm 108 ====="
if timeout 600 qm migrate 108 prox3 --online; then echo "OK 108"; else echo "FAIL 108"; fi
echo "===== $(date -Is) drain prox1 movable done ====="
