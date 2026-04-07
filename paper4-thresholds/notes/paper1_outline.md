# Paper 1 — "The Real Effects of Narrow Wins"
## *Causal Effects of Public Procurement Contracts on Firm Employment, Wages, and Workforce Composition*

**Autores:** Galletta (ETH) · Genicolo-Martins (Insper) · Giommoni (UvA)
**Alvo primário:** Journal of Public Economics
**Alvos secundários:** REStat, AEJ: Applied
**Aspiracional:** JPE, AER (com execução excepcional)
**Status atual:** planejamento pós-pivot (2026-04-06)
**Gate check:** ✅ aprovado em 2026-04-06 (95.3% unweighted / 97.2% bid-weighted match BEC × RAIS)

---

## 0. Nota operacional

- **Restrição temporal**: RAIS linkada cobre 2009–2017. Tratamento deve ser `t ≤ 2015` para outcomes `t+2`. Amostra efetiva de tratamento: **2009–2015** (7 anos), janela de outcomes até 2017.
- **Amostra**: restringir a convite (sealed-bid) para evitar o problema mecânico de "last bid" em pregão e para manter consistência com KNOC-framework original.
- **Unidade de análise**: firma × ano. RD opera no nível lance, agregado à firma-ano via tratamento = "ganhou pelo menos um leilão close-bid em `t`".
- **Material pré-existente que se mantém**: `background.tex` (institucional BEC-SP) quase intacto; figuras `rd_plot_*.pdf`; limpeza de `df_convite_winner_looser.parquet`; definição de mercado; métrica `MV` (margin of victory).
- **Material que vira apêndice**: Tabela atual de jumps em incumbência/last-bid (vira manipulation/balance check).
- **Material que é reescrito do zero**: `introduction.tex`, `literature.tex`, `methodology.tex`, `data.tex` (match RAIS), `results.tex`, `conclusion.tex`.

---

## Estrutura de seções

### 1. Introduction (5–6 páginas)

**Primeiro parágrafo — gancho**:
- Governos gastam 12% do PIB global em procurement (Bosio–Djankov–Glaeser–Shleifer 2022 QJE). Em países em desenvolvimento, procurement é simultaneamente (i) instrumento de política industrial, (ii) canal de captura, e (iii) potencial motor de crescimento de pequenas firmas.
- Pergunta: **quais são os efeitos causais sobre firmas e seus trabalhadores de ganhar — ou perder por pouco — um contrato público?**
- Essa pergunta é policy-relevante porque o desenho de procurement (critérios de seleção, set-asides para PMEs, regras de pontuação) é um dos poucos instrumentos diretamente manejáveis pelo governo.

**Segundo parágrafo — lacuna empírica**:
- Literatura existente sobre efeitos de procurement sobre firmas é dominada por trabalhos com identificação fraca (matching, IV baseado em variação política). Exceção notável: **Ferraz–Finan–Szerman (2016, JPE)** — usa leilões municipais brasileiros e matching com propensity score. Nenhum paper até onde sabemos usa **close-bid RD** com **dados longitudinais empregador-empregado** para estimar simultaneamente efeitos sobre a firma E sobre os trabalhadores individuais.
- Por quê isso importa: o efeito agregado sobre a firma (receita, emprego) é uma média de heterogeneidades importantes — há rent-sharing com trabalhadores? Há seleção de trabalhadores (contratação de ex-servidores, revolving door)? Há crescimento real ou apenas transferência?

**Terceiro parágrafo — nossa contribuição**:
- Usamos 7 anos (2009–2015) do universo de licitações de convite do Estado de São Paulo (BEC-SP), linkadas a RAIS identificada por CNPJ raiz, com taxa de match de 97%.
- Exploramos um desenho de **close-bid RD**: firmas que ganham ou perdem por margem de preço <1% são quasi-randomicamente alocadas ao tratamento.
- Medimos efeitos sobre emprego, folha, salário médio, composição de trabalhadores e sobrevivência da firma, com horizonte de até 2 anos.
- Contribuição adicional (subseção Caminho 4): evidência direta de rent-sharing e contratação revolving-door.

**Quarto parágrafo — prévia de resultados**:
- [A preencher com números reais]
  - Ganhar o leilão aumenta o emprego em X% em `t+1` (IC: [a, b]).
  - Folha salarial cresce Y%, majoritariamente via headcount e não via salário médio.
  - Heterogeneidade: efeito concentrado em firmas pequenas/jovens; firmas grandes mostram menor elasticidade.
  - Sobrevivência: firmas narrowly-losing têm probabilidade Z pp menor de permanecer ativas em BEC em `t+2`.
  - Rent-sharing: salário médio sobe W% em firmas vencedoras, com mecânica de composição (contratação de novos trabalhadores melhor pagos) em vez de efeito firma AKM.

