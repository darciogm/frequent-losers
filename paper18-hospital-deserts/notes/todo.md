# Todo — paper18

Espelho rápido do `research_plan.md`. Para gestão de progresso ver TaskList do Claude.

## Hoje (28 abr)

- [ ] Resolver `environment.yml` (mamba env create -f environment.yml)
- [ ] Testar `pyreaddbc` em 1 arquivo SIH-AIH amostra
- [ ] Script 01: parse SIH 2015–2022 → parquet
- [ ] Script 02: parse SIM 2015–2022 → parquet
- [ ] Sanity log contagens vs TabNet

## Próximos 3 dias

- [ ] Script 03: CNES panel
- [ ] Script 04: amenable mortality (Nolte–McKee)
- [ ] Script 05: bipartite graph
- [ ] Script 06: node2vec embeddings
- [ ] Script 07-08: validação descritiva (NMI vs CIR, t-SNE)

## Decisões a tomar até dia 5

- [ ] Coautoria sim/não (e quem)
- [ ] Pooled vs panel embeddings
- [ ] Filtro de fechamentos exógenos (heurística final)

## Run-time goals

- [ ] Total wall-clock pipeline 01..06 < 4h em DarcioWork
- [ ] RSS pico < 12 GiB por script
- [ ] Logs em `04_logs/` para cada script
