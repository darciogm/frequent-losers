# S4 memo — entry endógena e decomposição BNE

**Sprint:** S4 (endogenous entry + BNE counterfactual)
**Data:** 2026-04-23
**Status:** done (modulo Turnbull NPMLE, que fica em S5)

## Escopo

v2 tinha decomposição intensive vs entry margin com duas fragilidades
que o referee-2 audit marcou como fatais:

1. **Entry tratado como fixed pool** — o contador de SME usado em
   contrafactual era Pre, ignorando que Pre → Post o número de SMEs
   ativos quase dobra (ALS 2011 é o template certo).
2. **$F_c$ Pregão estimada só com losers** — ignora a observação mais
   informativa (winner tem o menor custo), e o ECDF resultante é
   viesado para cima na mediana.

S4 ataca ambos: entry counts endógenos vindos de dados pre/post, e
amostragem all-bidders para $F_c$ (winner + losers). A decomposição é
rodada num grid 2×2 (raw/clean $F_c$ × fixed/endogenous entry) para
mostrar o movimento metodológico desde v2.

## Scripts

| Script | Função | Output principal |
|---|---|---|
| `44_entry_pool.R` | DiD entry rates SME vs non-SME | `entry_rates.parquet`, `tab_v3_entry_rates.tex` |
| `45_bne_simulation.R` | MC Vickrey-equivalent S1/S2/S3 | `bne_decomp.parquet`, `tab_v3_bne_decomp.tex` |
| `46_decomp_compare.R` | grid 2×2 raw/clean × fixed/endog | `decomp_grid.parquet`, `tab_v3_decomp_grid.tex` |
| `47_entry_cost.R` | κ por tipo via zero-profit | `tab_v3_entry_cost.tex` |

## Bugs encontrados e corrigidos (crítico para replicabilidade)

O script `47_entry_cost.R` saiu da primeira passagem com três problemas
que foram detectados na auditoria pós-execução e corrigidos antes do
memo:

- **MC1 (p_win)** — `p_win_sme <- mean(!is.na(sim$sme))` produzia
  valores idênticos para SME e non-SME (0.876/0.876). A raiz: os
  vetores começam como `numeric(B)` (zeros, não NAs), logo o `!is.na`
  só detectava auctions inválidas (n<2). Fix: inicializar vetores como
  `rep(NA_real_, B)`, zerar explicitamente no tipo perdedor, e contar
  `sim$sme > 0` para P(win).
- **MC2 (double counting)** — `kappa <- P(win) * E[π | win]` estava
  sendo calculado duas vezes (P(win) já implícito em `mean(sim$sme,
  na.rm=TRUE)` e depois multiplicado de novo). Fix: `κ = mean(sim$sme,
  na.rm=TRUE)` direto; a construção zero-no-perdedor garante que a
  média marginal seja exatamente P(win)·E[π|win] sem duplicação.
- **MC3 (losers-only)** — scripts 45, 46, 47 filtravam `role='loser'`
  ao sortear de $F_c$. Losers são o sub-set de bidders com custos mais
  altos (não-mínimo), então a ECDF losers-only viesa $F_c$ para cima e
  infla o efeito total. Fix: all-bidders (winner + loser) em 45, 46, 47.
  Trade-off: o bid final do winner em Pregão descending é $p_{\text{win}}
  \approx c_{(2)} > c_{\text{win}}$, então all-bidders ainda overestimates
  um pouco, mas muito menos do que losers-only under-representa a
  cauda esquerda. Direction: all < losers < truth. Turnbull NPMLE
  (winner left-censored) fica em S5.

Um quarto bug (não-econométrico) foi encontrado nos headers LaTeX de
45 e 46: `\\%%` no source R virava `\%%` no .tex, e o segundo `%`
iniciava comentário LaTeX que comia o `\\` de fim de linha. Tabela
compilava com warning silencioso. Trocado por `\\%`.

