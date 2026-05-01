# Prompt operacional — Revisão JLEO R2 (Paper 3)

**Para:** Claude Code em sessão fresh
**Estado:** R1 já aplicada (pacote codex, 8 scripts 47-54, 12 LaTeX edits, verifier 15/15 PASS, PDF 109pp)
**Meta:** após sua execução, mr-frequent (codex) em re-review hostil deve conceder **mínimo Major Revision** em JLEO (probabilidade ≥0.65). Atualmente R1 ainda foi Reject, com 4 problemas matadores pontuais identificados.

## VOCÊ É: co-autor cético + revisor rigoroso

Postura: convicção de excelência top-journal. Tradeoff sempre vencido por **passar em re-review hostil** > **manter tese ambiciosa**. Trabalhe com disciplina de:
- Rastreabilidade: todo número novo via macro `\val<Macro>` em `work/v13/values.tex`
- Verificabilidade: `verify_paper.sh` 15/15 PASS no fim
- Reprodutibilidade: `bash scripts/00_master_paper.sh` continua funcionando

## CONTEXTO

Diretório raiz: `/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/`

Pipeline:
- `bash scripts/00_master_paper.sh` (~14 min) — full
- `bash scripts/00_master_paper.sh --fast` (~30s) — só values+compile
- `bash scripts/verify_paper.sh` (~3s) — 15 invariantes

Scripts 47-54 (R1) já existem e produzem CSVs canônicos:
- `output/theory_operationalization/`, `output/stratum_scope/`, `output/imhof_incremental/`,
- `output/negative_cell_audit/`, `output/item_level_scope_match/`,
- `output/external_validity_scope/`, `output/strict_train_threshold/`,
- `output/threshold_table_q3iqr/`

Macros: 444 em `work/v13/values.tex`, gerados por `scripts/99_make_paper_values.R` com `src_set("script :: csv :: row")` provenance.

Convenções obrigatórias:
- Edits LaTeX marcadas com comentário `% JLEO-R2: [descrição curta]`
- DuckDB com `PRAGMA threads=12; PRAGMA memory_limit='14GB';`
- fixest com `lean=TRUE`
- Não invente dados; só use outputs canônicos existentes
- Não preserve claim por apego; preserve apenas o que resiste a re-review hostil

## OS 4 PROBLEMAS MATADORES (priority order)

### Killer 1 (CRÍTICO): Incoerência interna em sec7_results.tex:20

**Problema:** Linha 20 ainda diz "the institutional design identifies a … premium" — contradiz frontalmente o abstract/intro/limitations/conclusion (que rebaixaram para conditional association). Codex referee disse: "os autores ainda não decidiram se o artigo é screen modesto ou peça de identificação institucional".

**Verificação:**
```bash
grep -n "institutional design identifies\|design identifies" work/v13/sections/sec7_results.tex
```

**Ação:**
1. Ler `work/v13/sections/sec7_results.tex` linhas 1-50
2. Localizar TODA ocorrência de linguagem causal "identifies" / "identified" / "institutional design produces" / "the rule generates" no arquivo
3. Substituir por linguagem condicional: "is associated with", "concentrates risk in", "exhibits higher prices conditional on"
4. Especificamente, qualquer parágrafo que use a palavra "identifies" precisa ser revisado para descrição condicional
5. Marcar com `% JLEO-R2: causal language demoted to conditional throughout sec7_results`
6. Verificar coerência com abstract: o sentence pattern em sec7_results deve ecoar abstract, não contradizê-lo

**Critério de fechamento:** Não há mais "identifies" / "identification" em sec7_results.tex que conflite com R1 disclaimer de associação condicional. Coerência com `sec_frontmatter.tex` abstract paragraph.

### Killer 2 (ALTO): sec_robustness.tex:89 escorrega para causalidade

**Problema:** Pregão-only falsification termina com "evidence that the construct identifies a coordination phenomenon" — vai além do que R1 sustenta no resto do paper.

**Verificação:**
```bash
sed -n '85,100p' work/v13/sec_robustness.tex
```

