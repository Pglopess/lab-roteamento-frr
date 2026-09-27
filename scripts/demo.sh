#!/usr/bin/env bash
# Demonstracao para o video. Uso: ./scripts/demo.sh ospf|rip|bgp
# ENTER avanca cada etapa (pausas para narrar).
PROTO=${1:?ospf|rip|bgp}
cd "$(dirname "$0")/.."
case $PROTO in
  ospf) NEI="show ip ospf neighbor"; ROT="show ip route ospf"; W=45;;
  rip)  NEI="show ip rip status";    ROT="show ip route rip";  W=75;;
  bgp)  NEI="show bgp summary";      ROT="show ip route bgp";  W=50;;
  *) echo invalido; exit 1;;
esac
V(){ docker exec clab-rotas-r$1 vtysh -c "$2" 2>/dev/null; }
passo(){ echo; echo ">>> $*"; read -r -p "[ENTER] " _; }
 
clear
passo "1. Subindo a topologia (5 roteadores, FRR 10.2.1) com $PROTO"
./scripts/up.sh $PROTO 2>&1 | tail -12
echo "aguardando convergencia (${W}s)..."; sleep $W
 
passo "2. Vizinhanca do R1 ($NEI)"
V 1 "$NEI"
 
passo "3. Matriz de ping entre loopbacks e entre hosts das redes de acesso"
./scripts/check.sh $PROTO 2>/dev/null | sed -n '/Matriz/,$p' | grep -E "Matriz|^[rh][0-9]:"
 
passo "4. Rotas aprendidas no R1 ($ROT)"
V 1 "$ROT"
 
passo "5. Rota do R1 para a rede de acesso do R5 (192.168.5.0/24) e caminho h1 -> h5"
V 1 "show ip route 192.168.5.0/24" | grep -E "Known|via"
docker exec clab-rotas-h1 traceroute -n -w1 -q1 192.168.5.10
 
passo "6. Derrubando o link R2-R5 e acompanhando o ping h1 -> h5"
docker exec clab-rotas-h1 ping 192.168.5.10 > /tmp/demo_ping.log 2>&1 &
PP=$!
sleep 3
docker exec clab-rotas-r2 ip link set eth3 down
echo "link r2:eth3 DOWN"; sleep 40
kill $PP 2>/dev/null; docker exec clab-rotas-h1 pkill ping 2>/dev/null
echo "--- ping durante a queda (buracos na seq = pacotes perdidos):"; grep -o "seq=[0-9]*" /tmp/demo_ping.log | cut -d= -f2 | tr "\n" " "; echo
 
passo "7. Nova rota do R1 para 192.168.5.0/24 e novo caminho h1 -> h5"
V 1 "show ip route 192.168.5.0/24" | grep -E "Known|via"
docker exec clab-rotas-h1 traceroute -n -w1 -q1 192.168.5.10
 
passo "8. Derrubando o laboratorio"
./scripts/down.sh 2>&1 | tail -3
