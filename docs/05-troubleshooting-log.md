# 05 — Troubleshooting log

Real incidents from building the lab. Each one lists the symptom, the evidence that located the cause, the fix, and what it taught. They are ordered roughly as they happened.

## 1 — Address plan conflicts
**Symptom.** The first plan gave `compute1` and `storage` the same IP, and used the controller's own address as the VIP.
**Cause.** Two nodes cannot share an address, and Kolla's Keepalived needs a *free* address for the VIP so it can add and move it.
**Fix.** Controller `.4`, VIP `.5` (assigned to no node in ZeroTier), compute1 `.6`, storage `.7`. The pre-deploy check now fails if anything answers on the VIP.
**Lesson.** Validate the address plan before building on it.

## 2 — Prechecks fail on missing inventory groups
**Symptom.** `'dict object' has no attribute 'neutron-ovn-agent'` (then `ironic-neutron-agent`, `neutron-metering-agent`, …), one new error after each fix.
**Cause.** A hand-written Kolla inventory lacked groups that Kolla's service definitions reference, even for services that are not deployed.
**Fix.** Stop patching. Generate the inventory from Kolla's own shipped `multinode` file, replacing only the host-placement section ([D5](04-design-decisions.md#d5--generate-kollas-inventory-from-kollas-shipped-file)).
**Lesson.** When errors arrive one at a time, look for the structural cause.