**Quinto parágrafo — posicionamento**:
- Contribuição 1: primeira estimativa causal dos efeitos de procurement em firmas usando close-bid RD em um país em desenvolvimento com dados linkados.
- Contribuição 2: contra Ferraz-Finan-Szerman (2016), usamos identificação mais limpa (RD > matching) e outcomes mais granulares (worker-level vs firm-level).
- Contribuição 3: [a depender dos resultados] documenta existência/ausência de rent-sharing em contratos públicos — contribuição à literatura de rent-sharing (Card et al. 2018 QJE) no contexto específico de demanda governamental.
- Contribuição 4: revolving-door evidence quantificada no micro, usando RAIS para identificar trabalhadores com passagem prévia pelo setor público.

**Sexto parágrafo — roteiro do paper**.

---

### 2. Institutional Background (2–3 páginas)

**Fonte primária**: `background.tex` atual — praticamente intacto.

Conteúdo:
- BEC-SP: plataforma eletrônica obrigatória desde 2007 para PBUs do Estado de SP.
- Convite vs pregão: regras, limites de valor, formato de seleção. **Justificar foco em convite**: (i) formato mais simples e canônico de first-price sealed; (ii) evita problema mecânico de "last bidder" do pregão; (iii) mantém consistência com KNOC.
- Reference price, processo de seleção, regras de adjudicação.
- Volume e valor: R$X bilhões em contratos no período, Y% do gasto estadual via BEC.

**O que adicionar**:
- Breve nota sobre o ambiente institucional de fiscalização (TCE-SP, CGE-SP, órgãos de controle) — contextualiza por que a "competição sob supervisão" não garante ausência de rent-sharing/captura.
- Ligação com o setor privado: que tipo de firma fornece via convite? (pista dos dados do gate check: 77% CNAE-4x, comércio atacadista/varejista — dominantemente bens de consumo público).

---

### 3. Data (4–5 páginas)

#### 3.1 BEC-SP microdata
- Fonte, período (2009–2015 para treatment; outcomes até 2017), estrutura.
- Amostra analítica: convite auctions com ≥2 bidders, ≥1 vencedor, bids válidos.
- Definição de `MV` (margin of victory) como running variable.
- Estatísticas: N leilões, N lances, N firmas, N PBUs, N mercados.

#### 3.2 RAIS identificada
- Fonte (MTE/IBGE via Insper com acesso pelo Darcio).
- Unidade: vínculo empregatício (worker × estabelecimento × ano).
- Variáveis usadas:
  - **Firma-nível**: CNPJ raiz, CNAE, natureza jurídica, data de abertura, número de vínculos ativos em 31/12, folha total, salário médio/mediano, número de estabelecimentos.
  - **Trabalhador-nível** (para Caminho 4): PIS, sexo, idade, escolaridade, CBO, salário, tempo de emprego, data de admissão, data de desligamento, motivo de desligamento.
- Limitações conhecidas:
  - CNPJ raiz vs estabelecimento (8 vs 14 dígitos) — escolhemos raiz para agregar filiais.
  - Cobertura 2009–2017 (gap 2018–2019 documentado no gate check).
  - Harmonização de layouts ESTB 2009–2010 vs 2011+.

#### 3.3 Linkage BEC × RAIS
- Match por CNPJ raiz (8 dígitos).
- **Tabela de cobertura** (reportar do gate check):
  - 11,964 firmas na amostra analítica BEC.
  - 11,402 (95.3%) com alguma cobertura RAIS.
  - 97.2% bid-weighted.
  - 97% no close-bid RD subsample.
  - 55% com trajetória RAIS completa de 9 anos.
- **Tabela de comparação matched vs unmatched** (ghost-firm signature).

#### 3.4 Variáveis do desenho
- **Running variable**: `MV` (percentual).
- **Treatment**: `winner` em leilão close-bid.
- **Outcomes firma-ano** (em `t`, `t+1`, `t+2`):
  - Log emprego (headcount ativos em 31/12)
  - Log folha salarial total
  - Salário médio
  - Share de trabalhadores contratados no ano
  - Share de desligamentos
  - Sobrevivência RAIS
  - Participação futura em BEC
  - Vitórias futuras em BEC
- **Pré-tratamento (teste de balanço)**: tudo do RAIS em `t-1`.

---

### 4. Empirical Strategy (3–4 páginas)

#### 4.1 Close-bid RD as local randomization

