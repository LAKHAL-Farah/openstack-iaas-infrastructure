#!/usr/bin/env bash
# Run on the controller after the repo is extracted. Installs a PINNED Ansible in its own venv
# (Ubuntu 22.04's apt ansible is too old for current collections) + creates the SSH keypair.
set -euo pipefail
sudo apt-get update -y
sudo apt-get install -y python3-venv python3-pip git jq curl
python3 -m venv ~/.venvs/ansible
~/.venvs/ansible/bin/pip install -q -U pip "ansible-core>=2.16,<2.18"
~/.venvs/ansible/bin/ansible-galaxy collection install "community.general:>=9,<11" ansible.posix --upgrade >/dev/null
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
~/.venvs/ansible/bin/ansible --version | head -1
echo "Controller ready. Public key:"; cat ~/.ssh/id_ed25519.pub
