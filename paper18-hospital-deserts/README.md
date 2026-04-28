# Hospital Deserts

**Beyond the Kilometer: Network-Revealed Access to Healthcare and Avoidable Mortality in Brazil**

Genicolo-Martins (Insper) · 2026

Submission target: **ETH/UZH Workshop in AI & Applied Economics** (Sept 11–12, 2026).
Submission deadline: **May 8, 2026**.

## One-liner

Aprendemos embeddings densos de municípios brasileiros a partir do grafo
bipartido paciente→hospital do SIH/DATASUS (2015–2022, ~50M internações).
Mostramos que **distância topológica** no espaço de embeddings — capturando
para onde pacientes *de fato* viajam — prevê mortalidade evitável melhor que
distância geográfica em km, e identifica desertos médicos invisíveis a métricas
tradicionais. Aplicação causal: choques de fechamento hospitalar via SIH/CNES
geram aumento dessa distância topológica e elevação de mortalidade Nolte–McKee
nos municípios afetados.

## Pergunta de pesquisa

A topologia da rede de fluxo de pacientes captura "isolamento médico" melhor
que distância geográfica? Municípios topologicamente isolados — depois de
condicionar em distância km, renda, oferta CNES, demografia — apresentam
mortalidade evitável maior?

## Contribuição

1. **Mensuração**. Primeiro índice de acesso à saúde *revelado* (não potencial)
   para os 5570 municípios brasileiros, com painel anual 2015–2022.
2. **Causal**. Choque de fechamento hospitalar como variação plausivelmente
   exógena para o indicador de embedding-distance, ligando explicitamente a
   piora de access à mortalidade evitável.
3. **Generalizável**. Receita replicável em qualquer país com dado
   administrativo de internações (claims, hospital discharge records).

## Linhagem econométrica

- **Currie & MacLeod (QJE 2008)**, **Chandra & Staiger (JPE 2007, 2020)**:
  acesso e qualidade hospitalar com distância como medida de access.
- **Allen & Atkin (Ec'a 2022)**, **Donaldson (AER 2018)**: redes de transporte
  e access economic.
- **Card et al. (RES 2009)**: access ao Medicare e mortality.
- **Nolte & McKee (BMJ 2003+)**: lista canônica de causas de morte evitáveis
  por intervenção médica oportuna.
- **Grover & Leskovec (KDD 2016)**, **Hamilton et al. (NeurIPS 2017)**:
  node2vec e GraphSAGE.
- **Sorkin (QJE 2018)**, **Card-Heining-Kline (QJE 2013)**: precedente em econ
  de usar mobilidade revealed para identificar estrutura latente — aqui
  pacientes em vez de trabalhadores.

## Repository structure

```
paper18-hospital-deserts/
├── 01_manuscript/        # paper.tex, paper.pdf
├── 02_data/
│   ├── raw/              # SIH/SIM/SINASC/CNES (DATASUS FTP), shapefiles IBGE
│   ├── intermediate/     # graph edge lists, embeddings (.npy/.parquet)
│   └── final/            # painel município-ano de outcomes + features
├── 03_analysis/          # scripts numerados 01_..→ NN_..
├── 04_figures/           # figs finais (mapas, ROC, t-SNE)
├── 04_logs/              # logs por script
├── 05_references/        # PDFs por bibkey
├── 06_scratch/           # exploração descartável
└── notes/                # research notes, decisions, todo
```

## Dados (todos públicos)

- **DATASUS SIH** (AIH-RD, 2015–2022): internações por procedimento, hospital
  de tratamento, município de residência. Edges do grafo bipartido.
- **DATASUS SIM** (2015–2022): óbitos com CID-10 → causas Nolte–McKee
  ("amenable mortality"). Outcome principal.
- **DATASUS SINASC**: nascimentos para mortalidade neonatal.
- **DATASUS CNES**: cadastro de hospitais — leitos, especialidades, eventos
  de abertura/fechamento. Choque de identificação.
- **IBGE**: shapefiles município, população, PIB per capita, urbanização.
- **TabNet/SUS-IPS**: cobertura ESF, IDSC.

## Build / run

```bash
mamba env create -f environment.yml
mamba activate paper18

bash run_pipeline.sh   # roda 01..NN em ordem, log em 04_logs/
```

## Estado atual

Setup inicial. Ver `notes/research_plan.md` para roteiro de 11 dias até deadline.
