# OpenStack Lab (automated) - Vol 1 foundation + Vol 2 Kolla-Ansible cloud

| Node | Account | ZeroTier IP | Role |
|---|---|---|---|
| controller | controller@controller | 10.0.1.4 | control plane, Ansible + Kolla deploy host |
| (VIP) | - | 10.0.1.5 | Kolla internal VIP (HAProxy/Keepalived) - assigned to nobody |
| compute1 | compute1@compute1 | 10.0.1.6 | Nova compute + Neutron DHCP/L3/metadata/OVS (provider NIC) |
| storage | storage@storage | 10.0.1.7 | Cinder LVM, iSCSI, Glance NFS, (Swift disk) |

Vol 1:  ./scripts/controller-init.sh ; ./scripts/distribute-keys.sh ; make ping ; make sudoers ; make all
Vol 2:  make kolla-prepare kolla-config kolla-bootstrap kolla-prechecks kolla-pull kolla-deploy kolla-post cloud test-vm
Settings live in inventory/group_vars/all.yml - Kolla files are GENERATED from it, never hand-edited.
