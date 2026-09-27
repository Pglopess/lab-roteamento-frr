# Roteamento IP com FRRouting: BGP, OSPF e RIP
 
Trabalho 1 de Redes de Computadores (UNISINOS). Trabalho individual.
 
## Ambiente e pré-requisitos
- VirtualBox (Windows) com Ubuntu, kernel 7.0.0-29-generic, ~3,3 GiB de RAM
- Docker 29.1.3, containerlab 0.79.0, tcpdump 4.99.6 (no host), python3
- Imagem FRR: `quay.io/frrouting/frr:10.2.1`, digest `sha256:e47e67bd612030cb1bedee2bde85b73913f2ea021573b749deb21d94940f03c1`
- Usuário nos grupos `docker` e `clab_admins`; `sudo` só para o `exp2.sh` (tcpdump via nsenter)
 
```
docker pull quay.io/frrouting/frr:10.2.1
```
 
## Topologia
5 roteadores em 3 ASes (AS65001: R1,R2; AS65002: R3,R4; AS65003: R5). Loopbacks 10.255.0.N/32.
 
| Link | Rede | Interfaces | Tipo |
|---|---|---|---|
| R1-R2 | 10.0.12.0/30 | R1:eth1 / R2:eth1 | iBGP (AS65001) |
| R1-R3 | 10.0.13.0/30 | R1:eth2 / R3:eth1 | eBGP |
| R2-R4 | 10.0.24.0/30 | R2:eth2 / R4:eth1 | eBGP (corda) |
| R2-R5 | 10.0.25.0/30 | R2:eth3 / R5:eth1 | eBGP |
| R3-R4 | 10.0.34.0/30 | R3:eth2 / R4:eth2 | iBGP (AS65002) |
| R4-R5 | 10.0.45.0/30 | R4:eth3 / R5:eth2 | eBGP |
 
A corda R2-R4 dá dois links eBGP paralelos entre AS1 e AS2 e cria empates de custo (ECMP) em OSPF.
 
## Como reproduzir
```
./scripts/up.sh ospf|rip|bgp                 # sobe a topologia com o protocolo escolhido
./scripts/check.sh ospf|rip|bgp              # vizinhos + matriz de ping entre loopbacks
./scripts/down.sh                            # destrói o laboratório
./scripts/exp1.sh <proto> down|silent <rep>  # convergência
./scripts/exp2.sh                            # tráfego de controle
./scripts/exp3.sh <proto>                    # seleção de rotas
./scripts/tabela.sh                          # tamanho da tabela de roteamento
./scripts/linhas.sh                          # complexidade de configuração
```
Um protocolo por vez, sobre a mesma topologia física. As configs ficam em `configs/<proto>/` e são copiadas para `running/` pelo `up.sh`.
 
## Premissas de interpretação do enunciado
- "Não simultâneo": cada protocolo roda sozinho; o laboratório é destruído e recriado entre eles.
- OSPF e RIP formam um domínio único com os 5 roteadores. O BGP usa eBGP entre ASes e iBGP dentro deles (link direto, `next-hop-self`, sem IGP).
- `no bgp ebgp-requires-policy`: sem isso o FRR estabelece a sessão eBGP mas não troca prefixos.
- Sem políticas de roteamento, o AS2 atua como trânsito entre AS1 e AS3, o que cria o caminho alternativo AS1-AS3.
- Timers padrão do FRR (OSPF hello 10 s / dead 40 s; RIP update 30 s / timeout 180 s; BGP keepalive 60 s / hold 180 s).
- Custo OSPF fixado em 10 por link; RIP usa contagem de saltos.
- Falhas no BGP só em links entre ASes (R2-R5): sem IGP, a queda de um link iBGP particiona o AS.
- O RIP do FRR não instalou multipath nos empates da corda; o OSPF instalou.
 
## Experimento 1: convergência (queda do link R2-R5, ping R1 -> R5)
Hipóteses em `results/hipoteses.md`. Dados em `results/exp1.csv`, logs em `results/raw/`.
Amostragem ~0,2 s por tentativa, mais até 1 s por ping perdido (erro de ~1 s).
 
