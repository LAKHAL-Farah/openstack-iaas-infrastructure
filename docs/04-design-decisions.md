# 04 — Design decisions

Each record states the decision, why it was made, and what it costs.

## D1 — ZeroTier for the management network
**Decision.** Nodes communicate over a ZeroTier overlay (`10.0.1.0/24`) with pinned IPs, not over VMware NAT or LAN addresses.
**Why.** The machines may be on different networks, and VMware NAT addresses are per host and not routable between hosts. The overlay gives stable addressing for Ansible, Kolla and OpenStack service endpoints.
**Cost.** The links between the VMs were relayed rather than direct: about 100 ms to compute1 and up to ~300 ms to storage. That is slow for control-plane RPC and very slow for iSCSI. The decision was kept deliberately (a shared LAN is not always available), and the rest of the design adapts to it (D3, D4, D8).

## D2 — Self-service tenant networks plus a provider network
**Decision.** Tenants get VXLAN networks behind a router; a flat provider network (`physnet1`) on a dedicated NIC supplies floating IPs.
**Why.** This is the standard production model: isolation and tenant-owned routing, with a single controlled exit.
**Cost.** Needs a layer-2 segment for the provider side, which cannot be carried over ZeroTier. That is solved with a VMware host-only network on the compute node's machine (D6).

## D3 — Neutron network agents on compute1
**Decision.** L3, DHCP and metadata agents run on compute1 (`[network]` = compute1).
**Why.** compute1 owns the provider NIC. With the agents elsewhere, every tenant and floating-IP packet would travel across the overlay to be routed and back.
**Cost.** compute1 is a combined compute and network node, so a failure there affects both.

## D4 — HAProxy/Keepalived on the control node
**Decision.** The load balancer is forced onto `[control]`.
**Why.** Kolla places it on network nodes by default. With the network node being compute1, every database and API call from the controller went to compute1 and back over the overlay. That doubled the latency of each call, and Keystone requests timed out (HTTP 504). See incident [3](05-troubleshooting-log.md#3--keystone-504-because-the-load-balancer-was-on-the-wrong-node).
**Cost.** None beyond a one-line template override; a startup assertion confirms it was applied.

## D5 — Generate Kolla's inventory from Kolla's shipped file
**Decision.** Only the host-to-group section is templated; the rest of Kolla's own `multinode` file is appended unchanged.
**Why.** Hand-written inventories miss groups that Kolla's roles reference, causing prechecks to fail one missing group at a time.

## D6 — Provider traffic stays off ZeroTier
**Decision.** The provider network is a VMware host-only network (`VMnet10`) attached to compute1.
**Why.** A flat network needs real layer-2 adjacency, and stretching it across an overlay is fragile.
**Cost.** Floating IPs are reachable natively only from compute1's own machine. Remote access is handled in D9.

## D7 — A pinned Ansible environment
**Decision.** The repository uses its own virtual environment with `ansible-core` 2.16–2.17 and Kolla uses a separate pinned venv.
**Why.** Ubuntu 22.04's packaged Ansible is too old for current collections, and mixing system and venv Ansible caused import and plugin problems in the first iteration.

## D8 — Defensive timeouts and waits
**Decision.** Kolla runs with `timeout = 60`, pipelining and SSH keep-alive; the workload test waits for volume attaches up to five minutes.
**Why.** On a relayed link and loaded VMs, the default 10-second privilege-escalation timeout fails mid-deployment, and an iSCSI attach can legitimately take minutes. Waiting on a status is correct; asserting once is a race.

## D9 — A dedicated access NIC and a Neutron return route
**Decision.** compute1 gets a third NIC on the provider subnet, owned by plain Linux, not Open vSwitch. It forwards ZeroTier traffic to floating IPs. The return path is a route stored on the Neutron router.
**Why.** The provider NIC belongs to OVS (`master ovs-system`) and must not carry a host IP. The Windows host must not become a router. See [06](06-floating-ip-access.md).
**Alternative considered.** NAT on compute1: simpler, but the instance then sees the router's address, not the real client, and it needs extra firewall state. A ZeroTier managed route was ruled out because it is a paid feature; an equivalent local route is installed instead.

## D10 — Storage: Cinder LVM now, Swift prepared, backup off
**Decision.** Cinder uses an LVM volume group on a dedicated disk; Glance uses an NFS export; the Swift disk is partitioned the way Kolla expects but the service is off; Cinder backup is off.
**Why.** Block storage and images are what a first workload needs. Swift needs ring building and backup needs a backend, and both would add failure points without helping the first workload.
**Cost.** No object storage and no volume backups yet.

## D11 — Safety rails in the automation
- The storage playbook refuses to touch the OS disk and skips destructive tasks in check mode.
- `kolla-prepare` refuses to start if something already answers on the VIP.
- `kolla-config` aborts if the load balancer is not on the control node.
- Playbooks resolve resources by ID, not by name, so re-runs are idempotent.
