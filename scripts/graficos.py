#!/usr/bin/env python3
# Gera os graficos dos experimentos a partir de results/*.csv
import csv, os, statistics as st
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

os.makedirs("results/graficos", exist_ok=True)
COR = {"OSPF": "#1f77b4", "RIP": "#d62728", "BGP": "#2ca02c"}

def salvar(nome):
    plt.tight_layout()
    plt.savefig(f"results/graficos/{nome}.png", dpi=150)
    plt.close()

# ---- Exp 1: convergência ----
rows = list(csv.DictReader(open("results/exp1.csv")))
def vals(proto, modo):
    return [float(r["interruption_s"]) for r in rows if r["proto"] == proto and r["mode"] == modo]

fig, ax = plt.subplots(figsize=(6, 4))
for i, p in enumerate(["ospf", "bgp", "rip"]):
    v = vals(p, "silent"); m = st.mean(v)
    ax.bar(i, m, color=COR[p.upper()], yerr=[[m - min(v)], [max(v) - m]], capsize=6)
    ax.text(i, max(v) + 6, f"{m:.1f} s", ha="center")
ax.set_xticks(range(3)); ax.set_xticklabels(["OSPF", "BGP", "RIP"])
ax.set_ylabel("Interrupção do ping R1→R5 (s)")
ax.set_title("Convergência: falha silenciosa (netem 100%), 3 rep.")
salvar("exp1_silent")

fig, ax = plt.subplots(figsize=(6, 4))
w = 0.25
for j, rep in enumerate([1, 2, 3]):
    ys = []
    for p in ["ospf", "bgp", "rip"]:
        r = [float(x["interruption_s"]) for x in rows if x["proto"] == p and x["mode"] == "down" and int(x["rep"]) == rep]
        ys.append(r[0] if r else 0)
    ax.bar([k + (j - 1) * w for k in range(3)], ys, w, label=f"rep {rep}")
ax.set_xticks(range(3)); ax.set_xticklabels(["OSPF", "BGP", "RIP"])
ax.set_ylabel("Interrupção (s)"); ax.legend()
for k in (0, 1): ax.text(k, 0.3, "sem perdas", ha="center")
ax.set_title("Convergência: ip link down (erro ~1 s)")
salvar("exp1_down")

# ---- Exp 2: tráfego de controle ----
e2 = list(csv.DictReader(open("results/exp2.csv")))
nomes = [r["proto"].upper() for r in e2]
for col, rot, arq in [("pacotes_por_s", "Pacotes/s", "exp2_pacotes"), ("bytes_por_s", "Bytes/s", "exp2_bytes")]:
    fig, ax = plt.subplots(figsize=(6, 4))
    ys = [float(r[col]) for r in e2]
    ax.bar(nomes, ys, color=[COR[n] for n in nomes])
    for i, y in enumerate(ys): ax.text(i, y, f"{y:.2f}", ha="center", va="bottom")
    ax.set_ylabel(rot); ax.set_title(f"Tráfego de controle em regime estável ({rot}, R2 eth1-3)")
    salvar(arq)

# ---- Tabela de roteamento ----
# Lido de results/tabela.txt (saida do tabela.sh): coluna FIB da linha do protocolo.
import re
fib, atual = {}, None
for ln in open("results/tabela.txt"):
    m = re.match(r"===== (\w+)", ln)
    if m: atual = m.group(1); fib[atual.upper()] = []; continue
    if ln.startswith("--- r") and atual: fib[atual.upper()].append(0); continue
    c = ln.split()
    # BGP aparece separado em ebgp + ibgp; soma os dois
    if atual and len(c) >= 3 and c[0] in (atual, "ebgp", "ibgp"): fib[atual.upper()][-1] += int(c[2])
fib = {p: fib[p] for p in ["OSPF", "RIP", "BGP"]}
fig, ax = plt.subplots(figsize=(7, 4))
w = 0.25
for j, (p, ys) in enumerate(fib.items()):
    ax.bar([k + (j - 1) * w for k in range(5)], ys, w, label=p, color=COR[p])
ax.set_xticks(range(5)); ax.set_xticklabels([f"R{i}" for i in range(1, 6)])
ax.set_ylabel("Rotas do protocolo na FIB"); ax.set_ylim(0, max(max(v) for v in fib.values()) + 3); ax.legend(loc="upper right", ncol=3)
ax.set_title("Tamanho da tabela de roteamento")
salvar("tabela")

# ---- Complexidade de configuração ----
# Mesma regra do linhas.sh: linhas sem vazias e sem comentarios "!".
lin = {p.upper(): sum(1 for r in range(1, 6) for l in open(f"configs/{p}/r{r}/frr.conf")
                      if l.strip() and not l.strip().startswith("!")) for p in ["rip", "bgp", "ospf"]}
fig, ax = plt.subplots(figsize=(6, 4))
ax.bar(list(lin), list(lin.values()), color=[COR[k] for k in lin])
for i, y in enumerate(lin.values()): ax.text(i, y, str(y), ha="center", va="bottom")
ax.set_ylabel("Linhas úteis (5 roteadores)"); ax.set_title("Complexidade de configuração")
salvar("linhas")

# ---- Exp 3: RTT do R1 ao R5 ----
rtt = {"OSPF": (0.12, 100.8), "RIP": (0.09, 100.7), "BGP": (0.09, 100.7)}
fig, ax = plt.subplots(figsize=(6, 4))
for i, (p, (a, b)) in enumerate(rtt.items()):
    ax.bar(i - 0.15, a, 0.3, color="#888", label="baseline" if i == 0 else None)
    ax.bar(i + 0.15, b, 0.3, color=COR[p], label="+100 ms em R2-R5" if i == 0 else None)
    ax.text(i - 0.15, a, f"{a:.2f}", ha="center", va="bottom")
    ax.text(i + 0.15, b, f"{b:.0f}", ha="center", va="bottom")
ax.set_yscale("log")
ax.set_xticks(range(3)); ax.set_xticklabels(list(rtt)); ax.set_ylabel("RTT médio (ms, escala log)")
ax.set_ylim(0.03, 400); ax.legend(loc="center right")
ax.set_title("Nenhum protocolo evita o caminho lento")
salvar("exp3_rtt")
print("PNGs em results/graficos/")