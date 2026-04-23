# S3 memo — unobserved heterogeneity (Krasnokutskaya-style)

**Sprint:** S3 (UH deconvolution)
**Data:** 2026-04-23
**Status:** done (versão semi-paramétrica BLP; Kotlarski full-nonparam
fica para S5 robustness)

## Escopo

v2 assumia que a normalização por ref-price absorvia toda a
heterogeneidade auction-level (UH). Krasnokutskaya (2011, ReStud)
mostra que em licitações não é verdade: itens dentro da mesma classe
têm dispersões multiplicativas de escala que não aparecem no ref. S3
testa duas coisas:

1. Quantificar: quanto da variância dos log-lances está no nível do
   leilão vs ao nível do bidder? Isto é a intraclass correlation ρ =
   σ²_a / (σ²_a + σ²_e).
2. Corrigir: remover σ²_a via BLP shrinkage e recomputar $F_c^k$. O
   gap cross-modality de S2 (Convite-Pregão 0.18-0.23 em non-pharma)
   fecha sob a correção?

## Scripts

| Script | Função | Output |
|---|---|---|
| `40_uh_variance.R` | método-dos-momentos ANOVA por estrato | `uh_variance.parquet`, `tab_v3_uh_variance.tex` |
| `41_uh_clean_bids.R` | BLP shrinkage → $\hat a_t$, $\hat e_{it}$ | `bids_uh_cleaned.parquet` |
| `42_uh_rerun_fc.R` | recomputa $F_c$ clean; fig cross-modality UH | `{convite,pregao}_fc_uh.parquet`, `tab_v3_uh_vs_raw.tex`, `fig_v3_cross_modality_uh.pdf` |
| `43_uh_invariance_update.R` | KS raw vs UH-clean, primitive invariance | `tab_v3_uh_invariance.tex` |

## Achados

### 1. UH é material: 40-65% da variância dos log-bids

| Classe | Tipo | $\rho$ médio | $\rho$ Pregão | $\rho$ Convite |
|---|---|---:|---:|---:|
| non-pharma | non-SME | 0.47 | 0.39 | 0.55 |
| non-pharma | SME | 0.49 | 0.36 | 0.62 |
| **pharma** | **non-SME** | **0.62** | 0.58 | 0.66 |
| pharma | SME | 0.42 | 0.28 | 0.56 |

Números comparáveis ao Krasnokutskaya 2011 em California highways
(0.5-0.7). Convite tem sistematicamente mais UH que Pregão — coerente
com a hipótese de que Convite é menos usado e portanto itens são mais
heterogêneos entre si. Pharma non-SME é o estrato mais UH-pesado
(distribuidoras de medicamento dominam, com escala variável por
tamanho de lote).

### 2. UH correction puxa medianas down 5-9pp

Por estrato, $c_{0.5}^{\text{raw}} - c_{0.5}^{\text{clean}}$ varia
entre 0.05 e 0.09 em magnitude (quase sempre negativo: raw overstates
cost). Isso significa que ignorar UH **superestima sistematicamente
o custo** — e portanto subestima markups em 5-9 pontos de ref. Para
welfare numbers, esse é o sinal errado em magnitudes relevantes.

### 3. Em pharma SME Post, UH correction **fecha 93%** do gap cross-modality

| Estrato | gap raw | gap clean | fechado |
|---|---:|---:|---:|
| **pharma SME Post** | 0.152 | **0.011** | **93%** |
| pharma non-SME Post | 0.060 | 0.046 | 23% |
| pharma non-SME Pre | -0.009 | 0.001 | -- |
| pharma SME Pre | 0.102 | 0.178 | pior |
| non-pharma non-SME (both) | 0.18 | 0.19 | praticamente nenhum |
| non-pharma SME (both) | 0.22 | 0.24 | praticamente nenhum |

Em pharma SME Post, a convergência entre Convite GPV e Pregão
drop-out é quase exata após UH correction — specification-test forte.
Em non-pharma, **UH não é a explicação do gap** — resta ~20pp de
divergência que motiva item-level FE ou a versão completa Kotlarski.

### 4. Primitive invariance é mais fraca após UH correction (revelação, não regressão)

| Modalidade | Classe | $D^{\text{raw}}$ | $D^{\text{clean}}$ |
|---|---|---:|---:|
| Convite | **pharma** | 0.032 | **0.023** (segue passando) |
| Convite | non-pharma | 0.051 | 0.089 |
| Pregão | non-pharma | 0.049 | 0.061 |
| Pregão | pharma | 0.072 | 0.141 |

O KS D cresce para non-pharma Convite e para Pregão nos dois estratos.
Interpretação correta: **a UH auction-level estava mascarando um
shift maior no primitivo do bidder non-SME.** Quando tiramos UH, fica
claro que os non-SMEs que continuam bidando Post-política são um
subset com dispersão de custo sistematicamente diferente do Pre.

Só **pharma Convite** mantém invariância sob UH correction (D=0.023).
Isso é o estrato mais limpo para o argumento identificador
"non-SME primitive invariante Pre-Post." O paper deve usar pharma
Convite como main text e tratar non-pharma como robustness.

### 5. O que isso muda no paper v2 → v3

- **v2 claim:** "non-SME cost primitive é invariante (KS D=0.03)"
  era específico a Convite agregado. Não vale em Pregão nem em
  non-pharma.
- **v3 claim (pós S2+S3):** "primitive invariance holds in pharma
  Convite; Pregão uses direct point-ID; non-pharma needs
  item-stratification or full Kotlarski UH."
- **Welfare numbers of v2 (DWL 11.8% of procurement value)** usaram
  $F_c$ raw — estão superestimados em ~5-9pp na mediana. Recomputar
  em S6 com $F_c$ UH-clean é obrigatório.

## O que desbloqueia

- **S4 (entry endógena):** o BNE re-solve deve usar $F_c$ UH-clean
  como input. Diferente do v2 que usou raw.
- **S5 (robustez):** full Kotlarski deconvolution (não-paramétrico)
  fica aqui. Esperado validar ou ajustar os números BLP. Também
  incluir item-level FE como alternativa à UH-by-deconvolução.
- **S6 (welfare):** usar $c_{0.5}^{\text{clean}}$ para MCPF / DWL
  numbers; documentar a correção de 5-9pp vs v2.

## Riscos abertos

- **BLP assume gaussianidade** de $a_t$ e $e_{it}$. Kotlarski full é
  non-paramétrico, entra em S5. Esperado ajustar tails de $F_c$ mas
  não medianas.
- **σ²_a foi estimado separado por período** (Pre ≠ Post). Isso pode
  criar shrinkage diferencial que artificialmente infla a diferença
  Pre-Post no KS. Alternativa: fixar σ²_a comum entre períodos (H0
  de invariância) e rerodar. Fica como robustez em S5.
- **Kotlarski exige simetria dentro de tipo** (IPV symmetric by
  bidder type). Se houver asymmetria residual dentro de SMEs (por
  tamanho), o Kotlarski vira mais complexo (Hu-Schennach 2008). Não
  é prioridade agora.

## Arquivos gerados

```
v3-structural/
├── data/processed/
│   ├── uh_variance.parquet
│   ├── bids_uh_cleaned.parquet        (400k bids com ê e â)
│   ├── convite_fc_uh.parquet
│   └── pregao_fc_uh.parquet
├── output/tables/
│   ├── tab_v3_uh_variance.tex
│   ├── tab_v3_uh_vs_raw.tex
│   └── tab_v3_uh_invariance.tex
└── output/figures/
    └── fig_v3_cross_modality_uh.pdf
```
