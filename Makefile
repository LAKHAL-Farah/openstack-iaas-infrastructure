.RECIPEPREFIX := >
export PATH := $(HOME)/.venvs/ansible/bin:$(PATH)
PB = ansible-playbook
.PHONY: ping sudoers baseline network storage compute preflight all \
        kolla-prepare kolla-config kolla-bootstrap kolla-prechecks kolla-pull kolla-deploy kolla-post cloud test-vm vol2
ping:
> ansible openstack_nodes -m ping
# one prompt per node, so each account may have a different password
sudoers:
> for h in controller compute1 storage; do $(PB) playbooks/00-sudoers.yml --limit $$h --ask-become-pass || exit 1; done
baseline:
> $(PB) playbooks/01-baseline.yml
network:
> $(PB) playbooks/02-network.yml
storage:
> $(PB) playbooks/03-storage.yml
compute:
> $(PB) playbooks/04-compute.yml
preflight:
> $(PB) playbooks/99-preflight.yml
all: ping baseline network storage compute preflight

# ---------------- Vol 2: Kolla-Ansible + cloud ----------------
kolla-prepare:
> $(PB) playbooks/10-kolla-prepare.yml
kolla-config:
> $(PB) playbooks/11-kolla-config.yml
kolla-bootstrap:
> ./scripts/kolla.sh bootstrap-servers
kolla-prechecks:
> ./scripts/kolla.sh prechecks
kolla-pull:
> ./scripts/kolla.sh pull
kolla-deploy:
> ./scripts/kolla.sh deploy
kolla-post:
> ./scripts/kolla.sh post-deploy && cp /etc/kolla/admin-openrc.sh ~/admin-openrc.sh
cloud:
> $(PB) playbooks/20-openstack-cloud.yml
test-vm:
> $(PB) playbooks/21-workload-test.yml
vol2: kolla-prepare kolla-config kolla-bootstrap kolla-prechecks kolla-pull kolla-deploy kolla-post cloud
