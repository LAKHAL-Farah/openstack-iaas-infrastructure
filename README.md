# OpenStack Lab — Vol 1: Infrastructure Foundation (automated)

| Node | ZeroTier IP | Notes |
|---|---|---|
| controller | 10.0.1.4 | 4 vCPU / 16 GB / 80 GB. Ansible control node |
| (VIP) | 10.0.1.5 | Reserved for Kolla HAProxy/Keepalived — assign to NOBODY |
| compute1 | 10.0.1.6 | 4 vCPU / 9 GB / 30 GB, nested virt ON, 2nd NIC on VMnet10 |
| storage | 10.0.1.7 | 4 vCPU / 8 GB / 20 GB OS + 15 GB Cinder + 15 GB Swift |

Edit `inventory/group_vars/all.yml` (network ID, NIC/disk names), then:

    # on controller
    ./scripts/controller-init.sh
    ZT_API_TOKEN=... ZT_NETWORK_ID=... ./scripts/zt-authorize.sh controller=<id> compute1=<id> storage=<id>
    ./scripts/distribute-keys.sh
    make sudoers      # once, asks the sudo password
    make all          # ping, baseline, network, storage, compute, preflight
