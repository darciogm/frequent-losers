# Fases 4-5 — Resultado

**Data:** 2 de abril de 2026

## Fase 4: Adequacao JLE

### 4.1 Document class: elsarticle → article
- Removida dependencia de elsarticle (nao eh JLE class)
- Trocado para `\documentclass[12pt]{article}` + `\doublespacing`
- Margens 1in (standard)
- amsthm carregado (proof environment nativo)
- Removidas macros elsarticle-specific (corref, ead, affiliation, biboptions)
- Frontmatter reescrito com `\title`, `\author`, `\thanks`, `\maketitle` standard

### 4.2 Abstract: 458 → 105 palavras
- Dentro do limite JLE de 150 palavras
- Manteve: AUC 0.94, dispersion paradox, 3.6-7.7%, 5 diagnostics
- Cortou: detalhes de matching/IV, CADE co-participation rate, model description

### 4.3 Companion paper citation
- `genicolomartins2026structural` adicionado ao .bib como working paper INSPER
- Citacao no Results (sec7): "a companion paper develops the full structural model, calibration, and policy counterfactuals"

### Estrutura final (JLE-ready)

| Componente | Paginas (double-spaced) |
|-----------|------------------------|
| Title page + Abstract | 1 |
| Corpo (Intro → Conclusion) | 30 |
| References | 2 |
| Print Appendix (A-E) | 12 |
| Online Appendix (F-I) | 33 |
| **Total** | **78** |

### Checklist JLE

- [x] Double-spaced throughout
- [x] 12pt font, 1in margins
- [x] Abstract ≤ 150 words (105)
- [x] Chicago citation style (natbib + chicago.bst)
- [x] Single-blind (author names visible)
- [x] Keywords + JEL codes
- [x] Online appendix clearly demarcated
- [x] No special class files needed
- [ ] Replication package (a preparar separadamente)
- [ ] Submission fee ($100)
- [ ] Cover letter

## Fase 5: Disposicao de P2

- P2 fica em standby ate P1 submetido
- Disponibilizar no SSRN apos submissao de P1
- Target: IJIO ou JLEO apos publicacao de P1
- 7 itens de trabalho necessarios (appendix, labels, mecanismos, numeros, reframe, counterfactuals)
- Material exclusivo suficiente para standalone paper

## Compilacao final
- 78 pp, zero warnings substantivos
- PDF limpo, titulo/abstract/autores corretos
- Pronto para submissao apos cover letter e replication package
