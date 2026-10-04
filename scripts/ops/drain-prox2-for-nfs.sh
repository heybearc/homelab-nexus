#!/bin/bash
# Move prox2 guests to prox1 so the node can drop its NFS session.
# LXC live migration is not implemented on this cluster; --restart is a short stop/start.
set -u
echo "===== $(date -Is) drain prox2 start ====="
for id in 115 139 140 141 142 153 170 171 181 183 185 193 196 198 200; do
  echo "===== $(date -Is) ct $id ====="
  if timeout 240 pct migrate "$id" prox1 --restart; then
    echo "OK $id"
  else
    echo "FAIL $id"
  fi
done
echo "===== $(date -Is) vm 105 ====="
if timeout 300 qm migrate 105 prox1 --online; then
  echo "OK 105"
else
  echo "FAIL 105"
fi
echo "===== $(date -Is) drain prox2 done ====="
pct list
qm list
