.RECIPEPREFIX := >
PB = ansible-playbook
.PHONY: ping sudoers baseline network storage compute preflight all
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
