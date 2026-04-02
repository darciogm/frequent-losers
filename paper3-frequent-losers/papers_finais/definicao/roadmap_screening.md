# Roadmap: Paper Screening → Submissao

**Decisao:** Estrategia (c) — focar em P1 (Screening), absorver elementos-chave de P2
**Target:** ~40 paginas corpo + online appendix  
**Current:** ~47 pp corpo + 31 pp appendix = 78 pp total
**Meta de corte:** -7 pp no corpo, appendix vira online supplement

---

## FASE 1: Cirurgia de compactacao (corpo: 47 → 40 pp)

### 1.1 Modelo estrutural: de secao independente para framework embutido
**Arquivo:** `sections/sec3_structural_model.tex`  
**Atual:** 83 linhas (~3 pp), secao propria com subsecoes
**Meta:** ~40 linhas (~1.5 pp)  
**Ganho:** ~1.5 pp

**O que cortar:**
- Remover subsecao "Setup and Key Results" como subsecao formal
- Comprimir os 3 items numerados (i-iii) em prosa corrida de 1 paragrafo
- Manter: (a) intuicao dos 2 regimes em 1 paragrafo, (b) deteccao impossibility result em 1 frase, (c) market-selection prediction em 1 frase, (d) predictions table intacta
- Remover todo material que ja esta em Appendix A (provas, likelihood)

**O que muda:** Titulo da secao de "A Model of Cover Bidding in Procurement Auctions" para "Conceptual Framework: Cover Bidding and Detection Vulnerability" — sinaliza que eh framework, nao contribuicao standalone.

### 1.2 Empirical Strategy: remover formulas redundantes
**Arquivo:** `sections/sec5_empirical_strategy.tex`  
**Atual:** 230 linhas (~8 pp)  
**Meta:** ~185 linhas (~6.5 pp)  
**Ganho:** ~1.5 pp

