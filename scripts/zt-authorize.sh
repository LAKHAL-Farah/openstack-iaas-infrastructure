#!/usr/bin/env bash
# Usage: ZT_API_TOKEN=xxx ZT_NETWORK_ID=xxx ./zt-authorize.sh controller=<id> compute1=<id> storage=<id>
# Authorizes each member and pins its static IP (keep in sync with inventory/hosts.yml).
set -euo pipefail
: "${ZT_API_TOKEN:?set ZT_API_TOKEN}"; : "${ZT_NETWORK_ID:?set ZT_NETWORK_ID}"
declare -A IPS=( [controller]=10.0.1.4 [compute1]=10.0.1.6 [storage]=10.0.1.7 )
for arg in "$@"; do
  name="${arg%%=*}"; id="${arg#*=}"; ip="${IPS[$name]:?unknown node $name}"
  curl -fsS -X POST \
    -H "Authorization: token ${ZT_API_TOKEN}" -H "Content-Type: application/json" \
    -d "{\"name\":\"${name}\",\"config\":{\"authorized\":true,\"ipAssignments\":[\"${ip}\"]}}" \
    "https://api.zerotier.com/api/v1/network/${ZT_NETWORK_ID}/member/${id}" >/dev/null
  echo "authorized ${name} (${id}) -> ${ip}"
done
