#!/usr/bin/env python3
"""Send one ARP request on an interface and print any reply. Sender IP is 0.0.0.0."""
import socket
import struct
import sys
import time

IFACE = sys.argv[1]
TARGETS = sys.argv[2:]


def if_mac(ifname):
    import fcntl
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    info = fcntl.ioctl(s.fileno(), 0x8927, struct.pack("256s", ifname.encode()[:15]))
    return info[18:24]


def probe(ifname, dst_ip):
    mac = if_mac(ifname)
    dst = socket.inet_aton(dst_ip)
    eth = b"\xff" * 6 + mac + struct.pack("!H", 0x0806)
    arp = struct.pack("!HHBBH6s4s6s4s", 1, 0x0800, 6, 4, 1, mac, b"\x00\x00\x00\x00", b"\x00" * 6, dst)
    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(0x0003))
    s.bind((ifname, 0))
    s.settimeout(1.5)
    s.send(eth + arp)
    found = []
    end = time.time() + 1.5
    while time.time() < end:
        try:
            data = s.recv(2048)
        except socket.timeout:
            break
        if len(data) < 42 or data[12:14] != b"\x08\x06":
            continue
        op = struct.unpack("!H", data[20:22])[0]
        if op != 2:
            continue
        spa = socket.inet_ntoa(data[28:32])
        sha = ":".join("%02x" % b for b in data[22:28])
        if spa == dst_ip:
            found.append(sha)
            break
    s.close()
    print(f"{ifname} {dst_ip} {'reply ' + found[0] if found else 'no-reply'}")


for target in sys.argv[2:]:
    probe(sys.argv[1], target)