**O que cortar:**
- Eqs (3)-(4) (TPR/FPR): definicoes standard, nao precisam ser formalizadas — substituir por 1 frase em prosa
- Eq (5) (Youden's J): idem — 1 frase
- Eq (7) (winner HHI): formula de HHI eh universalmente conhecida — referencia basta
- Comprimir "Benchmarking against Imhof-style screens" de paragrafo para 2 frases (detalhes ja estao em Results)

**O que manter intacto:**
- Eq (1) OLS baseline — essencial
- Eq (2) IV instrument — essencial
- Eq (6) MLE genuine — essencial
- Eq (8) Bajari-Ye first stage — essencial
- Toda a prosa sobre matching, IV como diagnostico, n_bids exclusion

### 1.3 Results: comprimir structural estimation e ground truth
**Arquivo:** `sections/sec7_results.tex`  
**Atual:** 287 linhas (~10 pp)  
**Meta:** ~245 linhas (~8.5 pp)  
**Ganho:** ~1.5 pp

**O que cortar:**
- Sec 7.4 "Structural Estimation Results" (linhas 263-287): comprimir de 25 para 12 linhas — 1 paragrafo com numeros-chave (BIC, sigma ratio, markup match) + remeter ao appendix
- `\input{sections/sec_ground_truth}` (22 linhas): comprimir para 1 paragrafo de 8 linhas dentro de Detection Performance
- `\input{sections/sec_identification}` (48 linhas): comprimir para 1 paragrafo de 15 linhas — manter event study + min-bidder, CADE enforcement vai para appendix

**O que manter intacto:**
- Classification diagnostics (7.0) — fundamental
- OLS and matching (7.1) — core
- Detection performance (7.2) — killer feature
- Network-split (7.3) — core prediction test
- Bajari-Ye (7.3) — core

### 1.4 Mechanisms: comprimir M4, M5, rationality
**Arquivo:** `sec_mechanisms.tex`  
**Atual:** 135 linhas (~5 pp)  
**Meta:** ~100 linhas (~3.5 pp)  
**Ganho:** ~1.5 pp

**O que cortar:**
- M4 dyadic linkage: de 12 para 6 linhas (numeros + referencia ao appendix)
- M5 Cox survival: de 12 para 6 linhas (HR + caveat PH, remeter appendix)
- Rationality: de 28 para 15 linhas (manter Bayesian learner footnote, cortar tabela do corpo — mover tab_rationality para appendix)
- "Strategic adaptation" (11 linhas): comprimir para 4 linhas
- "Joint assessment" (12 linhas): comprimir para 6 linhas

**O que manter intacto:**
- M1 crowding out — 1 paragrafo, essencial
- M2 reference price — 1 paragrafo, essencial
- M3 reverse causality — 1 paragrafo, essencial
- Alternative explanations — importante

### 1.5 Robustness: texto → referencia tabela
**Arquivo:** `sec_robustness.tex`  
**Atual:** 137 linhas (~5 pp)  
**Meta:** ~110 linhas (~4 pp)  
**Ganho:** ~1 pp

**O que cortar:**
- Tabela robustness_summary ja faz o trabalho pesado — comprimir texto explicativo
- Threshold sensitivity: de 14 para 8 linhas
- Staggered DiD: de 17 para 10 linhas (manter interpretacao market-selection)
- Oster: de 8 para 4 linhas
- Oversight heterogeneity: manter intacto (resultado forte)

### Resumo Fase 1

| Secao | Atual (pp) | Meta (pp) | Ganho |
|-------|-----------|----------|-------|
| Modelo | 3.0 | 1.5 | 1.5 |
| Empirical Strategy | 8.0 | 6.5 | 1.5 |
| Results | 10.0 | 8.5 | 1.5 |
| Mechanisms | 5.0 | 3.5 | 1.5 |
| Robustness | 5.0 | 4.0 | 1.0 |
| **Total** | **31.0** | **24.0** | **7.0** |

Secoes intactas: frontmatter (1.5), intro (3.5), lit (2), data (4), CADE (2), limitations (1.5), conclusion (2) = 16.5 pp
**Corpo final: 24.0 + 16.5 = 40.5 pp** ✓

---

## FASE 2: Absorcao seletiva de P2

### 2.1 "Dispersion paradox" no abstract e intro
**Onde:** `sec_frontmatter.tex` (abstract) e `sec_introduction.tex`  
**O que adicionar:** 2-3 frases no abstract e 1 paragrafo curto na intro explicando que sigma_c/sigma_g = 0.72 eh resultado central — cover bids sao MENOS dispersos, nao mais, o que explica por que screens de dispersao falham.  
**Impacto em paginas:** +0 (substitui texto existente que ja menciona "28% below")

O abstract ja menciona "BIC selects Regime 2, with cover-bid dispersion 28% below genuine bids" — so precisa dar o nome "dispersion paradox" e enfatizar a implicacao.

### 2.2 Honestidade sobre causalidade
**Onde:** `sec_introduction.tex` e `sec_limitations.tex`  
**O que adicionar:** 1-2 frases inspiradas no paragrafo "What the paper does and does not claim" de P2. P1 ja tem secao de limitacoes mas pode ser mais explicito na intro.
**Sugestao:** Adicionar apos contribuicoes: "We emphasize that the price association is a conditional correlation, not a causal estimate; the paper's contribution is the screen and its diagnostic validation, not causal identification of the FL-price effect."

### 2.3 Counterfactual como nota
**Status:** Ja esta no appendix de P1 (`sections/sec_counterfactual.tex` + `tab_welfare_bounds`).  
**Acao:** Nenhuma — manter no appendix online com disclaimer existente.

### 2.4 QQ-plot de Regime 2
**Onde:** Appendix structural  
**Acao:** Importar `fig_qqplot_regime2.pdf` de P2 para o appendix de P1 se nao estiver la. Adicionar 3 linhas de texto no appendix.

---

## FASE 3: Limpeza editorial

### 3.1 Inconsistencia de N
**Problema:** 1,654,401 (sec_robustness.tex tabela) vs 1,654,447 (sec4_data_fl.tex)  
**Acao:** Verificar qual eh correto no pipeline R e unificar

### 3.2 Bib cleanup
- Remover `ashenfelter1989using` (entrada fantasma — conteudo eh Baldwin et al. 1997, nao citado)
- Verificar se `decarolis2017corruption` publicou (2017 working paper)
- Verificar se `schurter2020identification` publicou (2020 working paper)
- Verificar se `kawai2019using` / `kawai2022detecting` publicaram

### 3.3 Labels e cross-references
- Audit completo de `\ref{}` e `\label{}` para garantir que nenhum aponte para material removido
- Verificar que predictions table refs (P1-P5) apontam para secoes corretas apos reestruturacao

### 3.4 Appendix: separar print vs online
**Estrutura proposta:**

**Print appendix (~8 pp):**
- App A: Model proofs (Propositions 1-4) — essencial para referee
- App B: Structural estimation details (identification, likelihood)
- App C: Core supporting tables (conditional desc stats, CADE permutation, exclusion)
- App D: IV results + Bajari-Ye full tables

**Online appendix (restante, ~23 pp):**
- Tudo que esta atualmente em "Online Appendix" de sec_appendix.tex
- + tab_rationality (movido do corpo)
- + CADE enforcement DiD (movido de sec_identification)
- + QQ-plot regime 2 (importado de P2)

---

## FASE 4: Adequacao ao target journal

### 4.1 Opcoes de journal (em ordem de fit)

| Journal | Paginas corpo | Fit | Risco |
|---------|--------------|-----|-------|
| **RAND** | 35-40 | Alto: screening + model + empirics | Desk reject se "too applied" |
| **JLE** | 40-50 | Alto: law enforcement angle, CADE validation | Precisa enfatizar policy |
| **ReStat** | 35-40 | Medio: empirical methods paper | Modelo pode parecer out of place |
| **IJIO** | 40-50 | Alto: IO + procurement | Ja submeteu P2 aqui — risco de overlap |
| **JLEO** | 40-50 | Medio: law + economics | Menos tecnico que P1 |

### 4.2 Recomendacao: JLE como first choice

**Razoes:**
1. CADE validation eh perfeito para JLE audience (law enforcement)
2. Aceita papers mais longos (40-50 pp)
3. Screen como "tool for enforcement" eh JLE language
4. Modelo como framework (nao contribuicao) eh aceitavel em JLE
5. Nao tem conflito com submissao anterior (IJIO foi P2)
6. Policy implications (three-stage workflow) sao bem-vindas

**RAND como alternativa:**
- Se conseguir compactar para 38 pp, RAND eh o premio maior
- Risco: RAND quer novidade metodologica pura; screening tool pode parecer "applied"
- Mas: AUC 0.94 + dispersion paradox + 5 diagnostics eh suficientemente novo

### 4.3 Formatacao
- Se JLE: manter elsarticle, ajustar para JLE template se disponivel
- Se RAND: converter para RAND template (requer reformatacao)
- Em ambos os casos: abstract ≤ 150 palavras, JEL codes, keywords

---

## FASE 5: O que fazer com P2

### Opcao 1 (recomendada): Working paper + future submission
- Disponibilizar como working paper (SSRN, INSPER WP series)
- Citar em P1 como "Genicolo-Martins & Azevedo (2026b)"
- Apos publicacao de P1, submeter P2 como companion a IJIO ou JLEO
- P2 precisara: consertar appendix orfao, reintegrar mecanismos, reconciliar numeros

### Opcao 2: Absorver completamente em P1
- Modelo completo no appendix online (~15 pp adicionais)
- Counterfactuals no appendix online
- Nao publicar P2 separadamente
- Menor risco de overlap, mas perde 1 publicacao potencial

**Recomendacao:** Opcao 1 — preserva opcionalidade

---

## CRONOGRAMA SUGERIDO

| Sessao | Fase | Entregavel |
|--------|------|-----------|
| 1 | 1.1-1.2 | Modelo compactado + Emp Strategy enxuta |
| 2 | 1.3-1.4 | Results + Mechanisms compactados |
| 3 | 1.5 + 2.1-2.4 | Robustness + absorcoes de P2 |
| 4 | 3.1-3.4 | Limpeza editorial + appendix split |
| 5 | 4.1-4.3 | Adequacao journal + formatting |
| 6 | Review | Leitura final modo revisor |

---

*mr-frequent — Roadmap v1, 2 de abril de 2026*