**Ação:**
1. Localizar exatamente linha 89 e contexto (linhas 80-100)
2. Substituir "the construct identifies a coordination phenomenon" por "the construct is empirically robust to the absence of the minimum-bidder rule, supporting the descriptive interpretation that loser-side concentration discriminates similar environments across modal regimes — without committing to a coordination mechanism"
3. Marcar `% JLEO-R2: falsification claim disciplined — describe-not-identify`
4. Re-verificar que tab_falsification_modal nota termina-se igualmente disciplinada

**Critério:** Substituição feita; pregão-only falsification agora é **descritivo** (boundary test), não causal.

### Killer 3 (MÉDIO): Continuous-superiority claim simplificado demais

**Problema:** Tabela `tab_theory_operationalization.tex` mostra que continuous PERDE no strict firm-level AUC (0.750 vs 0.767 binário). Narrativa atual em sec_introduction/sec4_data_fl ignora essa nuance e diz "continuous score is the stronger object" sem qualificação.

**Verificação:**
```bash
cat output/theory_operationalization/theory_operationalization.csv
grep -n "continuous score" work/v13/sec_introduction.tex work/v13/sections/sec4_data_fl.tex
```

**Ação:**
1. Ler `output/theory_operationalization/theory_operationalization.csv` para confirmar números
2. Adicionar parágrafo curto em `sec_robustness.tex` (logo após threshold sensitivity) com texto:

```latex
% JLEO-R2: continuous-vs-binary nuance — neither dominates uniformly
\paragraph{Continuous vs. binary: trade-off, not dominance.}
The continuous loss-intensity score \emph{dominates} the binary
$\valFL$ rule in two of three settings: in-sample firm-level AUC
($\valAUClogtc$ vs.\ $\valAUCFLfirm$, DeLong $p=\valDeLongP$) and
the item-level prediction reported in
Section~\ref{sec:robustness}. \emph{The binary rule, however,
does at least as well in the strict (train-period-only)
firm-level holdout: AUC $\valAUCFLstrict$ binary vs.\
$\valAUClogtcStrict$ continuous}
(Table~\ref{tab:theory_operationalization}). The continuous score
captures finer ordering when the full sample is observable; the
binary rule is more robust to truncation. We treat the
construct as a continuous concept and the binary rule as the
deployable form, with neither uniformly dominant.
```

3. Adicionar macros novos em `scripts/99_make_paper_values.R`:
   - `valAUCFLstrict` (binário strict-train AUC) — source: `output/strict_train_threshold/strict_train_threshold.csv`
   - `valAUClogtcStrict` (continuous strict-train AUC) — same CSV
   - Adicionar com `src_set("scripts/53_strict_train_period_threshold.R :: output/strict_train_threshold/strict_train_threshold.csv")`
4. Onde no abstract/intro disser "continuous score is the stronger object", suavizar para "continuous loss intensity is the construct of substantive interest; the FL14 binary is the deployable form, with no uniform dominance"

**Critério:** Continuous superiority claim qualificado. Macros novos populados. Tabela referenciada.

### Killer 4 (MÉDIO): Apêndice A3 contradiz padrão empírico

**Problema:** Apêndice prediz `∂m*/∂HHI < 0` (cover bidders são mais valiosos em mercados menos concentrados). Mas `tab_negative_cell_audit.tex` mostra High HHI × High pairs = NEGATIVO (−7.92%) — sinal oposto. Mantém tensão teoria/empírico.

**Verificação:**
```bash
grep -n "partial m.*HHI\|m.*HHI.*<.*0\|A3\|HHI-cover complementarity" work/v13/sec_appendix.tex
```

**Ação:**
1. Localizar bloco "Setup", A3, e proof de Proposition `prop:market_selection` em `sec_appendix.tex` (linhas 21-160)
2. Adicionar **parágrafo de tensão honesta** logo após o proof de `prop:market_selection`:

