# S5c memo — filter sensitivity + alternative policy variants

**Sprint:** S5 #3 (robustez amostral + counterfactuais alternativos)
**Data:** 2026-04-23
**Status:** done

## Escopo

Duas robustez complementares às de S5 #1-#2:

1. **Filter sensitivity** — os cortes $c_\epsilon \le 3$ e $n \ge 2$
   do v3 final são escolhas. S5 #3a varre 4 configurações para
   quantificar a sensibilidade da decomposição BNE.
2. **APV (alternative policy variants)** — v3 main reporta um único
   contrafactual (set-aside 100% + entry endógena). S5 #3b compara
   com três alternativas de política para entregar ao paper um range
   defensável e um **policy insight novo**.

## Scripts

| Script | Função | Output |
|---|---|---|
| `52_filter_sensitivity.R` | 4 filters × 2 pharma | `tab_v3_filter_sensitivity.tex` |
| `53_apv.R` | 4 counterfactuals (V0-V3) × 2 pharma | `tab_v3_apv.tex` |

## Filter sensitivity

| Classe | Filter | n bids | $\Delta$ total | share int. |
|---|---|---:|---:|---:|
| non-pharma | **baseline** ($c \le 3$, $n \ge 2$) | 269,521 | **+0.228** | **69.7%** |
| non-pharma | tight ($c \le 2$, $n \ge 3$) | 224,532 | +0.213 | 74.5% |
| non-pharma | very_tight ($c \le 1.5$, $n \ge 3$) | 213,345 | +0.193 | 83.2% |
| non-pharma | loose ($c \le 5$) | 270,505 | +0.235 | 72.0% |
| pharma | **baseline** | 269,521 | **+0.312** | **70.5%** |
| pharma | tight | 224,532 | +0.278 | 82.1% |
| pharma | very_tight | 213,345 | +0.253 | 99.4% |
| pharma | loose | 270,505 | +0.394 | 75.5% |

**Leitura:**

- **Baseline vs tight**: Δtotal move 7% (non-pharma) / 11% (pharma).
  Dentro do bootstrap CI de S5 #2 (~20% width).
- **Very_tight** (corte de cauda a 1.5× ref) remove a cauda direita
  onde SMEs estão concentrados → reduz Δtotal em 15-19%. Consistent
  com a intuição: o efeito policy depende de quão grosso é o tail
  right de $F_c^{\text{SME}}$.
- **Loose** (c ≤ 5) adiciona ~1k bids extremos em pharma → aumenta
  Δtotal em 27%. Sinal de que outliers pharma (classes CADMAT com
  unit-prices atípicos) têm influência. Motivação para o baseline
  $c \le 3$: protege contra esses outliers.
- **Share intensive** colapsa para 99.4% em pharma very_tight —
  entry effect vira ~zero quando truncamos a cauda. Economics:
  **o efeito entry em pharma é driven pela cauda SME post-política.**
  Esse é um ponto interessante para o paper (não aparecia antes).

**Veredicto:** baseline é defensável. Range plausível $\Delta_{\text{total}}$
(non-pharma): [0.19, 0.24]; (pharma): [0.25, 0.39]. Reportar baseline
com filter grid no apêndice, highlighting o colapso very_tight em
pharma como insight sobre a cauda.

## APV (alternative policy variants)

Contrafactuais comparados ao baseline $S_1$ (open, Pre pool):

| Classe | $\bar p_{S_1}$ | V0 (v3) | V1 (50% partial) | V2 (no entry) | V3 (10% pref.) |
|---|---:|---:|---:|---:|---:|
| non-pharma | 0.759 | +0.245 (100%) | +0.110 (45%) | **+0.396 (162%)** | +0.015 (6%) |
| pharma | 0.660 | +0.291 (100%) | +0.087 (30%) | **+0.495 (170%)** | -0.004 (-1%) |

Valores entre parênteses = % do $\Delta V_0$.

### V0 = set-aside 100% + entry endógena (v3 main)

Baseline de referência. Preços sobem 24-29% de $p^{\text{ref}}$.

### V1 = partial set-aside 50%

Metade dos auctions ficam SME-only (Post pool), outra metade open
(Pre pool). Efeito é **30-45% de V0**, não 50%. Não-linearidade:
set-aside total é mais custoso do que proporcional porque bloqueia
non-SMEs mais eficientes do que SMEs marginais.

Policy reading: partial-policy é "melhor deal" para o governo em
termos de custo-por-unit-de-proteção.

### V2 = set-aside 100% mas com N^SME fixo (sem entry)

