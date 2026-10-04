#!/bin/bash
# Move prox2 guest bridges from 1G eno1 onto 10G enp4s0f1.
# Reverts the live ports if connectivity checks fail. Does not rewrite ifupdown config.
set -u

revert() {
  ip link set enp4s0f1.923 nomaster 2>/dev/null || true
  ip link set eno1.923 up 2>/dev/null || true
  ip link set eno1.923 master vmbr0923 2>/dev/null || true
  ip link set enp4s0f1.924 nomaster 2>/dev/null || true
  ip link set eno1.924 up 2>/dev/null || true
  ip link set eno1.924 master vmbr0924 2>/dev/null || true
  ip link set enp4s0f1.925 nomaster 2>/dev/null || true
  ip link set eno1.925 up 2>/dev/null || true
  ip link set eno1.925 master vmbr0925 2>/dev/null || true
}

move_one() {
  old="$1"
  new="$2"
  br="$3"
  ip link set "$old" nomaster
  ip link set "$new" master "$br"
  ip link set "$new" up
  ip link set "$old" down
}

fail=0
move_one eno1.923 enp4s0f1.923 vmbr0923
move_one eno1.924 enp4s0f1.924 vmbr0924
move_one eno1.925 enp4s0f1.925 vmbr0925

echo "---MEMBERS---"
bridge link show | awk '/master vmbr092[345]|master vmbr0923|eno1.92|enp4s0f1.92/'

echo "---MTU---"
for i in vmbr0923 vmbr0924 vmbr0925 enp4s0f1 enp4s0f1.923; do
  echo -n "$i "
  cat /sys/class/net/$i/mtu
done

echo "---PING923---"
ping -c 2 -W 2 -I 10.92.3.206 10.92.3.1 || fail=1
ping -c 2 -W 2 -I 10.92.3.206 10.92.3.3 || fail=1

echo "---ARP---"
arp924=$(python3 /tmp/arp-probe.py vmbr0924 10.92.4.1)
arp925=$(python3 /tmp/arp-probe.py vmbr0925 10.92.5.1)
echo "$arp924"
echo "$arp925"
printf '%s\n' "$arp924" | grep -q ' reply ' || fail=1
printf '%s\n' "$arp925" | grep -q ' reply ' || fail=1

echo "---GUEST---"
guest_ip=$(pct exec 139 -- ip -4 -br addr show scope global | awk 'NR==1 {print $3}' | cut -d/ -f1)
echo "ct139=$guest_ip"
ping -c 2 -W 2 -I 10.92.3.206 "$guest_ip" || fail=1

if [ "$fail" -ne 0 ]; then
  echo REVERT
  revert
  exit 1
fi
echo MOVE_OK