## 3 — Keystone 504 because the load balancer was on the wrong node
**Symptom.** Deploy failed at *keystone | Creating services* with `Gateway Timeout (HTTP 504)` from `http://10.0.1.5:5000`. Keystone was `unhealthy`; direct calls to the controller's own address also hung.
**Evidence.**
- No `haproxy`, `keepalived` or `proxysql` containers on the controller; `ip -br a` showed no VIP there.
- `nc -zv 10.0.1.5 3306` *succeeded*, so something answered the VIP.
- The deploy log showed the *loadbalancer* role applied to `compute1`; the generated inventory had `[loadbalancer:children] network`, and `network` was compute1.
**Cause.** Kolla puts the load balancer on network nodes by default. Every database query from Keystone therefore went controller → compute1 → controller across the overlay; the startup queries were slow enough to time out.
**Fix.** Force `[loadbalancer:children]` to `control`; remove the stale containers from compute1; redeploy. The generator now asserts the placement ([D4](04-design-decisions.md#d4--haproxykeepalived-on-the-control-node)).
**Lesson.** Defaults assume a topology. Check where each component actually lands.

## 4 — Stale Neutron agents after moving them
**Symptom (first iteration).** After relocating DHCP/L3/metadata to compute1, `openstack network agent list` still showed dead controller agents.
**Cause.** Moving a group changes containers, but Neutron's database keeps the old agent registrations.
**Fix.** Remove the old containers and delete dead agent records (the cleanup was scripted by filtering the agent list for `Alive=false` on the old host).
**Lesson.** Service placement should be right from the first deploy; the second iteration did that.

## 5 — "Timeout (12s) waiting for privilege escalation prompt"
**Symptom.** Deploy failed on compute1 and storage after earlier tasks on those nodes had succeeded.
**Cause.** Not a sudo configuration problem (earlier tasks used it fine). The 10-second default was too tight for loaded VMs over a relayed link.
**Fix.** A generated `/etc/kolla/ansible.cfg` with `timeout = 60`, pipelining and SSH keep-alive ([D8](04-design-decisions.md#d8--defensive-timeouts-and-waits)).
**Lesson.** Intermittent success followed by a timeout points to latency or load, not permissions.

## 6 — VIP vanished after a ZeroTier restart
**Symptom.** `No route to host` for `10.0.1.5`. `ip -br a` showed only the node address. Neutron agents on compute1 showed `XXX`.
**Evidence.** Containers were all healthy. The Keepalived log showed *Entering FAULT STATE*, then the ZeroTier interface being *deleted* and recreated at the time `systemd` stopped and started `zerotier-one`, and afterwards Keepalived sat in BACKUP and never returned to MASTER.
**Cause.** When the interface was recreated, Keepalived stayed attached to the old one.
**Fix.** `docker restart keepalived`; restart the compute1 agents so they reconnect to RabbitMQ.
**Lesson.** A VIP depends on the interface beneath it. On a single controller it adds a failure mode; the design keeps it to demonstrate the pattern and records this trade-off.

## 7 — Measuring the overlay: relayed, slow, lossy
**Symptom.** Control-plane operations were slow; agents flapped after any blip.
**Evidence.** `zerotier-cli peers` showed `RELAY` (no direct path) to both nodes even with traffic flowing. Measured: controller → compute1 ≈ 98 ms with 10 % loss; controller → storage ≈ 283 ms (166–373 ms).
**Cause.** Each VM sat behind VMware NAT and a shared router, so ZeroTier could not establish direct paths.
**Decision.** Keep ZeroTier-only networking (D1) and design around it: network agents beside the provider NIC (D3), load balancer beside the services (D4), generous timeouts (D8).
**Lesson.** Measure the network before blaming the application, and record limits honestly.

## 8 — Cinder backup reports down
**Symptom.** `cinder-backup` showed `down`; the container was `Up … (healthy)` and `docker logs` looked fine.
**Evidence.** The service's own log file (`/var/log/kolla/cinder/cinder-backup.log`) repeated *"Manager … is reporting problems, not sending heartbeat"*. Clock difference with the controller was under 1 ms, ruling out skew.
**Cause.** The backup driver could not initialise: no backup backend (Swift/NFS/Ceph) is configured.
**Fix.** `enable_cinder_backup: "no"`, reconfigure, remove the stale service record.
**Lesson.** A healthy container does not mean a healthy service; check the application log. Also: the first diagnosis from `docker logs` alone was wrong, and only the file log settled it.

## 9 — Volume attach: asserting too early
**Symptom.** The workload test failed `volume is in-use` right after attaching, but a minute later the volume was `in-use` on `/dev/vdb`.
**Cause.** `server add volume` returns when Nova accepts the request. The iSCSI login across the overlay takes longer, and the test checked once.
**Fix.** Poll the status until `in-use` (or an error state), for up to five minutes.
**Lesson.** Asynchronous operations need waits, not single checks.

## 10 — Re-running created duplicate volumes
**Symptom.** After a failed run, `openstack volume show test-volume` failed with *More than one Volume exists with the name*, and the next run could not continue.
**Cause.** Existence checks used names, and a failed first run plus a re-run created a second resource with the same name.
**Fix.** Look up resources by ID (`server list --name '^test-vm$'`, `port list --device-id <id>`) and delete duplicates by ID.
**Lesson.** Names are not identifiers in OpenStack; idempotent automation must use IDs.

## 11 — `ip netns exec` inside the L3-agent container: Operation not permitted
**Symptom.** Pinging an instance from the router namespace failed with *setting the network namespace … failed*.
**Cause.** Kolla containers run the agent as an unprivileged user; entering a namespace needs root.
**Fix.** `docker exec -u root neutron_l3_agent ip netns exec qrouter-<id> …`.

## 12 — Floating IP unreachable from the overlay: the return path
**Symptom.** Requests from the controller reached the floating IP but no reply came back.
**Evidence.** `tcpdump -ni any` on compute1 showed the request entering via the ZeroTier interface and leaving by the access NIC, while the **reply** left through the OVS provider NIC. Inside the router namespace, `ip route get <controller IP>` resolved to the default gateway (the Windows host's VMnet10 address), which has no route to the overlay.
**Cause.** Two routing domains: the host's routing table and the Neutron router's namespace. The host knew how to reach the overlay; the router did not.
**Fix.** A route on the Neutron router: `10.0.1.0/24` via the access NIC's address. Because it is stored in Neutron, it survives namespace recreation. See [06](06-floating-ip-access.md).
**Lesson.** Debug with packet captures per interface; read the route table of *each* namespace on the path.

## 13 — Link up, ARP works, ping unanswered
**Symptom.** From compute1's new NIC, `ping` to the VMnet10 host address got no reply.
**Evidence.** `tcpdump` showed an ARP reply from the host adapter's MAC, so layer 2 was fine; only ICMP echo went unanswered.
**Cause.** Windows Firewall drops inbound ICMP on the VMware host-only adapter.
**Fix.** Allow inbound ICMPv4 echo on that adapter.
**Lesson.** ARP replies separate "link is broken" from "protocol is filtered".

## 14 — A cloud image fails Nova's safety check
**Symptom (first iteration).** An Alpine cloud image failed with *Base image failed safety check: mbr … invalid boot flag*, before the VM could start.
**Evidence.** The scheduler had selected compute1, KVM was available; the failure was in image inspection.
**Fix.** Use CirrOS for infrastructure validation, which is what it is for.
**Lesson.** Isolate whether the platform or the payload is at fault.

## 15 — ZeroTier managed routes are a paid feature
**Symptom.** The route that tells overlay peers how to reach the provider subnet could not be created in the free plan.
**Fix.** Install the equivalent route locally on the controller, kept alive by a small systemd service that re-adds it if the ZeroTier interface is recreated. Alternative for SSH only: `ssh -J compute1@10.0.1.6 cirros@<floating-ip>`.