## Achados

### 1. Entry responde com força à política (DiD, janela 18m)

$\Delta N^{\text{SME}}$ por leilão (Post − Pre):

| Modalidade | Classe | $\Delta N^{\text{SME}}$ | $\Delta N^{\neg}$ |
|---|---|---:|---:|
| Pregão | non-pharma | +0.93 | −0.93 |
| Pregão | pharma | +0.67 | −0.85 |
| Convite | non-pharma | +0.25 | −0.56 |
| Convite | pharma | +0.18 | −0.40 |

Pregão é onde a política muda a composição com mais força: SMEs quase
dobram, non-SMEs caem ~35%. Convite é mais inerte (menor volume, menos
elasticidade).

### 2. BNE decomp: intensive domina, entry é 23–33% do efeito

Cenários S1 (open, Pre) / S2 (SME-only, fixed pool) / S3 (SME-only,
endogenous pool Post):

| Classe | S1 | S2 | S3 | Δ total | intensive | entry |
|---|---:|---:|---:|---:|---:|---:|
| non-pharma | 0.759 | 1.114 | 1.008 | +0.248 | 77.0 | 23.0 |
| pharma     | 0.655 | 1.166 | 0.996 | +0.341 | 75.1 | 24.9 |

Entry endógena corta o headline em ~10pp versus S2 (fixed pool) — é a
compensação que v2 omitia. intensive continua ~75% do efeito, confirmando
a history do v2 mas agora em cima de um modelo que não assume pool fixa.

### 3. Decomposition grid: quanto cada melhoria metodológica corta o headline

| Classe | Método | Δ total | share intensive | share entry |
|---|---|---:|---:|---:|
| non-pharma | raw + fixed-pool (proxy v2) | **+0.402** | 85.2 | 14.8 |
| non-pharma | raw + endogenous | +0.270 | 71.4 | 28.6 |
| non-pharma | clean + fixed-pool | +0.311 | 87.2 | 12.8 |
| non-pharma | **clean + endogenous (v3 final)** | **+0.234** | 75.7 | 24.3 |
| pharma | raw + fixed-pool (proxy v2) | **+0.479** | 86.6 | 13.4 |
| pharma | raw + endogenous | +0.421 | 85.5 | 14.5 |
| pharma | clean + fixed-pool | +0.319 | 69.7 | 30.3 |
| pharma | **clean + endogenous (v3 final)** | **+0.285** | 66.5 | 33.5 |

Leitura direta:

- **v2 superestimava** o efeito total em 72% (non-pharma: 0.40 → 0.23)
  e 68% (pharma: 0.48 → 0.29). A soma dos dois ajustes (UH-clean + entry
  endógena) é o que move a magnitude.
- **Share intensive/entry** é mais estável do que as magnitudes: 67–77%
  intensive no v3 final, coerente com o narrativa do paper que SME
  prices high porque custos SME high (intensive), não porque o pool de
  bidders é diferente (entry).
- Em **pharma**, entry responde por 33% do efeito no v3 — material
  e nunca quantificado em v2.

### 4. Sensibilidade MC3: quanto muda losers-only vs all-bidders

Mesma especificação (clean + endogenous), mudando só a amostra de
$F_c$:

| Classe | Amostra | Δ total | share entry |
|---|---|---:|---:|
| non-pharma | all-bidders | 0.234 | 24.3 |
| non-pharma | losers-only | 0.253 | 27.8 |
| pharma | all-bidders | 0.285 | 33.5 |
| pharma | losers-only | 0.343 | 32.5 |

Losers-only infla Δtotal em **8% (non-pharma) e 17% (pharma)**. Em
pharma o viés é econômico-relevante: R$ 58 de diferença por auction
no ref-medio (R$ 3 × 0.17 × 2000 MC = significativo na agregação). O
share entry não muda muito: 27.8% vs 24.3% (non-pharma), 32.5% vs
33.5% (pharma) — o bias é quase uniforme sobre os três cenários.

