# S8 — Audit de referências bibliográficas

Sessão 2026-04-28. Anti-hallucination protocol mr-hospital aplicado: cada
referência citada no manuscrito + cada nova para o framework rewrite foi
verificada contra fonte primária (publisher / DOI / NBER / arXiv / journal
website) via WebSearch tool.

Status: 24/24 refs existentes auditadas + 7 refs novas a adicionar para
suportar o framework rewrite.

---

## A. Auditoria das 24 refs existentes em `references.bib`

| BibKey | Status | Issue / Fix |
|---|---|---|
| `avdic2016` | ⚠️ TÍTULO ERRADO | Título do `.bib` é do working paper. Publicado: *"Improving efficiency or impairing access? Health care consolidation and quality of care: Evidence from emergency hospital closures in Sweden"*. JHE 48:44-60, 2016. **CORRIGIR**. |
| `gujralBasu2019` | ✅ OK | NBER WP 26182. Confirmado. |
| `carroll2019` | ✅ OK | Working paper Harvard, ASHEcon 2019. Confirmado. |
| `germack2019` | ✅ OK | Health Affairs 38(12):2086-2094, DOI 10.1377/hlthaff.2019.00916. Confirmado. |
| `lindrooth2018` | ✅ OK | Health Affairs 37(1):111-120, DOI 10.1377/hlthaff.2017.0976. Confirmado. |
| `gaynorTown2011` | ⚠️ ENTRY TYPE | Está como `@article` mas é capítulo de livro. Reformatar para `@incollection`. Pages 499-637 confirmados. |
| `gaynorVogt2003` | ✅ OK | RAND J Econ 34(4):764-785, 2003. Confirmado. |
| `joynt2015` | ✅ OK | Health Affairs 34(5):765-772, 2015. Confirmado. |
| `doyle2011` | ✅ OK | AEJ:Applied 3(3):221-243. Confirmado. |
| `macinkoHarris2015` | ✅ OK | NEJM 372(23):2177-2181, DOI 10.1056/NEJMp1501140. Confirmado. |
| `rochaSoares2010` | ✅ OK | Health Economics 19(S1):126-158, 2010. Confirmado. |
| `nolteMckee2008` | ✅ OK | Health Affairs 27(1):58-71, 2008. Confirmado. |
| `oecd2019` | ✅ OK | OECD/Eurostat list, URL OK. Confirmado. |
| `ms2014` | ✅ OK (gov doc) | Saúde Brasil 2013, MS 2014. Não-paper, OK. |
| `franca2017` | ✅ OK | Rev Bras Epidemiol 20(S1):46-60. Confirmado. |
| `grover2016` | ✅ OK | KDD 2016, pp 855-864. Confirmado. |
| `liu2021pecanpy` | ✅ OK | Bioinformatics 37(19):3377-3379. Confirmado. |
| `eliorc2017` | ✅ OK | GitHub URL. Software ref, OK. |
| `cs2021` | ✅ OK | Callaway-Sant'Anna J Econometrics 225(2):200-230, 2021. Confirmado. |
| `kelly2021` | ✅ OK | AER:Insights 3(3):303-320 (also written 303-20). Confirmado. |
| `acemoglu2024` | ⚠️ UPDATE OPCIONAL | NBER WP 32487 confirmado. Versão publicada agora disponível em Economic Policy 2025 vol 40(121), pp 13-58. **Atualizar para versão publicada se houver acesso**. |
| `vandermaaten2008` | ✅ OK | JMLR 9:2579-2605. Confirmado. |
| `mcinnes2018` | ✅ OK | arXiv:1802.03426. Confirmado. |
| `bonhomme2019` | ✅ OK | Econometrica 87(3):699-739, 2019. Confirmado. |

**Resumo**: 24/24 refs auditadas. **3 issues**: 1 erro factual de título
(avdic2016), 1 erro estrutural BibTeX (gaynorTown2011 entry type), 1
update opcional (acemoglu2024 → versão publicada).

---

## B. Refs a ADICIONAR para o framework rewrite (S7)

Necessárias para sustentar §4 (framework methodology) e §5 (results) do
outline. Verificadas anti-hallucination via WebSearch. Pronto para
inclusão no `.bib`.

### B.1 — Sun-Abraham 2021 (event-study principal)
```bibtex
@article{sunAbraham2021,
  author  = {Sun, Liyang and Abraham, Sarah},
  title   = {Estimating Dynamic Treatment Effects in Event Studies with Heterogeneous Treatment Effects},
  journal = {Journal of Econometrics},
  year    = {2021},
  volume  = {225},
  number  = {2},
  pages   = {175--199},
  doi     = {10.1016/j.jeconom.2020.09.006},
}
```
Status: ✅ verificado JE 225(2):175-199, 2021.