- Motivação: no limite `|MV| → 0`, a identidade do vencedor é *as good as random* (Lee 2008). Sob suposições de continuidade em outcomes potenciais e no suporte de `MV`, a estimativa RD identifica o efeito médio de tratamento local no cutoff.
- **Unidade**: par (vencedor, runner-up) em cada leilão close-bid → comparação dentro do mesmo leilão → controle mais rígido possível.
- Estimador: local linear com kernel triangular, CCT-optimal bandwidth, robust bias-corrected SE (Calonico–Cattaneo–Titiunik 2014 Ecma; Calonico–Cattaneo–Farrell 2018 REStat).
- Clustering de SEs: no nível auction (pair-level observação correlacionada).

#### 4.2 Agregação firma-ano

- Um mesmo lance close-bid é um evento; a firma pode ser tratada múltiplas vezes no ano.
- Duas especificações:
  - (A) **Cross-section por leilão**: observação = (firm × auction) com outcomes `t+k` medidos no nível firma-ano. Peso por leilão.
  - (B) **Painel firma-ano com stacked event study**: para cada firma, identificar o primeiro choque close-bid em cada janela, estimar efeitos dinâmicos (Cellini–Ferreira–Rothstein 2010; Callaway–Sant'Anna 2021).
- Preferência: (B) como baseline, (A) como robustez. Justificar.

#### 4.3 Validity checks

- **Density test**: Cattaneo–Jansson–Ma (2020) no running variable `MV`. Ausência de manipulação é crítica aqui (firmas colusoras poderiam ajustar bids precisamente para ficar no cutoff).
- **Balance test**: outcomes pré-tratamento (firma size, sector, wage bill em `t-1`) devem ser contínuos em `MV`. **Reaproveitar a Tabela 1 atual** do paper (jumps em incumbência e last-bid) como balance diagnostics, NÃO como outcome — e mostrar que os jumps desaparecem após firm FE, consistente com heterogeneidade persistente (o ponto central do parecer).
- **Placebo cutoffs**: estimar RD em cutoffs artificiais `MV = 0.05`, `0.10` etc. Deve dar zero.
- **Donut-hole RD**: excluir `|MV| < 0.001` para testar manipulação exata do cutoff.
- **Bandwidth sensitivity**: 0.5×h, 1×h, 2×h.

#### 4.4 Intepretação e LATE

- O efeito estimado é um LATE local: firmas marginais competindo por leilões disputados.
- External validity: não extrapolável para leilões de grande escala (fora de convite), mas representativo de ~R$X bilhões/ano de procurement recorrente em SP.

---

### 5. Main Results (6–8 páginas)

#### 5.1 Descriptive statistics
- Summary table: amostra analítica (11,964 firmas), close-bid subsample (~10,500 firmas em |MV|<0.02).
- Distribuição de outcomes no momento `t-1` para matched sample.

#### 5.2 RD validity (primeira evidência)
- **Figura 1**: density de `MV` com CJM test.
- **Figura 2**: continuidade de outcomes pré-tratamento (balance) ao longo de `MV`.
- **Tabela 1** (a antiga tabela do paper): jumps em incumbência/last-bid como *diagnostic*, não como finding. Mostrar que jumps atenuam drasticamente com firm FE.

#### 5.3 Main outcomes — firm-level
- **Tabela 2**: efeito do narrow-win sobre log emprego em `t`, `t+1`, `t+2`.
  - Col 1: sem FE
  - Col 2: market × year FE
  - Col 3: firm FE (permite interpretação within-firm)
- **Tabela 3**: efeitos sobre folha, salário médio, participação futura, sobrevivência.
- **Figura 3**: event study dinâmico (`t-2` a `t+2`) com bandwidth optimal.

#### 5.4 Heterogeneity
- **Tabela 4**: por quartil de tamanho inicial (micro/pequena/média/grande).
- **Tabela 5**: por setor (CNAE-2-dígito), por concentração do mercado (HHI de win shares), por tipo de PBU.
- **Discussão**: firmas pequenas têm elasticidade maior? Isso racionaliza o set-aside para PMEs (paper 2 do projeto bigger-picture!).

#### 5.5 Mechanisms
- Decomposição do crescimento de emprego: contratações novas vs redução de desligamentos.
- Decomposição do crescimento salarial: composição vs efeito firma (AKM em sub-amostra de firmas com ≥2 trabalhadores que transitam).
- Teste de rent-sharing: elasticidade salário-receita condicional a firma e ano.

---

### 6. Subsection — Revolving Door and Rent-Sharing (Caminho 4, 2–3 páginas)

**Motivação**: Se há efeito causal positivo sobre emprego e salário, três hipóteses:
- (H1) Choque puro de demanda: firma expande normalmente, contrata trabalhadores no mercado.
- (H2) Rent-sharing: firma divide parte do rent do contrato com trabalhadores existentes via aumento salarial.
- (H3) Revolving door: firma contrata ex-servidores públicos que "trouxeram" o contrato.

**Testes**:
- **(H1 vs H2)**: decomposição AKM do crescimento salarial. Se é H1, efeito firma AKM não muda (trabalhadores novos têm efeito-trabalhador médio); se é H2, efeito firma AKM sobe.
- **(H3)**: identificar trabalhadores admitidos em `t` ou `t+1` que têm histórico RAIS anterior em natureza jurídica pública (códigos 1xxx da `nat_juridica`) ou em estabelecimentos do próprio PBU comprador. Quantos trabalhadores assim? Eles se concentram em firmas tratadas? Estão em CBOs de decisão (gerentes, vendedores, diretores)?

**Tabela 6**: stock de ex-servidores públicos em firmas tratadas vs não tratadas, antes e depois do choque.

**Discussão**: isso fornece evidência micro-quantificada de revolving door em procurement brasileiro, literatura ainda muito baseada em estudos de caso ou em nível de elite política.

---

### 7. Robustness (2–3 páginas)

- Exclusão de firmas unmatched (562 firmas, 5%).
- Definição alternativa de mercado (CNAE 4-dígito vs closure transitiva).
- Estimação por GMM, por matching como cross-check.
- Inclusão/exclusão de pregão (alternative specification).
- Separação por período pré/pós Lei Anticorrupção 12.846/2013.
- Exclusão de PBUs outliers (grandes hospitais, universidades).
- Placebos: firmas tratadas "fake" via permutação de winners dentro de mercado.

---

### 8. Discussion and Policy Implications (2 páginas)

- Quanto dos R$X bilhões em procurement paulista gera externalidade positiva via crescimento de firmas vs quanto é puro transfer?
- Implicação para desenho de procurement: quanto vale set-aside para PMEs se os efeitos são maiores em firmas pequenas?
- Implicação para enforcement anti-corrupção: a magnitude do revolving door sugere onde focar auditoria.
- Limitações: external validity (SP, convite), efeitos de equilíbrio geral não capturados, período pré-2018.

---

### 9. Conclusion (1 página)

- Resumo dos 3 achados principais.
- Contribuição para literatura de procurement, rent-sharing, e política de desenvolvimento.
- Agenda futura: (i) extensão para pregão, (ii) segundo paper sobre networks de worker flows (Caminho 2), (iii) quantificação estrutural de welfare (Caminho 3).

---

## Figuras e tabelas previstas

| # | Item | Seção |
|---|---|---|
| F1 | Density de `MV` com CJM test | 5.2 |
| F2 | Continuidade de covariáveis pré-tratamento | 5.2 |
| F3 | Event study dinâmico (`t-2` a `t+2`) | 5.3 |
| F4 | Heterogeneidade por tamanho | 5.4 |
| T1 | RD jumps em incumbência/last-bid (diagnostic, ex-main) | 5.2 |
| T2 | Efeito sobre log emprego | 5.3 |
| T3 | Efeitos sobre folha/salário/survival | 5.3 |
| T4 | Heterogeneidade por tamanho | 5.4 |
| T5 | Heterogeneidade por setor e mercado | 5.4 |
| T6 | Revolving door: stock de ex-servidores | 6 |
| T7 | Robustness: alternativas | 7 |

---

## Checklist de próximos passos (ordem sugerida)

1. **Decidir janela de treatment**: `t ≤ 2015` ou renovar RAIS 2018–2019? Confirmar com Insper/MTE.
2. **Extensão do linkage_rais_bec.py** para construir painel firma-ano com TODAS as variáveis listadas em 3.4 acima (incluindo AKM inputs e dummies de revolving door).
3. **Script de amostra analítica**: criar subsample `|MV|<h` com `h` CCT-optimal.
4. **Primeiro teste RD** (piloto): emprego `t+1` como outcome, baseline specification. Validar ordem de magnitude.
5. **Balance tests e density test**: gate check #2 — a validade do RD.
6. **Event study dinâmico** completo.
7. **Rodar heterogeneidades**.
8. **Escrever draft das seções 3, 4, 5** (Data, Strategy, Results).
9. Literatura review direcionada (próxima etapa deste plano).
10. **Draft completo v0** → circular com Galletta/Giommoni.

---

*Documento gerado por mr-beneath em modo /co. Este outline complementa `replanning_paths.md` e deve ser revisado com os coautores antes da execução empírica.*
