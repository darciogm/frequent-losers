# P2 Disposition Plan

**Paper:** "Cover Bidding in Public Procurement: A Structural Model of the Dispersion Paradox"
**Status atual:** 54 pp, compilacao incompleta (appendix orfao), maturidade 5/10

## Decisao: Working Paper → Future Submission

### Sequencia

1. **Agora:** P2 fica em standby. Nenhum trabalho adicional ate P1 estar submetido.
2. **Apos submissao de P1:** Disponibilizar P2 no SSRN como working paper (INSPER WP series).
3. **Apos publicacao de P1:** Submeter P2 como companion a IJIO ou JLEO.

### Reframing necessario para P2 standalone

Quando for hora de trabalhar em P2, sera necessario:

1. **Consertar appendix orfao** — reintegrar sec_appendix.tex no paper_structural.tex ou fundir com sec_appendix_p2.tex
2. **Resolver labels duplicados** — app:did, app:robustness, app:extensions
3. **Reintegrar mecanismos** — sec_mechanisms.tex (106 linhas) precisa entrar no corpo
4. **Reconciliar numeros** — IQR variants 0.060/0.050 vs 0.071/0.091
5. **Citar P1 como companion publicado** — trocar `genicolomartins2026screening` por referencia ao journal
6. **Reframe intro** — P2 deixa de ser self-contained e passa a ser "we showed in [P1] that FL works; here we explain why"
7. **Fortalecer counterfactuals** — essa eh a contribuicao exclusiva de P2 que P1 nao cobre no corpo

### Target journals para P2

| Journal | Fit | Razao |
|---------|-----|-------|
| **IJIO** | Alto | IO + structural estimation + procurement |
| **JLEO** | Medio | Law + economics, mas menos tecnico |
| **JIE** | Medio | Industrial economics, structural models |

**Nota:** IJIO ja viu versao anterior (branch ijio-r1-response). Verificar se houve rejeicao formal ou R&R. Se R&R, submeter revisao. Se rejeicao, considerar JLEO ou JIE.

### O que P1 ja absorveu de P2

- "Dispersion paradox" naming (abstract + intro)
- sigma_c/sigma_g = 0.72 como resultado
- QQ-plot Regime 2 (appendix)
- Disclaimer de causalidade
- Companion citation

### O que permanece exclusivo de P2

- Modelo estrutural completo (487 linhas, 4 proposicoes, 6 predictions)
- Calibracao de primitivas (gamma = 0.694, c1 = 0.238, phi0 = 0.019)
- 3 counterfactuals formais com welfare function
- Specification tests em 3 tiers
- "What the paper does and does not claim" paragraph (versao expandida)
- Tiered evidence presentation

Este material exclusivo eh suficiente para um paper standalone em IJIO/JLEO.
