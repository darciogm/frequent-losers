# Parecer Estrategico — mr-frequent (Modo Revisor + Ultrathink)

**Data:** 2 de abril de 2026
**Objeto:** Decisao estrategica entre tres opcoes de submissao
**Papers avaliados:**
- P1 = "Screening for Bid Rigging with Frequent Losers" (78 pp, elsarticle)
- P2 = "Cover Bidding in Public Procurement: A Structural Model of the Dispersion Paradox" (54 pp, article)

---

## 1. DIAGNOSTICO DO ESTADO ATUAL

### 1.1 Paper Screening (P1) — 78 paginas

**Pontos fortes:**
- Narrativa limpa e auto-contida: FL como tela de deteccao, validacao contra CADE, mecanismos, robustez
- Bateria empirica impressionante: OLS + CEM + IPW + cross-fit + IV (diagnostico) + Bajari-Ye + C&S DiD + 14 checks de robustez
- CADE validation com AUC = 0.94 e 3 firmas condenadas que sao FL — evidencia rara e poderosa
- 5 testes de mecanismo (M1-M5) bem organizados
- Secao de limitacoes honesta
- Modelo estrutural presente mas compactado (84 linhas, ~3 paginas) — serve como framework motivador, nao como contribuicao central
- Apendice massivo e bem organizado (623 linhas, ~70 figuras/tabelas)
- Compilacao funcional, sem TODOs

**Vulnerabilidades criticas (olhar de Referee 2):**
1. **Identidade confusa**: O paper *diz* que eh screening mas *inclui* modelo estrutural com 4 proposicoes no corpo principal. Referee vai perguntar: "Se o modelo nao eh contribuicao, por que esta no corpo? Se eh contribuicao, por que o titulo diz screening?"
2. **Pre-trends no event study**: P1 reconhece mas interpreta como market selection. Referee cético vai dizer: "Se ha pre-trends, o DiD nao identifica nada — e voce esta chamando isso de evidencia?"
3. **IV como 'diagnostico'**: Framing inteligente mas fragil. Balance tests falham, e o paper admite. Referee: "Entao qual eh a estrategia de identificacao? OLS com FE? Isso nao identifica efeito causal de FL sobre precos."
4. **AUC 0.94 com N=65 CADE cases**: Amostra de validacao minuscula. Referee: "65 casos de cartel — quanto disso eh overfitting? Onde esta o out-of-sample?"
5. **78 paginas**: Longuissimo para qualquer journal. RAND/ReStat tipicamente quer 40-50 pp com apendice online.
6. **N inconsistencia**: 1,654,401 vs. 1,654,447 aparece em dois pontos diferentes.

**Maturidade editorial:** 8/10 — pronto para submissao apos cortes e ajustes.

### 1.2 Paper Structural (P2) — 54 paginas

**Pontos fortes:**
- Contribuicao teorica clara: modelo de cover bidding com 2 regimes, calibracao, counterfactuals
- "Dispersion paradox" (sigma_c/sigma_g = 0.72) eh resultado genuinamente interessante e original
- 5 testes de especificacao em 3 tiers de valor probatorio — organizacao excelente
- Counterfactuals bem calibrados com disclaimers honestos
- Paragrafo "What the paper does and does not claim" — transparencia rara
- Comprimento adequado (54 pp)

**Vulnerabilidades criticas:**
1. **PROBLEMA TECNICO GRAVE: sec_appendix.tex ORFAO**: O paper_structural.tex so inclui sec_appendix_p2.tex (provas + tabelas estruturais). O sec_appendix.tex (261 linhas com robustez reduced-form, DiD, competition outcomes, heterogeneidade) NAO COMPILA. Isso significa que o PDF de 54 paginas esta INCOMPLETO — faltam dezenas de tabelas e figuras referenciadas no corpo.
2. **Labels duplicados**: app:did, app:robustness, app:extensions existem em ambos os appendix files — vai gerar warnings/erros de cross-reference.
3. **Mecanismos orfaos**: sec_mechanisms.tex (106 linhas com M1-M3, racionalidade, bid rotation) existe mas NAO esta incluido no documento ativo. O paper estrutural nao apresenta nenhum teste de mecanismo formalmente.
4. **Reduced-form como afterthought**: OLS/matching/IV aparecem em sec6 como "Additional Evidence" (sec 6.5-6.6) mas sem a bateria de robustez que existe em P1. Para um referee, isso parece incompleto.
5. **Calibracao depende de modelo**: gamma, c1, phi0 sao estimados condicionais no modelo estar correto. Se o referee nao comprar o modelo, toda a Secao 7 (counterfactuals) cai.
6. **Inconsistencia nos IQR variants**: sec8_robustness mostra 0.060/0.050 vs. sec_robustness (orfao) mostra 0.071/0.091. Qual eh correto?
7. **Companion paper citado mas nao publicado**: `\citep{genicolomartins2026screening}` — referee pode recusar se o companion nao estiver disponivel.

**Maturidade editorial:** 5/10 — precisa de trabalho significativo para compilar corretamente e completar o apendice.

---

## 2. MAPA DE OVERLAP