### B.2 — Borusyak-Jaravel-Spiess 2024 (DID imputation, used in S6.2)
```bibtex
@article{borusyak2024,
  author  = {Borusyak, Kirill and Jaravel, Xavier and Spiess, Jann},
  title   = {Revisiting Event-Study Designs: Robust and Efficient Estimation},
  journal = {The Review of Economic Studies},
  year    = {2024},
  volume  = {91},
  number  = {6},
  pages   = {3253--3285},
  doi     = {10.1093/restud/rdae007},
}
```
Status: ✅ ReStud 91(6):3253-3285, Nov 2024.

### B.3 — de Chaisemartin-D'Haultfoeuille 2020 (TWFE heterogeneous)
```bibtex
@article{deChaisemartin2020,
  author  = {de Chaisemartin, Cl{\'e}ment and D'Haultfoeuille, Xavier},
  title   = {Two-Way Fixed Effects Estimators with Heterogeneous Treatment Effects},
  journal = {American Economic Review},
  year    = {2020},
  volume  = {110},
  number  = {9},
  pages   = {2964--2996},
  doi     = {10.1257/aer.20181169},
}
```
Status: ✅ AER 110(9):2964-2996, set 2020.

### B.4 — Roth-Sant'Anna-Bilinski-Poe 2023 (DiD synthesis paper)
```bibtex
@article{roth2023did,
  author  = {Roth, Jonathan and Sant'Anna, Pedro H. C. and Bilinski, Alyssa and Poe, John},
  title   = {What's Trending in Difference-in-Differences? A Synthesis of the Recent Econometrics Literature},
  journal = {Journal of Econometrics},
  year    = {2023},
  volume  = {235},
  number  = {2},
  pages   = {2218--2244},
  doi     = {10.1016/j.jeconom.2023.03.008},
}
```
Status: ✅ J Econometrics 235(2):2218-2244, 2023.

### B.5 — Athey-Wager 2019 (Causal Forest, R3 core)
```bibtex
@article{atheyWager2019,
  author  = {Athey, Susan and Tibshirani, Julie and Wager, Stefan},
  title   = {Generalized Random Forests},
  journal = {Annals of Statistics},
  year    = {2019},
  volume  = {47},
  number  = {2},
  pages   = {1148--1178},
  doi     = {10.1214/18-AOS1709},
}
```
Status: ✅ verificado. Annals of Statistics 47(2), 2019.
Application paper companion (citar conjunto): Athey-Wager 2019
"Estimating Treatment Effects with Causal Forests: An Application",
Observational Studies 5(2):37-51.

### B.6 — Hamilton-Ying-Leskovec 2017 (GraphSAGE, apêndice R2)
```bibtex
@inproceedings{hamilton2017,
  author    = {Hamilton, William L. and Ying, Rex and Leskovec, Jure},
  title     = {Inductive Representation Learning on Large Graphs},
  booktitle = {Advances in Neural Information Processing Systems 30 (NeurIPS 2017)},
  year      = {2017},
  pages     = {1024--1034},
}
```
Status: ✅ NeurIPS 2017, Long Beach. arXiv:1706.02216.

### B.7 — Wager-Athey 2018 (precursor causal forest)
```bibtex
@article{wagerAthey2018,
  author  = {Wager, Stefan and Athey, Susan},
  title   = {Estimation and Inference of Heterogeneous Treatment Effects using Random Forests},
  journal = {Journal of the American Statistical Association},
  year    = {2018},
  volume  = {113},
  number  = {523},
  pages   = {1228--1242},
  doi     = {10.1080/01621459.2017.1319839},
}
```
Status: ✅ JASA 113(523), 2018.

---

## C. Refs OPCIONAIS — usar se §4 ou §7 expandirem

### C.1 — Almond-Doyle 2011 (extended hospital stays, related null)
JHE / AEJ:Applied paper. Pode entrar em §7 discussion como precedent de
"null with mechanism".

### C.2 — Lei 10.216/2001 (Reforma Psiquiátrica brasileira)
Não-paper, mas precisa ser citado em §2.2 e §7.2. Format:
```bibtex
@misc{lei10216,
  author       = {{Brasil}},
  title        = {Lei n.\\ 10.216, de 6 de abril de 2001: Disp{\~o}e sobre a prote{\c{c}}{\~a}o e os direitos das pessoas portadoras de transtornos mentais},
  year         = {2001},
  howpublished = {\\url{http://www.planalto.gov.br/ccivil_03/leis/leis_2001/l10216.htm}},
}
```

