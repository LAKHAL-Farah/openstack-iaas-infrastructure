#!/usr/bin/env bash
# Run on the controller once the ZeroTier IPs respond to ping.
# Asks for each account's password once (user@host pairs match inventory/hosts.yml).
set -euo pipefail
for target in controller@10.0.1.4 compute1@10.0.1.6 storage@10.0.1.7; do
  echo ">>> $target"
  ssh-copy-id -o StrictHostKeyChecking=accept-new "$target"
done
