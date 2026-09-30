#!/usr/bin/env bash
# Run on controller once ZeroTier IPs respond. Asks for each node's password once.
set -euo pipefail
for ip in 10.0.1.4 10.0.1.6 10.0.1.7; do
  ssh-copy-id -o StrictHostKeyChecking=accept-new stack@"$ip"
done
