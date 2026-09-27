#!/usr/bin/env bash
# Uso: ./scripts/check.sh ospf|rip|bgp
# Mostra vizinhos de cada roteador, testa ping entre loopbacks e entre os hosts das redes de acesso.
PROTO=${1:?uso: ./scripts/check.sh ospf|rip|bgp}
case $PROTO in
  ospf) CMD="show ip ospf neighbor" ;;
  rip)  CMD="show ip rip status" ;;
  bgp)  CMD="show bgp summary" ;;
esac
for r in 1 2 3 4 5; do
  echo "===== r$r: $CMD"
  docker exec clab-rotas-r$r vtysh -c "$CMD" 2>/dev/null
done
echo "===== Matriz de ping (origem loopback -> destino loopback)"
for s in 1 2 3 4 5; do
  linha="r$s:"
  for d in 1 2 3 4 5; do
    [ $s -eq $d ] && { linha="$linha  -- "; continue; }
    if docker exec clab-rotas-r$s ping -c1 -W1 -I 10.255.0.$s 10.255.0.$d >/dev/null 2>&1; then
      linha="$linha  OK "; else linha="$linha FALHA"; fi
  done
  echo "$linha"
done
echo "===== Matriz de ping entre hosts (hN 192.168.N.10 -> hM 192.168.M.10)"
for s in 1 2 3 4 5; do
  linha="h$s:"
  for d in 1 2 3 4 5; do
    [ $s -eq $d ] && { linha="$linha  -- "; continue; }
    if docker exec clab-rotas-h$s ping -c1 -W1 192.168.$d.10 >/dev/null 2>&1; then
      linha="$linha  OK "; else linha="$linha FALHA"; fi
  done
  echo "$linha"
done
