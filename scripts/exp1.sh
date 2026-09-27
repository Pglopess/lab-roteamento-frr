#!/usr/bin/env bash
# Uso: ./scripts/exp1.sh ospf|rip|bgp down|silent [rep]
# Mede a interrupcao do ping R1->R5 (loopbacks) quando o link R2-R5 falha.
#  down   : ip link set down (deteccao imediata, melhor caso)
#  silent : netem loss 100% nos dois lados (so os timers do protocolo detectam)
set -uo pipefail
PROTO=${1:?ospf|rip|bgp}; MODE=${2:?down|silent}; REP=${3:-1}
cd "$(dirname "$0")/.."
mkdir -p results/raw
case $PROTO in ospf) WARM=45;; rip) WARM=75;; bgp) WARM=50;; *) echo proto invalido; exit 1;; esac
case $MODE in
  down) WIN=60;;
  silent) case $PROTO in ospf) WIN=90;; *) WIN=260;; esac;;  # RIP/BGP: timers de 180 s
  *) echo modo invalido; exit 1;;
esac
R1=clab-rotas-r1; R2=clab-rotas-r2; R5=clab-rotas-r5
LOG=results/raw/exp1_${PROTO}_${MODE}_${REP}.log
 
./scripts/up.sh $PROTO >/dev/null 2>&1
sleep $WARM
docker exec $R1 ping -c2 -W1 -I 10.255.0.1 10.255.0.5 >/dev/null 2>&1 \
  || { echo "sem conectividade R1->R5 antes da falha; abortando"; ./scripts/down.sh >/dev/null 2>&1; exit 1; }
 
# sonda no HOST (date com ns); cada ping roda dentro de R1 via docker exec.
rm -f /tmp/probe_$$.log /tmp/stop_$$
( while [ ! -f /tmp/stop_$$ ]; do
    if docker exec $R1 ping -c1 -W1 -I 10.255.0.1 10.255.0.5 >/dev/null 2>&1; then r=1; else r=0; fi
    echo "$(date +%s%N) $r" >> /tmp/probe_$$.log
    sleep 0.1
  done ) &
PROBE=$!
sleep 5
 
if [ "$MODE" = down ]; then
  docker exec $R2 ip link set eth3 down
else
  docker exec $R2 tc qdisc add dev eth3 root netem loss 100% \
&& docker exec $R5 tc qdisc add dev eth1 root netem loss 100% \
   || { echo "tc falhou"; touch /tmp/stop_$$; wait $PROBE; ./scripts/down.sh >/dev/null 2>&1; exit 1; }
fi
 
sleep $WIN
touch /tmp/stop_$$; wait $PROBE
cp /tmp/probe_$$.log $LOG; rm -f /tmp/stop_$$ /tmp/probe_$$.log
 
RES=$(LC_ALL=C awk '{ts=substr($1,1,length($1)-6)+0}
  $2==0 { if(!f) f=ts; l++; last=ts; next }
  f && !rec && $2==1 { rec=ts }
  END { if(!l) print "0,0,yes"; else printf "%d,%.1f,%s\n", l, (rec?(rec-f):(last-f))/1000, (rec?"yes":"no") }' $LOG)
 
CSV=results/exp1.csv
[ -f $CSV ] || echo "proto,mode,rep,lost_probes,interruption_s,recovered" > $CSV
echo "$PROTO,$MODE,$REP,$RES" >> $CSV
echo "$PROTO $MODE rep$REP -> $RES"
./scripts/down.sh >/dev/null 2>&1