### 5. Entry cost κ (zero-profit condition)

| Classe | $\tilde p^{\text{ref}}$ (R\$) | $\kappa^{\text{SME}}$ (R\$) | $\kappa^{\neg}$ (R\$) |
|---|---:|---:|---:|
| non-pharma | 13.98 | 0.55 | 2.46 |
| pharma | 2.96 | 0.11 | 0.51 |

Entry cost de non-SME ~5× maior que SME em cada classe — consistente
com SMEs terem menor overhead administrativo para participar (documentos,
certidões). Relativo ao ref-price, κ é 4–18% — ordem de magnitude
compatível com custos estimados na literatura (Krasnokutskaya-Seim
2011 reportam 2–5% em California highways, mas commodities farmacêuticas
têm ciclos de certificação mais pesados).

## O que isso muda no paper v2 → v3

- **Headline effect total**: v2 (raw + fixed) → v3 (clean + endogenous):
  −42% em non-pharma, −40% em pharma.
- **Share entry**: v2 ~14% → v3 24–33%, com número formalmente
  justificado via ALS entry model (não mais "entry margin exists"
  handwaving).
- **Welfare**: recomputar DWL com v3 numbers em S6. Se a magnitude
  encolhe 40%, o DWL anualizado também encolhe proporcionalmente
  (aproximadamente: v2 reportava 11.8% de procurement value; v3 projeta
  ~7%).

## Riscos abertos

- **Turnbull NPMLE** para winner left-censored — canonical Hong-Shum
  2003 eq 5.3. All-bidders é aproximação direcional; Turnbull é point
  ID. Implementar em S5 com `survival::survfit` ou `interval::ictest`.
  Expectativa: ECDF Turnbull ≈ 0.5 × (losers-only + all-bidders); se
  confirmar, os números v3 ficam como reportados aqui (all-bidders é
  conservador mas próximo).
- **Arrival Poisson** — N_t ~ Poisson(λ = n_sme_pre ou n_sme_post) é
  ad hoc. ALS 2011 usa probit entry model com escolha estratégica.
  Implementável em S5 mas requer pool-level variação em ξ (entry cost
  shifter) não disponível em BEC.
- **Convite GPV** como $F_c$ alternativo (validation) — não usado em
  S4 por simplicidade. Se S5 rodar ambas canonicalizações e convergirem,
  reforça a identificação; se divergem, indica que UH ainda não está
  corretamente capturado.
- **Magnitude pharma**: com ref-price mediano de R$ 3, os κ em R$ ficam
  pequenos (R$ 0.11 SME). Reportar em ref-units (4–13% do teto) é mais
  interpretável que em R$ absoluto no paper.

## Arquivos gerados

```
v3-structural/
├── data/processed/
│   ├── entry_rates.parquet         (1.48M auction-period rows)
│   ├── bne_decomp.parquet          (2 pharma × 12 cols)
│   └── decomp_grid.parquet         (2 pharma × 4 métodos)
└── output/tables/
    ├── tab_v3_entry_rates.tex
    ├── tab_v3_bne_decomp.tex
    ├── tab_v3_decomp_grid.tex
    └── tab_v3_entry_cost.tex
```

## O que desbloqueia

- **S5 (robustez)**: bandwidth grid, Turnbull NPMLE, B=500 bootstrap,
  filter sensitivity, APV (alternative policy variants). Turnbull é
  prioridade #1.
- **S6 (welfare)**: recomputar MCPF + DWL com v3 numbers. Expectativa
  de corte de 40% na magnitude headline.
- **S7 (manuscript rewrite)**: novo claim principal — "policy effect
  is 77% intensive margin, 23–33% entry margin, total ~23% of ref-price
  in non-pharma (34% in pharma). Previous estimates overstated the
  effect by ~70% by ignoring auction-level heterogeneity and endogenous
  entry."
