#!/usr/bin/env bash
# Run on the controller after the repo is cloned. Installs Ansible + keypair.
set -euo pipefail
sudo apt-get update -y
sudo apt-get install -y ansible git jq curl
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ansible-galaxy collection install community.general ansible.posix >/dev/null
echo "Controller ready. Public key:"; cat ~/.ssh/id_ed25519.pub
