# S1 memo — data foundations for v3-structural

**Sprint:** S1 (data foundations)
**Data:** 2026-04-23
**Status:** done

## Escopo

Preparar o bid-level de G65 com (i) um flag SME por lance validado
contra os counts históricos do BEC e (ii) estratificação pharma que
separa CMED-regulados (classe 6531 etc.) dos equipamentos e insumos.
Sem isso, as sprints S3 (Krasnokutskaya UH) e S4 (Athey–Levin–Seira
entry) herdam o mesmo proxy bias e a mesma heterogeneidade pooled que
v2 carregou.

## O que foi feito

1. **Extração do universo G65** via stream do CSV cru (6.4 GB) —
   `scripts/_extract_g65_keys.py` grava `data/processed/g65_keys.parquet`
   com chaves, classe CADMAT, preço-ref, `data_oc_numb` e os counts
   históricos `numfornecs_type_me/epp/oth_ph*`.

2. **Construção de quatro proxies SME** a partir do `Firms_final`:
   - `sme_porte` — Receita (porte\_empresa ∈ {01, 03})
   - `sme_bec` — BEC (fornec\_enquad ∈ {1, 2, 3, 4, 5})
   - `sme_either` — união
   - `sme_both` — interseção

3. **Audit proxy vs histórico** (`scripts/32_historical_sme.R`):
   cruza os quatro proxies contra `numfornecs_type_me + epp` por leilão.

4. **Flag pharma** (`scripts/33_pharma_flag.R`): CADMAT narrow
   (6531/6532/6536/6581) e broad (+ reagentes, soluções, biológicos).

5. **Descritivas estratificadas** (`scripts/34_s1_descriptives.R`):
   tabela de massa, bidders, HHI, preço-ref por
   modalidade × período × pharma × SME.

## Achados que mudam o paper

### 1. Proxy RF superestima SME em 1,4–3,3 firmas por leilão

| Proxy | Convite exact | Pregão exact | Pregão bias |
|---|---:|---:|---:|
| `sme_porte` (Receita) | 25.6 % | 48.0 % | **+3.19** firmas |
| `sme_bec` (BEC) | **54.4 %** | **54.2 %** | +2.20 firmas |
| `sme_either` | 23.1 % | 46.9 % | +3.27 firmas |

A concordância porte × BEC é **44%** (κ=0.12). São medidas quase
ortogonais. O `sme_bec` bate melhor porque o histórico
`numfornecs_type_me/epp` vem da mesma fonte BEC.

**Implicação para v3:** default é `sme_bec`. `sme_porte` (o que v2
usava) entra como robustez em S5.

### 2. Bias post-policy > bias pre-policy (Pregão)

| | Pre MAE | Post MAE |
|---|---:|---:|
| Pregão | 3.06 | **7.16** |
| Convite | 1.34 | 1.69 |

O bias de proxy dobra depois de março/2018 no Pregão. Isso é
**exatamente o tipo de problema que contamina a decomposição de v2**:
se o erro da proxy é diferencial por regime, a diferença
Pre→Post mistura efeito da política com drift do proxy. S3 precisa
usar exclusivamente `sme_bec`.

### 3. Pharma e não-pharma são mercados diferentes

| mod | classe | N leilões | Med.\ ref (R\$) | HHI | Avg.\ $N$ bidders |
|---|---|---:|---:|---:|---:|
| Convite | pharma    | 9,247  | 2.14 | 370–456 | 2.73–2.82 |
| Convite | non-pharma | 33,161 | 22.00 | 216–240 | 2.85 |
| Pregão  | pharma    | 60k    | 2.84 | 294–368 | 2.88–3.16 |
| Pregão  | non-pharma | 61k    | 18.32 | 123 | 3.38–3.62 |

Preço-ref mediano é **10× maior fora de pharma**. HHI 2× maior em
pharma — dominado por distribuidoras de medicamentos (CMED-regulado).
Pooling sem estratificar é um IPV-violation óbvio.

### 4. Resposta de entrada Pre→Post é pharma-heterogênea

| mod | classe | Δ SME bidders | Δ non-SME bidders |
|---|---|---:|---:|
| Convite | non-pharma | **+0.47** | **−0.48** |
| Convite | pharma     | −0.05 | +0.14 |
| Pregão  | non-pharma | **+0.93** | **−1.18** |
| Pregão  | pharma     | +0.67 | −0.95 |

**Em pharma-Convite a política praticamente não deslocou o pool.**
A manchete v2 (“SME +52%”) é puxada por não-pharma; pharma contribuiu
quase zero. Se a heterogeneidade sobreviver à decomposição em S3/S4,
isso vira **achado novo do paper**, não robustez.

## O que desbloqueia

- **S2 (Pregão descending-clock):** usar `sme_bec` + pharma como
  covariates; estratificar a inversão bid-dropping por pharma.
- **S3 (Krasnokutskaya UH):** a heterogeneidade observada entre pharma
  e não-pharma motiva a deconvolução; os dois grupos são condicionantes
  óbvios antes do Kotlarski por estrato.
- **S4 (entry endógena):** a diferença de Δ-entry não-pharma × pharma
  sugere que a entry cost κ varia por tipo de item. Modelar
  `κ^{k, pharma}` separado de `κ^{k, non-pharma}`.
- **S5 (robustness):** grid de proxies SME (porte, bec, either, both),
  bandwidth grid, B=500.

## Arquivos gerados

```
v3-structural/
├── data/processed/
│   ├── g65_keys.parquet               (782k rows, 33 cols)
│   ├── bid_level_sme_g65.parquet      (5.83M bids, 4 proxies)
│   ├── bid_level_sme_pharma_g65.parquet (5.83M bids, +pharma)
│   └── g65_proxy_audit.parquet        (detalhe do audit)
├── output/tables/
│   ├── tab_v3_sme_proxy_audit.tex
│   ├── tab_v3_pharma_counts.tex
│   └── tab_v3_s1_handoff.tex
└── logs/
    ├── 32_historical_sme.log
    ├── 33_pharma_flag.log
    └── 34_s1_descriptives.log
```

## Riscos abertos

- Cobertura do registro é 90.3% (Convite) e 96.6% (Pregão). Os 3–10%
  sem registro vão para NA — não para uma categoria residual. Conferir
  se esses leilões estão concentrados em algum período ou classe; se
  estiverem, a perda vira seleção endógena.
- O audit compara proxy atual com counts históricos mas os counts
  históricos podem refletir uma noção operacional de SME ligeiramente
  diferente de `fornec_enquad` (ex: contabilizam cooperativas?).
  Checar a documentação do BEC em S2.
- Pharma-narrow é 40% da massa; pharma-broad 50%. Rodar S3/S4 com as
  duas definições e reportar a mais conservadora no main text.