```latex
% JLEO-R2: empirical tension with A3 acknowledged
\paragraph{Empirical tension with A3.}
Proposition~\ref{prop:market_selection} predicts
$\partial m^*/\partial \mathrm{HHI} < 0$ under A3, i.e., that
cover bidding concentrates in less-concentrated markets. The
empirical decomposition in
Table~\ref{tab:unified_mechanism} is partially consistent
with this prediction in the dominant cell (Low HHI $\times$ Low
pairs, $+\valMechQLLLCoef\%$), but the High HHI $\times$ High pairs
cell returns a \emph{negative} coefficient
($\valMechQLHHCoef\%$, $p=\valMechQLHHP$). We do not interpret
this as falsification of A3 in isolation, because the negative
cell is small ($\valMechQLHHN$ items) and is plausibly a
selection cell — environments under or already targeted by
CADE enforcement, where cartel activity has been deterred or
prosecuted. We acknowledge, however, that this leaves the
mechanism partially unidentified: the framework guides
interpretation but the data do not deliver a single canonical
mechanism. We treat the empirical patterns as risk
heterogeneity rather than mechanism evidence.
```

3. Verificar que toda referência a A3 / `prop:market_selection` no main text (não no apêndice) seja igualmente cautelosa
4. Marcar `% JLEO-R2: A3 empirical tension disclosed`

**Critério:** Tensão teoria/empírico declarada explicitamente. Não mais escondida em apêndice.

---

## BOOST ADICIONAL (push 2 PARTIAL → RESOLVED)

### Boost 1: Major 1 (theory grounding) → fortalecer

**Problema atual:** Codex disse "honestidade melhorou; não entregou fundamento teórico forte". Modelo formal continua editorial.

**Ação leve, alto ROI:**
1. Adicionar 2-3 sentences em sec_introduction.tex declarando explicitamente que o framework do apêndice é "organizing device, not source of identification"
2. Adicionar uma justificativa econômica curta em sec_introduction.tex, conectando rationality argument (Bayesian learner) ao construto:

```latex
% JLEO-R2: explicit construct rationale (rationality + selection)
The economic logic is direct: under positive bid-preparation
costs and persistent zero wins, continued participation past
any reasonable Bayesian threshold is incompatible with
expected-profit maximization (\S\ref{sec:rationality}). Firms
that nevertheless persist are doing so for reasons orthogonal
to expected-profit competition — capacity transfer, market
intelligence, or instrumental participation in coordinated
arrangements. The construct does not distinguish among these
non-competitive readings; it captures their shared empirical
footprint.
```

3. Marcar `% JLEO-R2: explicit construct rationale (Bayesian rationality)`

**Critério:** Construto agora tem rationale econômico explícito (não só "tela útil"). M1 → mais perto de RESOLVED.

### Boost 2: Major 6 (single-jurisdiction) → fortalecer com case for narrowing

**Problema atual:** "narrowing claim, não validação externa".

**Ação:**
1. Em `sec_limitations.tex`, expandir parágrafo de single-jurisdiction com **prediction of generalizability**:

```latex
% JLEO-R2: scope statement strengthened with falsifiable prediction
The construct's empirical content is most likely portable to
procurement environments sharing three structural features:
(i) commodity-heavy item composition (allowing repeated
participation), (ii) electronic platform with publicly auditable
participant lists, and (iii) institutional asymmetry between
winner and loser sides of the bidding pool (e.g., minimum-bidder
rules in convite-style modalities, or analogous quorum
requirements in other jurisdictions). The construct is least
likely portable to (i) heterogeneous works contracts, (ii)
private-sector procurement, and (iii) jurisdictions where
bid microdata are routinely audited and bid-distribution
screens are operational. We make this prediction explicit
because the construct's value is in cheaply screening
procurement environments where bid microdata are unavailable —
roughly the OECD-procurement-without-microdata frontier
identified by \citet{coviello2017tenure} and the
participation-disclosure regimes surveyed by
\citet{decarolis2020rules}.
```

2. Marcar `% JLEO-R2: external validity prediction made falsifiable`

**Critério:** Single-jurisdiction agora tem **prediction of where it would and would not work** — falsificável, não apenas defensive.

---

## SEQUÊNCIA DE EXECUÇÃO

1. **Read-only inventory (~5 min):**
   - Read `work/v13/sec_frontmatter.tex` (abstract)
   - Read `work/v13/sec_introduction.tex` (full)
   - Read `work/v13/sections/sec7_results.tex` linhas 1-50 (Killer 1)
   - Read `work/v13/sec_robustness.tex` linhas 80-100 (Killer 2)
   - Read `work/v13/sec_appendix.tex` linhas 21-160 (Killer 4)
   - Inspect `output/theory_operationalization/theory_operationalization.csv` (Killer 3)
   - Inspect `output/strict_train_threshold/strict_train_threshold.csv` (Killer 3)
   - Inspect `output/negative_cell_audit/negative_cell_audit.csv` (Killer 4)

