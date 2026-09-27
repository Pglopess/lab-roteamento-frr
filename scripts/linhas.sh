#!/usr/bin/env bash
# Complexidade de configuracao: linhas uteis (sem vazias e sem comentarios "!") dos frr.conf.
cd "$(dirname "$0")/.."
echo "proto,linhas_total,linhas_r1,linhas_r2"
for p in ospf rip bgp; do
  t=0
  for r in r1 r2 r3 r4 r5; do
    n=$(grep -vE '^\s*(!|$)' configs/$p/$r/frr.conf | wc -l); t=$((t+n)); eval "n_$r=$n"
  done
  echo "$p,$t,$n_r1,$n_r2"
done
