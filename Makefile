.RECIPEPREFIX := >
PB = ansible-playbook
.PHONY: ping sudoers baseline network storage compute preflight all
ping:
>  ansible openstack_nodes -m ping
sudoers:
>  $(PB) playbooks/00-sudoers.yml --ask-become-pass
baseline:
>  $(PB) playbooks/01-baseline.yml
network:
>  $(PB) playbooks/02-network.yml
storage:
>  $(PB) playbooks/03-storage.yml
compute:
>  $(PB) playbooks/04-compute.yml
preflight:
>  $(PB) playbooks/99-preflight.yml
all: ping baseline network storage compute preflight
