#!/bin/bash
# Park prox3 guests on prox2 so prox3 can drop its NFSv4 session.
set -u
echo "===== $(date -Is) drain prox3 start ====="
for id in 121 136 150 151 152 172 182 184 186 187 188 194 197 199 201 202; do
  echo "===== $(date -Is) ct $id ====="
  if timeout 240 pct migrate "$id" prox2 --restart; then
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
  if timeout 240 pct migrate "$id" prox2; then
    ssh -o BatchMode=yes -o ConnectTimeout=15 -o HostKeyAlias=prox2 \
      -o UserKnownHostsFile=/etc/pve/nodes/prox2/ssh_known_hosts \
      -o GlobalKnownHostsFile=none \
      root@10.92.0.6 "pct set $id --mp0 ${hostpath},mp=${guestpath} && pct start $id"
    echo "OK $id"
  else
    echo "FAIL $id"
  fi
}
bind_move 132 /mnt/pve/theoshift-uploads /mnt/theoshift-uploads
bind_move 191 /mnt/pve/tip-uploads /mnt/tip-uploads
echo "===== $(date -Is) vm 106 ====="
if timeout 300 qm migrate 106 prox2 --online; then
  echo "OK 106"
else
  echo "FAIL 106"
fi
echo "===== $(date -Is) drain prox3 done ====="
