#!/usr/bin/env bash
# Tamanho da tabela de roteamento (R1..R5) por protocolo, em regime estavel.
cd "$(dirname "$0")/.."
OUT=results/tabela.txt; : > $OUT
for P in ospf rip bgp; do
  case $P in ospf) W=45;; rip) W=75;; bgp) W=50;; esac
  ./scripts/up.sh $P >/dev/null 2>&1; sleep $W
  echo "===== $P" | tee -a $OUT
  for r in 1 2 3 4 5; do
    echo "--- r$r" | tee -a $OUT
    docker exec clab-rotas-r$r vtysh -c "show ip route summary" 2>/dev/null | tee -a $OUT
  done
  ./scripts/down.sh >/dev/null 2>&1
done
echo fim
