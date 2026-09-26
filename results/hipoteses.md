# Hipoteses (escritas antes dos experimentos)
 
## Experimento 1: convergencia apos queda do link R2-R5 (ping R1 -> R5)
- Modo link down: os tres protocolos recuperam em menos de ~1 s (a interface cai nas duas pontas e o FRR reage na hora). Sem diferenca mensuravel na resolucao da sonda (~0,2 s).
- Modo silent (netem loss 100%): so os timers detectam a falha.
  - OSPF: ~40 s (dead interval).
  - RIP: >= 180 s (timeout) mais o proximo update de 30 s.
  - BGP: ~180 s (hold time; keepalive de 60 s).
