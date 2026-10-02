# 02 — OpenStack services

Every service runs as a container managed by Kolla-Ansible. Images come from the `openstack.kolla` registry (`2024.2-ubuntu-noble`).

## Core services

| Service | Role | Runs on | Notes |
|---|---|---|---|
| **Keystone** | Identity: users, projects, roles, tokens, and the service catalogue | controller | Every other service authenticates against it. Fernet keys are distributed by `keystone_fernet` |
| **Glance** | Image registry | controller | File backend on an NFS share exported by the storage node |
| **Nova** | Compute | | |
| ├ nova-api | Public compute API | controller | Fronted by HAProxy |
| ├ nova-scheduler | Chooses a host for each instance | controller | Uses Placement data |
| ├ nova-conductor | Database proxy for compute nodes | controller | Compute nodes never talk to MariaDB directly |
| ├ nova-novncproxy | Browser console access | controller | |
| └ nova-compute + libvirt | Runs the VMs | compute1 | KVM with nested virtualisation |
| **Placement** | Tracks resource inventories and usage | controller | Used by the scheduler |
| **Neutron** | Networking | | |
| ├ neutron-server | API and plugin logic | controller | |
| ├ OVS agent + Open vSwitch | Builds `br-int`, `br-tun`, `br-ex`; VXLAN tunnels | compute1 | `br-ex` carries the provider NIC |
| ├ L3 agent | Routers, SNAT, floating IPs | compute1 | Runs routers as `qrouter-*` network namespaces |
| ├ DHCP agent | Addresses for tenant networks | compute1 | `qdhcp-*` namespaces |
| └ metadata agent | Instance metadata (`169.254.169.254`) | compute1 | Cloud-init and keypairs |
| **Cinder** | Block storage | | |
| ├ cinder-api / scheduler | API and placement of volumes | controller | |
| ├ cinder-volume | Creates volumes as LVM logical volumes | storage | VG `cinder-volumes` on a dedicated disk |
| └ tgtd + iscsid | iSCSI target (storage) and initiator (compute1) | storage / compute1 | Carries volume data to the instance |
| **Horizon** | Web dashboard | controller | `http://10.0.1.5` |

## Supporting infrastructure

| Component | Role | Runs on | Why it matters |
|---|---|---|---|
| **MariaDB** | State for every service | controller | Single node here |
| **ProxySQL** | Database connection routing | controller | Enabled by default in Kolla 2024.2; sits between services and MariaDB |
| **RabbitMQ** | Message bus for service-to-service RPC | controller | Agent liveness ("alive" `:-)`/`XXX`) depends on its heartbeats |
| **Memcached** | Token and session cache | controller | |
| **HAProxy** | Load balancer and single entry point for the APIs | controller | Listens on the VIP |
| **Keepalived** | Holds the virtual IP `10.0.1.5` | controller | Releases the VIP if HAProxy/ProxySQL fail their health check |
| **fluentd, cron, kolla-toolbox** | Log shipping, log rotation, the Ansible runtime Kolla uses for API calls | all nodes | `kolla_toolbox` is where Kolla's OpenStack Ansible modules run |

## Intentionally not deployed

| Service | Status | Reason |
|---|---|---|
| **Swift** | Disk prepared (GPT partition `KOLLA_SWIFT_DATA`, XFS label `d0`), service off | Ring building is a separate piece of work |
| **Cinder backup** | Off | Needs a backup backend (Swift/NFS/Ceph); without one the service reports itself down (see the [log](05-troubleshooting-log.md#8--cinder-backup-reports-down)) |
| **Heat** | Off | Saves RAM on the 9 GB compute node |

## Resources created by the automation

| Resource | Type | Purpose |
|---|---|---|
| `ext-net` / `ext-subnet` | Flat provider network, no DHCP | Floating-IP pool on `physnet1` |
| `tenant-net` / `tenant-subnet` | VXLAN self-service network, DHCP | Where instances live |
| `demo-router` | Neutron router | SNAT for outbound traffic, floating-IP NAT |
| `m1.tiny`, `m1.small` | Flavors | Small test sizes |
| `cirros-0.6.2` | Image | Minimal image for infrastructure testing |
| `lab-key` | Keypair | Created from the controller's SSH key |
| `default` rules | Security group | ICMP and SSH ingress |
