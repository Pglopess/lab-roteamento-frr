#!/usr/bin/env bash
# Uso: ./scripts/up.sh ospf|rip|bgp
set -euo pipefail
PROTO=${1:?uso: ./scripts/up.sh ospf|rip|bgp}
cd "$(dirname "$0")/.."
[ -d "configs/$PROTO" ] || { echo "configs/$PROTO nao existe"; exit 1; }
containerlab destroy -t topo.clab.yml --cleanup >/dev/null 2>&1 || true
rm -rf running && cp -r "configs/$PROTO" running
containerlab deploy -t topo.clab.yml
