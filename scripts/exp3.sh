#!/usr/bin/env bash
# Uso: ./scripts/exp3.sh ospf|rip|bgp
# (a) atraso de 100 ms no R2:eth3 -> a rota muda?  (b) mudanca de politica -> rota e tempo.
set -uo pipefail
PROTO=${1:?ospf|rip|bgp}
cd "$(dirname "$0")/.."
case $PROTO in ospf) WARM=45;; rip) WARM=75;; bgp) WARM=50;; *) exit 1;; esac
R1=clab-rotas-r1; R2=clab-rotas-r2; R5=clab-rotas-r5
OUT=results/exp3_${PROTO}.txt; : > $OUT
log(){ echo "$@" | tee -a $OUT; }
rt(){ docker exec $R1 vtysh -c "show ip route 10.255.0.5/32" 2>/dev/null | grep -E ' via ' | sed 's/^ *//' | tee -a $OUT; }
rtt(){ docker exec $R1 ping -c10 -W1 -I 10.255.0.1 10.255.0.5 | tail -1 | tee -a $OUT; }
 
./scripts/up.sh $PROTO >/dev/null 2>&1
sleep $WARM
log "== 1 baseline (R1 -> 10.255.0.5)"; rt; rtt
 
log "== 2 netem delay 100ms em r2:eth3"
docker exec $R2 tc qdisc add dev eth3 root netem delay 100ms
sleep 30; rt; rtt
docker exec $R2 tc qdisc del dev eth3 root
sleep 5
 
log "== 3 mudanca de politica"
case $PROTO in
  ospf)
    docker exec $R2 vtysh -c "configure terminal" -c "interface eth3" -c "ip ospf cost 100" >/dev/null 2>&1
    docker exec $R5 vtysh -c "configure terminal" -c "interface eth1" -c "ip ospf cost 100" >/dev/null 2>&1
    log "ip ospf cost 100 em r2:eth3 e r5:eth1";;
  bgp)
    docker exec $R1 vtysh -c "configure terminal" -c "route-map PREF200 permit 10" -c "set local-preference 200" -c "exit" \
      -c "router bgp 65001" -c "address-family ipv4 unicast" -c "neighbor 10.0.13.2 route-map PREF200 in" -c "end" \
      -c "clear bgp ipv4 unicast 10.0.13.2 soft in" 2>&1 | tee -a $OUT
    log "local-preference 200 para rotas vindas de 10.0.13.2 (R3) no R1";;
  rip) log "RIP: metrica = saltos, sem parametro de custo por link; nada a alterar";;
esac
if [ $PROTO != rip ]; then
  T0=$(date +%s.%N)
  for i in $(seq 1 120); do docker exec $R1 vtysh -c "show ip route 10.255.0.5/32" 2>/dev/null | grep -q '10.0.13.2' && break; sleep 0.5; done
  T1=$(date +%s.%N)
  log "tempo ate a rota mudar: $(LC_ALL=C awk -v a=$T0 -v b=$T1 'BEGIN{printf "%.1f",b-a}') s (max 60)"
fi
rt; rtt
docker exec $R1 vtysh -c "show bgp ipv4 unicast 10.255.0.5/32" 2>/dev/null | tee -a $OUT >/dev/null
./scripts/down.sh >/dev/null 2>&1
log fim