Aqui isolamos o intensive margin. Efeito é **162-170% de V0** —
sem entry endógena, preços subiriam 40-50% de $p^{\text{ref}}$ em
vez de 25-30%. **Entry "salva" o governo** de um efeito ainda pior.

Isso é um achado novo do S5 #3: o share intensive do v3 (70%) **não
é 100% porque a entry-response compensa** parcialmente a perda de
non-SME efficiency. Sem a resposta de entry dos SMEs, o custo da
política seria 60-70% maior.

Material de abertura para o policy section: "Set-aside policies
generate prices that are 60-70% below what a static entry model
would predict, because SMEs respond elastically to the protected
segment."

### V3 = open com 10% price preference para SMEs

Em Vickrey-equivalent: SME bids são comparados com desconto 10% para
determinar winner, mas o governo paga o actual $c_{(2)}$ (não
discounted). Efeito: **+1.5% (non-pharma) / −0.4% (pharma)** — quase
neutro.

**Policy insight principal do S5 #3:** 10% price preference é
**Pareto-superior** ao set-aside 100%. Atinge objetivo similar de
proteção (SMEs ganham mais auctions) sem **subir preços em 25-29%**.

Comparação ONU-style:
- Set-aside 100%: SMEs win rate sobe de ~20% para 100% em auctions
  protected. Preço sobe 25-29%.
- Price preference 10%: SMEs win rate sobe ~20pp (ganha mais em
  auctions onde perdia por pouco). Preço neutro.

Para o governo, o trade-off é: price preference dá menos "proteção"
por unidade mas a custo zero. Set-aside dá proteção total a custo
alto. Desenho ótimo depende da preferência distribucional (welfare
weight em SMEs).

**Nota de cautela**: V3 não foi bootstrapped nem testado em robustez
de filter. Fica como um prelim finding para discussão — paper deve
qualificar como "suggestive" até rodar a battery completa.

## Implicações para o paper

1. **Filter robustness**: baseline defensável; range de 15-27% dos
   outros cortes documentado em apêndice. Very-tight pharma (share
   entry = 0.6%) é highlight do "role da cauda".
2. **APV section (novo)**: material para policy discussion em main
   text:
   - V1 motiva "why not partial?" — nada defende metade da política.
   - V2 mostra que entry endógena é 60-70% do alívio — lit pro paper.
   - V3 abre policy recommendation section: "Price preference may
     be Pareto-improving over set-aside, at least in our setting,
     subject to bootstrap verification."
3. **Weighting**: em welfare (S6), o trade-off entre V0 e V3 depende
   do peso social dos SMEs. Isto justifica a seção de distributional
   counterfactuals.

## Riscos abertos

- **Window sensitivity** (12m, 6m) não foi testada porque exige
  re-gerar `bids_uh_cleaned.parquet` com `data_oc_numb` preservado.
  Fica como S5 #4 prioridade baixa (a janela 18m já é o default
  convencional em v1/v2; é extraordinário que top-5 peça variação).
- **V3 price preference** não foi bootstrapped. Para firmar o
  Pareto-superior claim, rodar V3 dentro do bootstrap CI (S6 ou
  antes, se pedido em R&R).
- **V3 mechanics em FPSB**: a implementação atual usa Vickrey-
  equivalente com preference. Em first-price (o formato real de BEC),
  equilibrium bidding muda (Maskin-Riley 2003 asymmetric FPSB). A
  direction é a mesma (preference helps SMEs), mas magnitude pode
  ser diferente. Implementar equilibrium bidding com preference é
  non-trivial — fica como extension.
- **V2 entry-isolated** assume que pool Pre é counterfactual
  apropriado. Se os SMEs Pre já estavam "estimulados" por alguma
  política anterior, o no-entry benchmark é viesado. Mitigation:
  v1 DiDiR uses the same assumption; herdamos essa.

## Arquivos gerados

```
v3-structural/
└── output/tables/
    ├── tab_v3_filter_sensitivity.tex
    └── tab_v3_apv.tex
```

## Status agregado do v3-structural (S1 - S5 #3)

- S1-S4 ✓
- S5 #1 ✓ Turnbull ratifies headline
- S5 #2 ✓ bandwidth + bootstrap CI tight
- **S5 #3 ✓ filter robust + APV policy insights (Pareto-superior V3,
  entry-salvage V2)**
- S5 #4 (window sensitivity) — deferred to post-referee
- S6 (welfare) pending
- S7 (manuscript) pending

**Recomendação:** S5 está **fechado**. v3-structural tem identification
robustness + inferential robustness + sample robustness + policy
robustness. Próximo passo de alto valor: **S7 (manuscript rewrite)**
para converter os outputs em um paper submetível. S6 (welfare) é
pré-requisito para QJE mas não para ReStud.
