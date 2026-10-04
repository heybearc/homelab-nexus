#!/bin/bash
# Return the guests that were parked on prox1 during the prox2 NFS cutover.
set -u
echo "===== $(date -Is) return prox2 start ====="
for id in 119 115 139 140 141 142 153 170 171 181 183 185 193 196 198 200; do
  echo "===== $(date -Is) ct $id ====="
  if timeout 240 pct migrate "$id" prox2 --restart; then
    echo "OK $id"
  else
    echo "FAIL $id"
  fi
done
echo "===== $(date -Is) vm 105 ====="
if timeout 300 qm migrate 105 prox2 --online; then
  echo "OK 105"
else
  echo "FAIL 105"
fi
echo "===== $(date -Is) return prox2 done ====="
