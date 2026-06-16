# Outline — Relatório Técnico: Dois Desertos Hospitalares

**Título de trabalho:** *Dois Desertos: Acesso Hospitalar no Brasil sob Distância
e sob Fluxo Revelado* (EN: *Two Hospital Deserts: Distance vs. Revealed-Flow
Access in Brazil*)

**Tipo:** relatório técnico, descritivo. **Sem reivindicação causal** — o causal
mora no paper18 e é citado, não reivindicado aqui.

**Unidade:** município (~5570 nós). **Janela:** 2015–2022.

**Status das decisões de design (preencher):**
- Escopo do outcome: incluir overlay de mortalidade (§8)? [x] sim [ ] não
- Língua do relatório: [x] PT [ ] EN
- Medida primária de fluxo: [x] F1 burden efetivo [ ] F2 isolamento embedding [ ] F3 fragilidade

---

## Tese em uma frase

Desertos hospitalares medidos em quilômetros e desertos medidos pelo fluxo real
de pacientes não são o mesmo mapa — e o gap entre eles identifica municípios que
a política de acesso baseada em distância sistematicamente não enxerga.

## Decisão de design central

"Distância" é trivial: km / tempo OSRM ao hospital ativo mais próximo. "Fluxo"
carrega o relatório e admite 2–3 operacionalizações — apresentar mais de uma e
mostrar que concordam:

- **(F1) Burden efetivo de fluxo** — tempo de viagem ponderado por *para onde os
  pacientes realmente vão*, vs. burden ao hospital *mais próximo*. O gap entre os
  dois é a essência do conceito.
- **(F2) Isolamento no embedding** — distância latente ao hub mais próximo na
  rede de co-paciência (resume topologia, não só geometria).
- **(F3) Fragilidade / concentração** — HHI dos destinos, dependência de um único
  hub, share de fluxo que sai do município.

O *wow* não é cada medida isolada — é o **mapa da divergência**: municípios
*perto* em km mas *desertos* em fluxo (referral fraco, sem hub real) e o inverso.

## Ativos de dados reaproveitáveis do paper18

- `osrm_travel_time_panel`, `municipios_centroids` — distância/tempo
- `bipartite_edges`, `embeddings_node2vec`, `embeddings_munmun_proj` — fluxo
- `divergence_panel`, `flow_divergence_panel` — divergência já computada
- `flow_distance_disagreement_f5`, `disagreement_groups_long/summary` — perfis 2×2
- `hospital_master`, `hospital_closures` — universo de hospitais
- `ans_private_penetration` — moderador (saúde suplementar)
- `amenable_mortality(_redistributed)` — outcome do overlay §8

---

## Estrutura

### 0. Sumário executivo (1 pág)
Tese em uma frase + os 2–3 números que o relatório sustenta + o mapa-síntese da
divergência. Quem lê só isso entende o achado.

### 1. Motivação e as duas definições de deserto
- Por que políticas de acesso (maternity deserts, regionalização SUS) são
  desenhadas sobre **mapas de distância** — e por que isso é incompleto.
- Pacientes não viajam em linha reta nem ao ponto mais próximo: o fluxo revelado
  contradiz o mapa.
- **Pergunta do relatório (descritiva, não causal):** *Onde, e para quem, os dois
  conceitos discordam?*

### 2. Conceitos e definições operacionais
- **2.1 Deserto de distância** — deserto se tempo/km ao hospital ativo mais
  próximo (ou de dado nível de complexidade) excede limiar; reportar a medida
  contínua, não só o binário.
- **2.2 Deserto de fluxo** — F1/F2/F3 definidas formalmente. Justificar a primária;
  tratar as outras como robustez.
- **2.3 Taxonomia 2×2** — perto/longe (km) × conectado/isolado (fluxo). Os dois
  quadrantes off-diagonal são o objeto do relatório.

### 3. Dados e construção
- SIH (fluxos residência×CNES), CNES (universo ativo por ano), centroides IBGE,
  matriz OSRM, população. Janela 2015–2022.
- Firewall residência-vs-provedor; armadilhas SIH (AIH-1/AIH-5 não dobrar, só-SUS).
  Reaproveitar texto do paper18.
- Tabela de cobertura: N municípios, N hospitais, N internações.

### 4. O deserto de distância (descritivo)
- Choropleth Brasil; distribuição do tempo ao mais próximo; ranking por UF;
  correlação km × tempo OSRM (estradas de terra, balsas no Norte).

### 5. O deserto de fluxo (descritivo)
- Choropleth da medida primária; mapa do grafo reduzido município-município;
  embedding 2D (t-SNE/UMAP) por mesorregião com âncoras rotuladas.
- Burden efetivo de fluxo vs. burden ao mais próximo — o gap.

### 6. Comparação: concordância e divergência *(coração do relatório)*
- **6.1** Scatter fluxo × distância + loess + correlação; quanto um conceito é
  redundante com o outro.
- **6.2** Mapa da divergência (a Figure 1): os off-diagonal pintados.
- **6.3** Perfis dos quadrantes: "perto-mas-isolado" (renda, porte, atenção
  primária, penetração privada ANS) vs. "longe-mas-conectado". Usa
  `flow_distance_disagreement_f5` e `disagreement_groups`.
- **6.4** Casos canônicos por inspeção: 3–4 municípios narrados (capital,
  periferia metropolitana, sertão, fronteira).

### 7. Validação externa
- Os dois desertos batem com a regionalização administrativa (CIR/RIPSA)? Qual
  conceito recupera melhor as regiões de saúde conhecidas?
- Estabilidade do embedding (5–10 seeds, média±sd) — referee-proofing.

### 8. Overlay descritivo com mortalidade evitável *(correlacional, caveated)*
- Os dois desertos co-variam com mortalidade evitável (Nolte–McKee)? Qual conceito
  "explica" mais variação cross-section (R² descritivo, **não** causal).
- **Disciplina:** linguagem puramente associativa; o causal mora no paper18.

### 9. Implicações de mensuração e política
- Quantos municípios são deserto sob cada conceito? Quantos a distância **perde**
  (perto mas isolado)? Tradução em população exposta.
- O que muda para desenho de política se o regulador medisse fluxo em vez de km.

### 10. Limitações
- Só-SUS; fluxo endógeno à oferta (medida, não tratamento); subnotificação SIM no
  Norte; embedding como caixa-preta.

### Apêndice técnico
- Hyperparams do embedding + seeds; definições alternativas de fluxo (F1/F2/F3);
  sensibilidade a limiares de deserto; tabelas completas.

---

## Figuras esperadas

1. Choropleth — deserto de distância (Brasil).
2. Choropleth — deserto de fluxo (medida primária).
3. **Figure 1** — mapa da divergência, quadrantes off-diagonal pintados.
4. Scatter fluxo × distância + loess + correlação.
5. Embedding 2D (t-SNE/UMAP) por mesorregião, âncoras rotuladas.
6. (se §8) Cross-section mortalidade evitável × cada conceito.

## Disciplina

- Descritivo: linguagem associativa, nunca causal.
- Vector (PDF/SVG); paleta viridis/Okabe-Ito; eixos honestos; captions
  autoexplicativas (o quê, fonte, N, especificação).
- Seeds e versões travadas; telemetria em `04_logs/`.
