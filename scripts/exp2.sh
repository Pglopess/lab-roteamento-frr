#!/usr/bin/env bash
# Uso: ./scripts/exp2.sh [janela_s]   (padrao 180 s)
# Volume de trafego de controle em regime estavel, observado no R2 (eth1..eth3).
set -uo pipefail
cd "$(dirname "$0")/.."
WIN=${1:-180}
mkdir -p results/raw
sudo -v || exit 1
CSV=results/exp2.csv
echo "proto,pacotes,bytes,pacotes_por_s,bytes_por_s" > $CSV
for PROTO in ospf rip bgp; do
  case $PROTO in
    ospf) F="ip proto 89";   WARM=45;;
    rip)  F="udp port 520";  WARM=75;;
    bgp)  F="tcp port 179";  WARM=50;;
  esac
  ./scripts/up.sh $PROTO >/dev/null 2>&1
  sleep $WARM
  PID=$(docker inspect -f '{{.State.Pid}}' clab-rotas-r2)
  for i in eth1 eth2 eth3; do
    sudo timeout -s INT $WIN nsenter -t $PID -n tcpdump -i $i -nn -U -w /tmp/exp2_${PROTO}_$i.pcap "$F" >/dev/null 2>&1 &
  done
  wait
  sudo chmod a+r /tmp/exp2_${PROTO}_*.pcap
  read PK BY < <(python3 scripts/pcapstat.py /tmp/exp2_${PROTO}_eth*.pcap)
  cp /tmp/exp2_${PROTO}_*.pcap results/raw/ 2>/dev/null
  LINE=$(LC_ALL=C awk -v p=$PK -v b=$BY -v w=$WIN -v n=$PROTO 'BEGIN{printf "%s,%d,%d,%.2f,%.1f", n,p,b,p/w,b/w}')
  echo "$LINE" | tee -a $CSV
  ./scripts/down.sh >/dev/null 2>&1
done
echo fim
