#!/usr/bin/env bash
# Usage: ./scripts/kolla.sh <bootstrap-servers|prechecks|pull|deploy|post-deploy|reconfigure|mariadb_recovery|...>
# Always uses the pinned venv + generated inventory, runs from /etc/kolla, logs to ./logs/
set -euo pipefail
action="${1:?usage: kolla.sh <action>}"; shift || true
logdir="$(cd "$(dirname "$0")/.." && pwd)/logs"; mkdir -p "$logdir"
source /opt/kolla-venv/bin/activate
cd /etc/kolla
echo ">>> kolla-ansible $action  (log: $logdir/kolla-$action.log)"
kolla-ansible "$action" -i /etc/kolla/multinode "$@" 2>&1 | tee "$logdir/kolla-$action.log"
exit "${PIPESTATUS[0]}"
