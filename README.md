# OpenStack Lab - Vol 1: Infrastructure Foundation (automated)

| Node | Account | ZeroTier IP | Notes |
|---|---|---|---|
| controller | controller@controller | 10.0.1.4 | 4 vCPU / 16 GB / 80 GB. Ansible control node |
| (VIP) | - | 10.0.1.5 | Reserved for Kolla HAProxy/Keepalived - assign to NOBODY |
| compute1 | compute1@compute1 | 10.0.1.6 | 4 vCPU / 9 GB / 30 GB, nested virt ON, 2nd NIC on VMnet10 |
| storage | storage@storage | 10.0.1.7 | 4 vCPU / 8 GB / 20 GB OS + 15 GB Cinder + 15 GB Swift |

Edit `inventory/group_vars/all.yml` (network ID, NIC/disk names), then, on the controller:

    ./scripts/controller-init.sh
    ./scripts/distribute-keys.sh     # ZeroTier already authorized + IPs set by hand in Central
    make ping
    make sudoers                     # once, prompts per node
    make all                         # baseline, network, storage, compute, preflight
