# justin-win11 (VM 105)

**Hostname:** `justin-win11`  
**VMID:** 105  
**OS:** Windows 11 23H2 (ISO install)  
**IP:** `10.92.4.3/24` on `vmbr0924` (VLAN 924), gw `10.92.4.1`  
**Domain:** `justin-win11.cloudigan.net`  
**Storage:** `truenas-proxmox` (TrueNAS NFS — required for new VMs)  
**Ansible:** `ansible/playbooks/deploy-windows11-vm.yml`

Netbox IP `10.92.4.3` is assigned to this workstation. Playbook creates/renames the QEMU guest and finishes IPAM + DNS.

---

## Wiring

| Layer | Value |
|-------|--------|
| Hypervisor | Proxmox QEMU, q35 + OVMF (Secure Boot) + TPM 2.0 |
| Disk | 128G on `truenas-proxmox` (NFS, migratable) |
| CPU / RAM | 4 cores, 16 GB |
| Guest resolver (set after OOBE) | Technitium `10.92.3.10` + `10.92.3.203` |
| DNS authority | Technitium zone `cloudigan.net` — A `justin-win11` → `10.92.4.3` |
| NPM | none (workstation, not an HTTP service) |
| SSH | `ssh justin-win11` after OpenSSH + `homelab_root` (D-HOMELAB-005) |

---

## Deploy / re-run

```bash
cd /Users/cory/Projects/homelab-nexus
set -a && source .env && set +a
cd ansible && ansible-playbook playbooks/deploy-windows11-vm.yml
```

DNS-only:

```bash
cd ansible && ansible-playbook playbooks/deploy-windows11-vm.yml --start-at-task 'Configure Technitium DNS'
```

---

## Operator steps (console install)

1. Open Proxmox console for VM 105 (`https://10.92.0.5:8006`).
2. Windows setup will not see the disk until VirtIO SCSI is loaded: **Load driver** → second CD (`virtio-win`) → `vioscsi\w11\amd64`.
3. Also install VirtIO NIC (`NetKVM\w11\amd64`) if Ethernet is missing.
4. After OOBE, set a static address:
   - IP `10.92.4.3/24`, gateway `10.92.4.1`
   - DNS `10.92.3.10`, `10.92.3.203`
5. Install **QEMU Guest Agent** from the VirtIO ISO (`guest-agent\qemu-ga-x86_64.msi`).
6. Install OpenSSH Server; put `homelab_root.pub` in `C:\ProgramData\ssh\administrators_authorized_keys` (one key per line).
7. Optional: domain-join `cloudigan.com` (DC-01). AD DNS for `.com` is separate from Technitium `.net`.
8. Optional: install [windows_exporter](https://github.com/prometheus-community/windows_exporter) on `:9182`, then set `windows-justin-win11` to `state: active` in `monitoring/apps-registry.yaml` and run `./scripts/monitoring/sync-monitoring-stack.sh`.

---

## Verify

```bash
ssh prox 'qm status 105; qm config 105 | grep -E "name:|ostype:|net0:|scsi0:|tpmstate0:"'
dig +short justin-win11.cloudigan.net @10.92.3.10   # expect 10.92.4.3
dig +short justin-win11.cloudigan.net @10.92.3.11   # via AdGuard filter — same
```

Netbox: VM `justin-win11` with primary IPv4 `10.92.4.3/24`.

---

**2026-09-02:** Initial Ansible deploy as `joel-win11`; renamed to `justin-win11` (Proxmox + Technitium + Netbox). Disks already on `truenas-proxmox`.
