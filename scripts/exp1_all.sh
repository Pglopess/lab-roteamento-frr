#!/usr/bin/env bash
cd "$(dirname "$0")/.."
for rep in 1 2 3; do for p in ospf rip bgp; do echo "$(date +%T) down $p $rep"; ./scripts/exp1.sh $p down $rep; done; done
for p in ospf rip bgp; do echo "$(date +%T) silent $p 1"; ./scripts/exp1.sh $p silent 1; done
echo "$(date +%T) fim"
