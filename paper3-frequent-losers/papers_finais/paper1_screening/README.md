# Paper 1: Screening for Bid Rigging with Frequent Losers

**Target**: IJIO (R&R minor)
**Status**: Pronto para submissao
**Source**: v12 (current)

## Claim
FL screen que usa apenas participation records e win/loss outcomes.
AUC = 0.94 contra CADE convictions. Price gap 3.6-7.7% (condicional).
Posicionamento: diagnostico, nao causal.

## Manuscript
- `manuscript/paper_screening.tex` (main file)
- `manuscript/paper_screening.pdf` (compiled, 78 pages)

## Code
- `code/` — full v4 pipeline (22 R scripts)

## Key Results
| Estimator | Coefficient |
|-----------|------------|
| Cross-fit | 0.036 |
| IPW | 0.055 |
| OLS | 0.064 |
| CEM | 0.077 |
| AUC (CADE) | 0.94 |