2. **Killer fixes em ordem (1 → 4):**
   - Killer 1: sec7_results.tex causal language demote (15 min)
   - Killer 2: sec_robustness.tex falsification softening (5 min)
   - Killer 3: continuous nuance paragraph + 2 macros novos em script 99 + sec_robustness paragraph (20 min)
   - Killer 4: apêndice A3 tension paragraph (10 min)

3. **Boost fixes:**
   - Boost 1: sec_introduction rationale paragraph (10 min)
   - Boost 2: sec_limitations external validity prediction (10 min)

4. **Update `scripts/99_make_paper_values.R`** com novos macros (Killer 3) — ~5 min

5. **Regenerate values.tex:**
   ```bash
   Rscript -e '.script_dir <- "scripts"; source("scripts/99_make_paper_values.R")'
   ```

6. **Recompile + verify:**
   ```bash
   bash scripts/00_master_paper.sh --fast
   bash scripts/verify_paper.sh
   ```

7. **Final coherence check:**
   - Re-read abstract + intro + sec7_results.tex top paragraph + conclusion
   - Verifique que linguagem é uniforme: "associated with" / "concentrates risk in" / "discriminates within stratum" — NÃO "identifies"
   - Verifique que continuous-vs-binary é apresentado como **trade-off**, não dominância

8. **Commit:**
   ```
   git add (lista específica) && git commit -m "paper3 v13-jle: JLEO R2 — 4 killer fixes + 2 boost (codex re-review response)"
   ```

## CRITÉRIOS DE SUCESSO (verificáveis)

Após sua execução, deve ser verdade que:

1. ✅ **`grep "identifies" work/v13/sections/sec7_results.tex`** retorna apenas linguagem condicional/descritiva (zero ocorrências causais)
2. ✅ **`grep "construct identifies a coordination" work/v13/sec_robustness.tex`** retorna 0
3. ✅ **`grep "valAUCFLstrict\|valAUClogtcStrict" work/v13/values.tex`** retorna 2 macros novos
4. ✅ **`grep "Empirical tension with A3" work/v13/sec_appendix.tex`** retorna 1 ocorrência
5. ✅ `bash scripts/verify_paper.sh` retorna 15/15 PASS
6. ✅ `work/v13/paper_v13.pdf` recompilou
7. ✅ Number of macros aumentou para ≥446 (era 444)
8. ✅ Coerência abstract ↔ intro ↔ sec7_results ↔ conclusion: linguagem uniforme

## RE-REVIEW HOSTIL ESPERADA APÓS R2

Após execução, codex referee em re-review hostil deve:

- **Killer 1 RESOLVED:** "incoerência interna eliminada"
- **Killer 2 RESOLVED:** "falsification claim disciplinada"
- **Killer 3 RESOLVED:** "nuance contínuo-vs-binário declarada"
- **Killer 4 RESOLVED:** "tensão A3-empírico declarada honestamente"
- **Major 1 ainda PARCIAL → quase RESOLVED** (rationale econômico explícito ajuda)
- **Major 6 ainda PARCIAL → quase RESOLVED** (predições falsificáveis)
- Major 4 (heterogeneity) e Major 5 (causal) permanecem PARCIAL — não dá para resolver totalmente sem dados externos

**Score esperado:** 6 RESOLVIDAS + 4 quase-resolvidas + 0 novas críticas estruturais. Critério de Major Revision atingido (≤1 Major Não Resolvida).

**Probabilidade JLEO pós-R2:** **0.45-0.55** (subindo de 0.30-0.40 atual).

## DELIVERABLE FINAL

Resumo factual em ≤500 palavras:
- Lista de arquivos editados (com line numbers)
- Macros novos adicionados (lista)
- Critérios verificáveis 1-8 acima — quais passaram
- Diff de páginas PDF (era 109pp)
- Status final do verifier

Commit + summary curto. Não invente progresso que não existe.
