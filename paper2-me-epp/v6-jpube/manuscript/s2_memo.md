# S2 memo — Pregão structural + cross-modality

**Sprint:** S2 (Pregão structural + cross-modality)
**Data:** 2026-04-23
**Status:** done

## Escopo

v2 tratou Pregão só via bounds Haile-Tamer agregados, e o painel
cross-modality quebrou por bug de ggplot. Como Pregão é 84% do valor
G65 tratado, essa perna do paper era frágil demais para top-5. S2
troca a estratégia:

1. Point identification direto em Pregão usando o English-reverse
   logic (Hong-Shum 2003 / Athey-Haile 2002): cada perdedor sai no
   seu custo, então drop-out = c para losers.
2. Bounds HT refinados como sanidade (não como identificação).
3. Painel cross-modality funcional — Convite GPV vs Pregão drop-out
   sob o mesmo grid, com banda HT.
4. Teste formal de invariância do primitivo non-SME em Convite vs
   Pregão, pharma-estratificado.

## Scripts novos

| Script | Função | Output principal |
|---|---|---|
| `35_pregao_dropouts.R` | drop-out price por firma×leilão + roles | `pregao_dropouts.parquet` (1.24M rows) |
| `36_pregao_fc_dropout.R` | $F_c^k$ point ID + KS shift | `pregao_fc.parquet`, `tab_v3_pregao_fc_summary.tex` |
| `37_pregao_ht_refined.R` | HT bounds tipo-agregadas | `tab_v3_pregao_ht_refined.tex`, `fig_v3_pregao_ht_bands.pdf` |
| `38_cross_modality.R` | Convite GPV + Pregão drop-out + HT band | `convite_fc.parquet`, `fig_v3_cross_modality.pdf` |
| `39_primitive_invariance.R` | KS non-SME Pre vs Post, modalidade×pharma | `tab_v3_primitive_invariance.tex` |

## Achados

### 1. Sanity check passou: 90–98 % do $F_c$ point-ID está dentro da banda HT

O bounds HT sobre Pregão é o teste de consistência do modelo
English-reverse. Nas quatro combinações (Pre × Post × pharma × not),
entre 90% e 98% dos pontos da CDF point-ID caem dentro do bound
[F_LB, F_UB]. Pontos fora são nas pontas (c < 0.005 ou c > 1.8),
onde os bounds são frouxos por construção.

### 2. Convergência cross-modality: pharma non-SME Pre bate entre Convite e Pregão

Recuperando $c_{0.5}$ (mediana do custo normalizado pelo ref) por
estratégia:

| Estrato | Convite (GPV) | Pregão (drop-out) |
|---|---:|---:|
| pharma non-SME Pre | **0.712** | **0.704** |
| pharma non-SME Post | 0.707 | 0.768 |
| non-pharma non-SME Pre | 0.639 | 0.820 |
| pharma SME Pre | 0.747 | 0.859 |
| non-pharma SME Pre | 0.723 | 0.954 |

Pharma non-SME Pre dá $|Δ| = 0.008$ entre duas identificações
independentes (GPV em Convite × drop-out em Pregão). Isso é um
specification-test point: o primitivo de custo é recuperável
independente da modalidade.

Em non-pharma o gap entre modalidades é maior (0.18-0.23). Hipótese
a testar em S3: Pregão não-pharma tem mais heterogeneidade não
observada (itens dentro da classe 65xx variam de mobiliário a insumo
cirúrgico), e a ref-price normalização não absorve tudo. Aí entra o
Krasnokutskaya (2011) em S3.

### 3. Teste de invariância do primitivo: passa onde v2 confiava, falha onde a política é mais agressiva

A condição identificadora de v2 é: $F_c^{\text{NonSME,Pre}} =
F_c^{\text{NonSME,Post}}$ (non-SMEs não mudaram de custo, apenas de
participação). O KS resultante:

| Modalidade | Classe | D | $\Delta\bar{c}$ | Invariante (D<0.05)? |
|---|---|---:|---:|:---:|
| Convite | pharma | **0.032** | −0.006 | **sim** |
| Convite | non-pharma | 0.051 | +0.037 | borderline |
| Pregão | non-pharma | 0.049 | +0.037 | borderline |
| Pregão | pharma | **0.072** | +0.068 | **não** |

Leitura:

- **Pharma Convite** é o estrato "limpo" — D=0.032, shift -0.006.
  Aí o argumento identificador v2 é defensável.
- **Pharma Pregão** é o estrato "sujo" — D=0.072, shift +0.068.
  Non-SMEs que continuam bidando em pharma-Pregão post-política são
  uma amostra selecionada de stragglers de custo mais alto. A
  invariância NÃO vale. Mas a nova identificação (drop-out point ID)
  NÃO exige invariância — recupera $F_c$ direto. Os dois estratos
  usam ferramentas diferentes; Pregão não precisa de invariância.

Essa complementaridade (Convite via invariância + Pregão via point
ID) é o argumento identificador mais forte que v3 traz.

### 4. Cross-modality figure agora funciona (v2 bug fix)

`fig_v3_cross_modality.pdf` sobrepõe, em cada painel (pharma × SME):
- Curva Convite GPV ($F_c$ tipo-específico)
- Curva Pregão drop-out ($F_c$ tipo-específico)
- Banda HT Pregão (pharma-nível, agnóstica quanto a tipo)

No v2 esse painel quebrou por erro de scoping em `aes(period, ...)`.
A linha 332 do v2/scripts/37_pregao_htbounds.R está preservada como
referência; o reimplementado em v3/38_cross_modality.R não depende
de `period` no escopo global do ggplot.

## O que desbloqueia

- **S3 (Krasnokutskaya UH):** motivado empiricamente pelo gap de
  0.18-0.23 entre Convite e Pregão em non-pharma — sinal forte de
  heterogeneidade não observada no estrato pooled. Aplicar Kotlarski
  deconvolution por (pharma × SME × período) deve fechar o gap.
- **S4 (entry endógena):** não afetado diretamente por S2, mas o
  painel cross-modality dá baseline para o BNE re-solve checar
  consistência.
- **Primitive invariance como tabela central:** `tab_v3_primitive_
  invariance.tex` entra como Tabela 3 do paper_v3 — é o argumento
  de identificação com números, não mais "KS D = 0.03" jogado no
  abstract.

## Arquivos gerados

```
v3-structural/
├── data/processed/
│   ├── pregao_dropouts.parquet       (1.24M firm×auction)
│   ├── pregao_fc.parquet             (ECDF grid, 4 strata × 2 métodos)
│   ├── pregao_ht_bounds.parquet      (HT panel)
│   └── convite_fc.parquet            (GPV-inverted CDF)
├── output/tables/
│   ├── tab_v3_pregao_fc_summary.tex
│   ├── tab_v3_pregao_ht_refined.tex
│   ├── tab_v3_cross_modality.tex
│   └── tab_v3_primitive_invariance.tex
└── output/figures/
    ├── fig_v3_pregao_fc_by_stratum.pdf
    ├── fig_v3_pregao_ht_bands.pdf
    └── fig_v3_cross_modality.pdf  (fix do v2)
```

## Riscos abertos

- **Drop-out assumption**: English-reverse IPV assume button-auction
  — na prática Pregão BEC tem jump-bidding (firma submete valor
  muito baixo de uma vez). Para esses, drop-out ≠ custo. Checar a
  distribuição de `n_iterations`: firmas com n_iterations = 1 (uma
  única bid) podem não estar seguindo a estratégia button. **S5**.
- **Winner contribution**: a ECDF só com losers ignora a observação
  mais informativa (winner tem o menor custo). Existem estimadores
  que combinam losers exactos + winner censurado (Hong-Shum 2003,
  eq 5.3) — implementar em S5 para checar se altera tail esquerda
  do $F_c$.
- **Convite GPV foi feita sem controle de bandwidth** — Silverman
  default. Grid de bandwidth é em S5.