| Protocolo | `link down` (3 rep.) | falha silenciosa (`netem loss 100%`, 3 rep.) |
|---|---|---|
| OSPF | sem perdas | 37,2 s (36,9 a 37,9) |
| BGP | sem perdas | 125,7 s (125,3 a 126,0) |
| RIP | 1,4 / 3,7 / 13,3 s | 184,9 s (181,2 a 191,8) |
 
Análise (rascunho para reescrever):
- No silent só os timers detectam a falha: OSPF ~ dead interval (40 s); RIP ~ timeout de 180 s mais o próximo update.
- O BGP (~125 s) ficou abaixo do hold de 180 s porque o hold conta desde o último keepalive. A baixa variação entre repetições reflete a fase do ciclo de keepalive no instante da injeção da falha (sempre o mesmo), não uma propriedade geral: em outro instante o valor cairia entre ~120 e 180 s.
- No `link down`, OSPF e BGP reagem ao carrier na hora. A hipótese de que os três recuperam em menos de ~1 s foi refutada para o RIP (1,4 a 13,3 s). Explicação provável, não verificada: o RIP depende de updates periódicos (30 s, jitter de ±50%) dos vizinhos para aprender o caminho alternativo.
 
## Experimento 2: tráfego de controle (regime estável, 180 s, observado no R2 eth1-eth3)
 
| Protocolo | Pacotes | Bytes | Pacotes/s | Bytes/s |
|---|---|---|---|---|
| OSPF | 108 | 8856 | 0,60 | 49,2 |
| RIP | 42 | 7632 | 0,23 | 42,4 |
| BGP | 32 | 2454 | 0,18 | 13,6 |
 
Filtros: `ip proto 89`, `udp port 520`, `tcp port 179`; a `eth0` de gerência fica fora. O OSPF tem mais pacotes (Hellos de 10 s por link); o RIP tem poucos pacotes, mas grandes (tabela inteira a cada update); o BGP é o menor, e sua contagem inclui ACKs de TCP. Não mede a fase de convergência inicial.
 
## Experimento 3: seleção de rotas (R1 -> 10.255.0.5)
 
| Protocolo | Baseline | Atraso de 100 ms em R2-R5 | Mudança de política |
|---|---|---|---|
| OSPF | via R2, métrica 20 | rota igual, RTT 0,12 -> 100,8 ms | `ip ospf cost 100`: métrica 30, ECMP via R2 e R3 |
| RIP | via R2, métrica 3 | rota igual, RTT 0,09 -> 100,7 ms | sem parâmetro de custo por link |
| BGP | via R2 (iBGP, AS-path 65003) | rota igual, RTT 0,09 -> 100,7 ms | `local-preference 200` vinda do R3: rota passa a via R3 (eBGP, AS-path mais longo) |
 
Nenhum protocolo mede latência. No BGP, o local-pref vence o AS-path. Os tempos de mudança medidos pelo script (OSPF 0,1 s, BGP 0,7 s) estão abaixo da resolução do teste e não são medições de convergência.
 
## Tamanho da tabela de roteamento
PREENCHER com `results/tabela.txt` (rodar `./scripts/tabela.sh`).
 
## Complexidade de configuração (linhas úteis, sem vazias nem comentários)
 
| Protocolo | Total (5 roteadores) |
|---|---|
| RIP | 86 |
| BGP | 107 |
| OSPF | 112 |
 
O OSPF ficou maior pela escolha de configurar `area`, `network point-to-point` e `cost` em cada interface. A contagem não mede a dificuldade de acertar a configuração.
 
## Escalabilidade e adequação a cenários
PREENCHER: RIP (limite de 15 saltos, updates com tabela inteira), OSPF (LSDB replicada; áreas para escalar), BGP (escala entre ASes e aplica política).
 
## Limitações
- Uma repetição por medição nos experimentos 2 e 3; três no silent do experimento 1.
- Erro de ~1 s na sonda do experimento 1.
- Ambiente virtualizado: tempos absolutos não representam hardware real.