### C.3 — Portaria MS 221/2008 (lista ICSAP)
Necessário para §3 e §6.1. Format:
```bibtex
@misc{portaria221_2008,
  author       = {{Ministério da Saúde do Brasil}},
  title        = {Portaria n.\\ 221, de 17 de abril de 2008: Lista Brasileira de Interna{\c{c}}{\~o}es por Condi{\c{c}}{\~o}es Sens{\'\i}veis {\`a} Aten{\c{c}}{\~a}o Prim{\'a}ria},
  year         = {2008},
  howpublished = {\\url{https://bvsms.saude.gov.br/bvs/saudelegis/sas/2008/prt0221_17_04_2008.html}},
}
```

### C.4 — Mendes 1996/2001 (regiões de saúde Brasil)
Standard ref para §2.1 (SUS regionalization architecture). Não confirmado
exatamente qual versão; checar com autor.

### C.5 — Dourado et al 2011 (ICSAP brasileira validação)
Necessário em §5.4 (ICSAP outcome). Verificar exato: Dourado et al
"Trends in Primary Health Care-sensitive Conditions in Brazil",
Cadernos de Saúde Pública 2011 (a verificar).

---

## D. Plano de implementação no `.bib`

1. **Corrigir avdic2016 title** — título publicado, não working paper.
2. **Reformatar gaynorTown2011** — `@article` → `@incollection`.
3. **Atualizar acemoglu2024 (opcional)** — NBER → Economic Policy 2025.
4. **Adicionar 7 refs novas** (B.1-B.7).
5. **Adicionar refs opcionais** (C.1-C.5) só após o autor confirmar
   quais §s vai expandir.

Total esperado pós-S7 rewrite: 24 + 7 = 31 refs core + ~5 opcionais.

---

## E. Anti-hallucination protocol — métodos usados

Para cada referência:
1. Search: autor + ano + título (ou keywords) + journal + volume
2. Verificar contra: publisher's article page, DOI, NBER, arXiv,
   institutional repo
3. Discrepâncias: documentar em status (⚠️ ou ✅)
4. URL fonte primária registrada para auditoria posterior

Tempo total: ~25 WebSearches × ~5s cada = ~2 minutos. Custo zero.

URLs primárias auditadas (sources):
- Avdic 2016: https://www.sciencedirect.com/science/article/abs/pii/S0167629616300832
- Carroll 2019: https://scholar.harvard.edu/ccarroll
- Gujral-Basu 2019: https://www.nber.org/papers/w26182
- Doyle 2011: https://www.aeaweb.org/articles?id=10.1257%2Fapp.3.3.221
- Joynt 2015: https://www.healthaffairs.org/doi/10.1377/hlthaff.2014.1352
- Lindrooth 2018: https://www.healthaffairs.org/doi/10.1377/hlthaff.2017.0976
- Germack 2019: https://www.healthaffairs.org/doi/full/10.1377/hlthaff.2019.00916
- Macinko 2015: https://www.nejm.org/doi/abs/10.1056/NEJMp1501140
- Rocha-Soares 2010: https://onlinelibrary.wiley.com/doi/abs/10.1002/hec.1607
- Nolte-McKee 2008: https://www.healthaffairs.org/doi/10.1377/hlthaff.27.1.58
- Callaway-Sant'Anna 2021: https://www.sciencedirect.com/science/article/abs/pii/S0304407620303948
- Sun-Abraham 2021: https://www.sciencedirect.com/science/article/abs/pii/S030440762030378X
- Borusyak 2024: https://academic.oup.com/restud/article/91/6/3253/7601390
- de Chaisemartin 2020: https://www.aeaweb.org/articles?id=10.1257/aer.20181169
- Roth 2023: https://www.sciencedirect.com/science/article/abs/pii/S0304407623001318
- Athey-Wager 2019 GRF: https://projecteuclid.org/euclid.aos/1547197247
- Wager-Athey 2018 JASA: https://doi.org/10.1080/01621459.2017.1319839
- Hamilton 2017 GraphSAGE: https://papers.nips.cc/paper/6703-inductive-representation-learning-on-large-graphs
- Acemoglu 2024 NBER: https://www.nber.org/papers/w32487
- Bonhomme 2019: https://onlinelibrary.wiley.com/doi/abs/10.3982/ECTA15722
- Gaynor-Town 2011: https://www.sciencedirect.com/science/article/abs/pii/B9780444535924000098
- Gaynor-Vogt 2003: https://econpapers.repec.org/RePEc:rje:randje:v:34:y:2003:i:4:p:764-85
- Kelly 2021: https://www.aeaweb.org/articles?id=10.1257%2Faeri.20190499
- Grover-Leskovec 2016: https://dl.acm.org/doi/10.1145/2939672.2939754
- Liu-Krishnan 2021: https://academic.oup.com/bioinformatics/article/37/19/3377/6184859
- Vandermaaten-Hinton 2008: https://www.jmlr.org/papers/v9/vandermaaten08a.html
- McInnes 2018: https://arxiv.org/abs/1802.03426
- França 2017: https://www.scielo.br/scielo.php?pid=S1415-790X2017000500046
