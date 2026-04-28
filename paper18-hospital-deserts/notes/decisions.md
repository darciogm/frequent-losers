# Decisions log — paper18

## 2026-04-27 — Project kickoff

- **Why this paper**: ETH/UZH Workshop AI&Econ deadline 8 mai 2026. Após
  triagem das 5 ideias parqueadas (`ideas-workshop-aiecon-2026.md` no root do
  monorepo), escolhida #1 (hospital deserts via geo-embeddings). Combinação
  vencedora: viabilidade 11 dias (★★★★★) + AI density alta (★★★★) + alvo
  realista JHE/AEJ:Applied (top-field score 6.5/10) + dados 100% públicos
  (DATASUS) + identificação causal limpa via fechamentos hospitalares.

- **Por que não paper17**: paper17 (firm embeddings sobre RAIS) já está em
  curso e vai continuar em paralelo, mas tem ground truth pequeno (6 cartéis,
  31 firmas) → variância de AUC alta. Paper18 tem N=5570 munis × 8 anos
  × ~80M internações → poder estatístico folgado.

- **Naming**: `paper18-hospital-deserts` (segue padrão paper17, paper7 do
  monorepo bitter-pills).

- **Repo**: nested no monorepo `bitter-pills`, sem git remoto próprio inicial.
  Decisão de extrair depende de coautoria futura.

- **Coautoria**: sole-authored. Reabrir se rumar para journal full-paper
  (JHE preferiria coautor com bg em health econ — Marcos Lopes Filho?
  Rodrigo Soares? Decidir até dia 5).

## 2026-04-27 — Decisões de escopo

- **Período**: SIH/SIM 2015–2022. Pré-2015 SIH tem schema diferente;
  pós-2022 ainda em consolidação. 8 anos = poder OK para event-study.
- **Outcome principal**: amenable mortality (Nolte–McKee 2003+). Robustez
  com OECD avoidable mortality (versão revisada 2019).
- **Universo**: todos os 5570 municípios brasileiros. Sem restrição UF.
- **Embedding scope**: pooled 2015–2022 como baseline; painel anual como
  robustez. Não usar CTDNE no MVP (dia 5 do plano original do paper17 mostrou
  que ganho marginal é pequeno em datasets desse tamanho).

## 2026-04-27 — Identificação causal

- **Choque**: fechamento de hospital identificado via CNES (`motivo_desativacao`).
  Filtro: motivo administrativo/fiscal, **não** demanda decrescente.
- **Tratamento**: município que perde seu hospital de referência (definido como
  hospital com >X% das internações pré-fechamento).
- **Estimador**: Callaway-Sant'Anna (`did` R package) — heterogeneous treatment
  timing, tem boas propriedades para staggered adoption.
- **Pre-trend**: 3 anos pre-fechamento.
- **Outcomes**: (i) Δ embedding-distance ao novo hub, (ii) Δ mortalidade Nolte–McKee.

## Pendentes

- [ ] Confirmar acessibilidade DBC files DATASUS via pyreaddbc (dia 1).
- [ ] Decidir parsing Python vs R (ler .dbc) — preferir Python se viável.
- [ ] Sample size de fechamentos exógenos (estimado 50–200 — confirmar dia 6).
- [ ] Coautoria — decidir até dia 5.