### 2.1 Conteudo compartilhado (identico ou quase identico)

| Elemento | P1 | P2 | Natureza |
|----------|----|----|----------|
| Definicao de FL (IQR threshold) | sec4_data_fl | sec4_data_fl | Identico |
| tab_desc_stats | corpo | corpo | Identico (mesmo arquivo) |
| tab_prices (OLS principal) | corpo | sec6_results | Identico |
| tab_iv_main | apendice | orfao (sec_appendix) | Identico |
| Bajari-Ye corrected | apendice | sec6 + appendix_p2 | Identico |
| tab_network_split | corpo | orfao (sec_appendix) | Identico |
| CADE validation (AUC, co-participation) | sec_cade (corpo) | sec4_data (breve) | Parcial |
| fig_roc_comparison | apendice | sec6_results | Identico |
| fig_fl_entry_event_study | apendice | sec6_results | Identico |
| fig_counterfactual_screening | apendice (counterfactual) | sec7 (corpo) | Identico |
| tab_counterfactual_welfare | apendice | sec7 (corpo) | Identico |
| fig_07_threshold_stability | apendice | sec8 | Identico |
| Provas (Props 1-4) | sec_appendix | sec_appendix_p2 | Identico |
| DiD (C&S + stacked) | sec_robustness + apendice | sec8 + orfao | Identico |
| Classification (IQR vs RF vs LCA) | apendice | orfao + appendix_p2 | Identico |

### 2.2 Conteudo exclusivo de cada paper

**Exclusivo P1:**
- 5 testes de mecanismo completos (M1-M5) no corpo
- Secao de limitacoes formal
- CADE como secao de corpo completa (3 pp)
- Apendice online massivo (~40 items)
- Cox survival, dyadic permutation, Oster delta, density shift
- Ground truth tests, identification evidence subsections

**Exclusivo P2:**
- Modelo estrutural completo (487 linhas, ~15 pp): environment, cartel problem, participation, distributions, market selection, likelihood, identification, predictions
- Calibracao de primitivas (gamma, c1, phi0)
- 3 counterfactuals formais com welfare function
- QQ-plot de regime 2
- "Dispersion paradox" como resultado central
- Specification tests em 3 tiers
- Paragrafo de honestidade ("what the paper does and does not claim")

### 2.3 Quantificacao do overlap

**Estimativa:** ~40-50% do conteudo empirico eh compartilhado. A diferenciacao real esta em:
- P1: breadth empirica (mecanismos, CADE, robustez extrema)
- P2: depth teorica (modelo, calibracao, counterfactuals)

---

## 3. AVALIACAO DAS TRES ESTRATEGIAS

### Estrategia (a): Separar completamente e submeter a dois journals distintos

**Viabilidade:** MEDIA-BAIXA

Para separar completamente:
- P1 perderia o modelo estrutural que motiva as predictions — viraria puramente ateórico, o que eh problematico para top-field journals
- P2 perderia os reduced-form results que ancoram o modelo — ficaria um exercicio teorico sem validacao empirica convincente
- Cada paper precisaria reescrever a definicao de FL e os dados sem overlap — artificialmente mais fraco
- O "companion paper" citation se torna critico — se um nao estiver publicado, o outro fica incompleto
- Risco de desk reject se editor perceber que sao dois papers do mesmo projeto com dados identicos

**Para funcionar**, seria preciso:
- P1: substituir o modelo formal por uma motivacao intuitiva (2-3 paragrafos, sem proposicoes)
- P2: dropar TODOS os reduced-form results do corpo, manter so no apendice como "companion confirms"
- Submissoes simultâneas a journals que nao tenham editores em comum
- Cada paper precisaria ser auto-contido sem depender do outro

**Esforco estimado:** ALTO (reescrita substancial de ambos)
**Risco:** ALTO (companion nao publicado, overlap percebido, cada paper mais fraco sozinho)
**Recompensa potencial:** 2 publicacoes se ambos forem aceitos

### Estrategia (b): Fundir em um unico paper

**Viabilidade:** MEDIA-ALTA

O paper fundido teria:
- Modelo estrutural como framework motivador (compactado, ~8 pp)
- Reduced-form como evidencia principal (~8 pp)
- Structural estimation + calibracao (~5 pp)
- CADE validation (~2 pp)
- Mecanismos (~4 pp)
- Counterfactuals (~3 pp)
- Robustez (~3 pp)
- Total corpo: ~45-50 pp + apendice online

**Vantagens:**
- Narrativa mais poderosa: teoria → evidencia → validacao → implicacoes
- Nenhum "companion paper" problem
- Um unico paper forte para RAND/ReStat
- Todo o conteudo se complementa naturalmente
- Resolve o problema de identidade de P1 (inclui modelo) e de P2 (inclui robustez)

**Desvantagens:**
- Extensao: 50+ pp pode assustar editores de RAND (limite tipico 35-40 pp corpo)
- Risco de "too many things" — referee pode dizer "pick your contribution"
- Sacrifica uma publicacao potencial
- Trabalho de integracao nao-trivial (reconciliar tonalidades, eliminar redundancias)

**Esforco estimado:** MEDIO (integracao, nao reescrita)
**Risco:** MEDIO (extensao, foco disperso)
**Recompensa potencial:** 1 publicacao em top-5/top-field

### Estrategia (c): Focar no melhor paper e aperfeicoar

**Viabilidade:** ALTA

**Qual eh o melhor paper no estado atual?**

**P1 (Screening) eh claramente superior**, por estas razoes:
1. **Maturidade**: 8/10 vs 5/10. P1 compila, P2 tem appendix orfao.
2. **Completude**: P1 tem todos os resultados, mecanismos, robustez. P2 falta mecanismos, robustez reduced-form incompleta.
3. **Vendabilidade**: "Novel screening tool validated against actual cartel convictions" eh um pitch imediatamente compreensivel. "Structural model of cover-bid dispersion" eh niche.
4. **CADE como killer feature**: AUC 0.94 contra convicções reais eh o tipo de resultado que editores de RAND/JLE lembram. P2 menciona CADE marginalmente.
5. **Extensibilidade**: P1 pode absorver o modelo como appendix sem perder nada. P2 nao pode absorver os mecanismos facilmente.
6. **Robustez**: 14 checks + 5 mecanismos + Cinelli-Hazlett + Oster + Cox survival. P2 tem robustez mais fina.
7. **Target journals**: P1 cabe em RAND, ReStat, JLE, IJIO. P2 cabe em IJIO, JLEO (mais estreito).

**O que P1 precisa para ficar pronto:**
- Cortar de 78 para ~45 paginas (mover modelo formal para appendix, compactar mecanismos)
- Resolver N inconsistencia (1,654,401 vs 1,654,447)
- Fortalecer o framing de "screening" removendo ambiguidade sobre modelo no corpo
- Absorver de P2: "dispersion paradox" framing (1 paragrafo), counterfactual referencia, honestidade sobre causality
- Limpar bib (entrada fantasma ashenfelter1989, working papers desatualizados)

**O que fazer com P2:**
- Material exclusivo (modelo completo, calibracao, counterfactuals) vira appendix online de P1 ou working paper separado para future submission
- Nenhum esforco imediato

**Esforco estimado:** BAIXO-MEDIO (compactacao, nao reescrita)
**Risco:** BAIXO (paper mais maduro, narrativa mais clara)
**Recompensa potencial:** 1 publicacao em top-5/top-field, com opcao de spinning P2 depois

---

## 4. RECOMENDACAO DO REFEREE 2

### Veredicto: Estrategia (c) — focar em P1 (Screening)

**Razoes decisivas:**

1. **Estado de maturidade desigual**: P1 esta a 2-3 sessoes de trabalho de submissao. P2 precisa de 5-8 sessoes minimo (consertar appendix, reintegrar mecanismos, reconciliar numeros).

2. **O resultado mais publicavel eh o AUC 0.94**: Nenhum modelo estrutural compete com "nosso screen simples detecta 94% dos carteis condenados pelo CADE." Isso eh o que editors lembram, o que referees acham dificil de contestar, e o que policy-makers citam.

3. **O modelo estrutural eh melhor como suporte do que como protagonista**: Como framework motivador em P1, ele da seriedade teorica sem precisar ser "the contribution." Em P2, ele precisa carregar o paper sozinho e eh vulneravel a "I don't buy your model → all results fall."

4. **Opcionalidade preservada**: Se P1 publicar, voce pode submeter o modelo expandido como paper 2 ("we showed in [Paper 1] that FL works; here we explain why via structural model"). Se P2 publicasse primeiro, P1 viraria "we already showed this in the companion" — sequencia invertida perde impacto.

5. **IJIO ja viu P2** (branch ijio-r1-response): Se houve rejeicao ou major revision, submeter P2 de novo seria arriscado. P1 eh material fresco.

### Proximos passos imediatos

Se voce aprovar (c):

1. **Criar `papers_finais/definicao/roadmap_screening.md`** com plano de compactacao de P1
2. **Inventariar o que absorver de P2** em P1 (dispersion paradox, counterfactual, honestidade)
3. **Definir target journal** e adequar formatting (RAND = 35-40 pp corpo)
4. **Mover modelo formal para appendix** em P1
5. **Cortar body para ~42 paginas** mantendo: intro, lit, data, empirical strategy, CADE, results, mechanisms (compactos), robustness (summary table + texto minimo), limitations, conclusion

---

## 5. NOTA SOBRE ESTRATEGIA (b) COMO SECOND-BEST

Se voce preferir maximizar impacto em uma unica submissao e tiver disposicao para mais trabalho, a fusao (b) produz o paper mais forte *em teoria*. Mas:
- O risco de "too long / too many contributions" em RAND eh real
- A integracao nao eh trivial (duas tonalidades diferentes)
- Se o referee pedir "cut the structural model," voce volta para (c) de qualquer forma

A fusao so faz sentido se o target for um journal que valorize papeis longos com teoria + empiria (tipo Econometrica, ReStud — mas esses provavelmente nao sao o melhor fit para procurement/screening).

---

*mr-frequent — Referee 2, modo ultrathink. Parecer completo.*
