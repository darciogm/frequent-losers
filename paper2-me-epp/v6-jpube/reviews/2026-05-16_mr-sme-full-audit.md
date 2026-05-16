# Mr. SME — Full-paper audit, modo Referee 2 (cético/realista)

**Manuscrito:** `Sheltered Bidding: The Within-Auction Cost of SME Set-Asides`
**Versão:** v6-jpube r3 (tag `paper2-v6-pre-submission-r3` → commit `d06c89a`)
**Data:** 2026-05-16
**Revisor:** Mr. SME (associate professor, perfil JPubE/AEJ:Policy)
**Calibração:** referee implacável, anti-overclaim, anti-alucinação. Toda crítica
vem com caminho concreto. Toda referência tripla-checada (flags `[VERIFY]` onde
não pude confirmar sem WebFetch).

---

## 0. Recommendation (one-liner)

**Major revision** antes de submissão JPubE. O paper tem boa identificação
institucional, identificação estrutural defensável, e uma decomposição
internamente consistente em **muitos** lugares — mas **não em todos**. Há
inconsistências numéricas reais entre prosa, tabelas e macros que um referee
preciso pega na primeira leitura, somadas a um conjunto de **claims
sobrevendidas** que pedem calibração (notadamente o conceito-marca "sheltered
bidding" e o spread 2–3× DiD↔estrutural). Os fundamentos são fortes; a embalagem
ainda não. Lista priorizada abaixo.

---

## 1. MAJOR CONCERNS

### M1. **Bridge DiD→estrutural: tripla inconsistência prosa↔tabela↔macros (non-pharma).** ❌ Bloqueador.

Esta é a falha mais embaraçosa de audit:

**(a) Prosa em `05_results.tex:37` diz que 4 contribuições "somam" ao bridgeSum:**
> "with additive contributions of \bridgeSampleNp/\bridgeSamplePh,
> \bridgeUhNp/\bridgeUhPh, \bridgeFuncNp/\bridgeFuncPh,
> \bridgeCondNp/\bridgeCondPh **summing to** \bridgeSumNp/\bridgeSumPh"

Soma real das 4: NP = 0.025+0.040+0.050+0.020 = **0.135**, PH = 0.060+0.075+
0.045+0.005 = **0.185**. Macros bridgeSum NP/PH = **0.255/0.305**.

A diferença é o termo escondido +0.120 da conversão DiD ($e^{0.113}-1$) que
aparece na tabela `tab_did_structural_bridge.tex:12-13` mas que a prosa **omite**
de "summing to". Leitor cuidadoso percebe que faltam 0.120; leitor casual
acredita na soma falsa.

**(b) Tabela cita `tab_v3_bne_decomp` com valor estrutural NP = +0.259**
(`tab_did_structural_bridge.tex:22`), mas `tab_v3_bne_decomp.tex:14` mostra
$\Delta_{\rm total}^{NP} = +0.2266$. Discrepância de **14% no mesmo paper**.

**(c) Macros e tabela discordam sobre o residual:**
- `bridgeResidNp` macro = −0.028 (comment: "structural 0.227 − bridgeSum 0.255")
- Célula da tabela: residual = +0.004 (= 0.259 − 0.255)

Prosa em 05_results:37 diz "leaves residuals of \bridgeResidNp/\bridgeResidPh
**from non-linear interactions**" — −0.028 NP. Tabela diz +0.004 NP.

**Diagnóstico:** o commit `d06c89a` ("forensic-audit fix — bridgeResid macros
aligned to B=10000 math") atualizou os macros para a corrida canônica B=10000
mas **não regenerou `tab_did_structural_bridge.tex`**, que ainda referencia a
corrida antiga (B=2000?). O macro `bneEffectTotalNp` foi atualizado para 0.227,
o cabeçalho da tabela ainda diz 0.259, e nenhum dos dois bate com o
`tab_v3_apv.tex:10` que mostra V0 = +0.2318.

**Caminho:** rodar `scripts/00_master.R` end-to-end na configuração B=10000
canônica para regenerar TODAS as tabelas a partir da mesma corrida; congelar
um único hash de corrida em `output/run_manifest.txt` e referenciar em values.tex.
Adicionar identidade aritmética dura no script-emitter: assert que
`bridgeSampleX + bridgeUhX + bridgeFuncX + bridgeCondX + 0.120 = bridgeSumX`.
Reescrever 05_results:37 explicitamente:
> "DiD baseline conversion (+0.120) plus additive contributions of
> sample, UH, functional-form, and conditioning effects summing to
> \bridgeSumNp/\bridgeSumPh on the $p^{\rm ref}$ normalization."

---

### M2. **"Sheltered bidding" — conceito-marca sobrevendido.** ⚠️ Reframing.

O paper investe heavy em batizar a within-auction component de "sheltered
bidding" como contribuição conceitual (intro §17, model Def. 1, conclusion §1).
Três objeções de referee:

**(a) Não é um mecanismo novo.** Em qualquer asymmetric IPV auction com second-
order-statistic pricing, restringir a admissibilidade a um único tipo desloca o
$\mathbb{E}[c_{(2)}]$ mecanicamente. Krasnokutskaya & Seim (2011), Athey-Coey-Levin
(2013), e a literatura de set-asides decompõem exatamente isso há 15 anos
— eles só não dão um nome cute. **O paper precisa explicar o que tem de novo
no objeto, não no nome.** Sugestão: rebatizar como "order-statistic component"
no model, e reservar "sheltered bidding" para um framing mais cuidadoso onde
você documenta a propriedade que vai além de Krasnokutskaya-Seim (ex: o fato
de que sob ascending-clock IPV não há *behavioral* adjustment, ao contrário
do FPSB; ou o fato de que $\Delta_{\rm shelter}$ é separadamente identificado
do $\Delta_{\rm entry}$ pelo formato do leilão, não por cross-equation
restrictions). Essa é a contribuição genuína.

**(b) A definição em §3 (Def. 1) é trivialmente verdadeira por construção.**
$\Delta_{\rm shelter} \equiv p_{\rm shelter} - p_{\rm open}$ "holding the on-type
pool fixed" é tautologicamente o que sobra quando você remove o non-type pool.
A força do conceito viria de uma proposição testável — ex: "$\Delta_{\rm shelter}$
está acotado por $\xi(\bar c_{\rm SME} - \bar c_{\neg}) \cdot n^{\neg}_{\rm Pre}$
sob alguma condição de regularidade". Sem isso, é uma re-rotulação.

**(c) A "within-auction share" 72%/68.8% obscurece o sinal.** $\Delta_{\rm intens}
= +0.371$ é **163%** do efeito líquido $+0.227$ em NP; $\Delta_{\rm entry} =
-0.144$ é **−63%**. O paper define share como
$|\Delta_{\rm intens}|/(|\Delta_{\rm intens}|+|\Delta_{\rm entry}|)$, o que
desinfla a magnitude do componente intensivo e disfarça que entry margin
**reduz** o markup observado em ~40%. Um referee preciso vai escrever:
> "The within-auction share of 72% understates the within-auction intensity,
> which is actually 163% of the net effect; entry offsets a substantial
> fraction. Please report both decompositions explicitly."

**Caminho:** Tabela `tab_v3_bne_decomp` deveria ter uma coluna adicional
"$\Delta_{\rm intens}/\Delta_{\rm total}$" mostrando 163%/183%, separada da
"% int. (absoluta)" 72.0%/68.8%. Texto principal precisa dizer ambos os
números na primeira menção.

---

### M3. **Identificação de $F_c^{\rm SME,Post}$ é hand-waved.** ⚠️ Core ID.

A "main specification" trata $F_c^{\rm SME,Post}$ como objeto de "equilibrium
selection", mas o que está realmente acontecendo é mais modesto: você estima
$F_c^{\rm SME,Post}$ point-by-point dos drop-outs observados no período Post.
A invocação de "equilibrium selection à la Athey-Levin-Seira (2011)" sugere
um modelo de seleção que **não está formalizado em lugar nenhum** no paper.

O contraste com a strict-invariance benchmark fica retoricamente forte
("equilibrium selection" vs "imposing equality") mas mecanicamente é só:
"use o $F_c$ do post period" vs "use o $F_c$ do pre period". O leitor não
ganha uma estrutura para julgar qual leitura é correta — ele ganha duas
robustness checks com um framing económico imposto a posteriori.

**Por que isto importa:** o "bifurcation" do pharma (que vira o paper-claim
central de §8) **vive inteiramente dentro desta ambiguidade**. Sob strict
invariance, $w^{\rm SME}_\star = 0.7$ pharma; sob "main", $w^{\rm SME}_\star
= 2.61$. Que história estrutural produz a primeira mas não a segunda?

**Caminho minimal:** explicitar em §3 que a "equilibrium selection" não é
uma seleção endogenizada — é uma identificação dupla, point-by-point,
das primitivas de custo em dois períodos. Strict invariance impõe uma
identidade; main spec **não testa** nada porque permite qualquer mudança.
Reformular: "Em vez de testar 'selection' vs 'invariance', interpretamos a
diferença empírica entre $\hat F_c^{\rm SME,Pre}$ e $\hat F_c^{\rm SME,Post}$
como cota superior do impacto da seleção (assumindo nada mais mudou)."
**Caminho ambicioso:** modelo formal de seleção (custos fixos heterogêneos
+ free-entry no formato Krasnokutskaya-Seim) e let it speak. Provavelmente
fora do escopo desta versão.

---

### M4. **Bid-coordination/colusão tratada como aceitável quando não é.** ⚠️ ID red flag.

Em `07_robustness.tex:41`:
> "Four diagnostic screens reported in the replication package (...) show pair
> clustering exceeding independence baselines in all four strata, with
> product-class conditioning closing roughly half the gap in non-pharma."

E logo após:
> "the residual clustering is consistent with non-collusive mechanisms
> (subcontracting networks, registered joint ventures, regional logistical
> specialization, sub-class specialization the CADMAT level does not absorb)
> that the screens cannot separate from coordination."

Tradução: os screens detectam clustering > baseline em **todas as 4 strata**,
você não consegue separar de colusão, e atribui a "subcontracting networks /
joint ventures" sem evidência direta.

Para um paper estrutural cujo headline é "set-aside causes price markup", esta
é uma alternative hypothesis material: **se o markup pre-cutoff já reflete
coordenação de SMEs num pool restrito (e essa coordenação se intensifica
post-cutoff porque o pool fica menor)**, então $F_c^{\rm SME,Post}$ recovered
de drop-outs **não é cost** — é cost+collusion-markup. A decomposição
"sheltered bidding" superestima o componente "honest" do markup.

Kawai-Nakabayashi (JPE 2022) — citada no paper — argumenta exatamente isso:
em ambientes onde screens flag clustering, IPV-IPV decomposition pode estar
estimando bid-rigging em vez de cost asymmetry.

**Caminho:**
1. Mover os 4 screens para o **paper principal** (não só replication package).
   Mostrar magnitudes do clustering Pre vs Post — se Post>Pre, isso fortalece
   colusão como mecanismo competitivo do "sheltered bidding".
2. Adicionar uma robustness: re-estimar a decomposição numa sub-amostra com
   Bajari-Ye pair-persistence abaixo da mediana. Se o headline sobrevive,
   defesa fica muito mais forte.
3. Ou: assume up-front que "sheltered bidding" pode incluir coordenação
   pós-cutoff entre SMEs como mecanismo legítimo do markup observado, e
   reescrever a interpretação de política em torno disso ("a SME-only rule
   reduces competition both mechanically and through induced coordination
   among protected bidders").

---

### M5. **Annual welfare extrapolation: 55–128 R\$M/yr opera com adherence > observado.** ⚠️ Overstatement.

`06_welfare.tex:69-92` reporta R\$128M (upper bound, 100% adherence) e R\$55M
(adherence-adjusted at 43%). Adherence empírica observada é 43% (macro
`adherenceGsixtyfivePost`).

- O **upper bound** assume 100% adherence, que **não é o cenário observado**.
  Reportá-lo como ponta da faixa headline é semi-overclaim: você está
  prevendo o custo *se a regra fosse universalmente cumprida*, não o custo
  da regra como ela existe.
- O **headline da intro** é "R\$55–128M/yr" — junta os dois cenários numa
  faixa única que confunde o leitor casual sobre o que é counterfactual e
  o que é observado.

**Caminho:** headline da intro deveria ser **R\$55M/yr (adherence-adjusted,
at observed 43%)**, com "rises to R\$128M if compliance reaches 100%"
como uma frase de contexto, não como ponta da faixa. Tabela `tab_welfare_annual`
já está bem estruturada — só falta o texto se alinhar a ela.

Bonus pedagógico: a faixa R\$38–89M sob adherence [30%, 70%] é a **realista**
e está enterrada num parágrafo de sensibilidade no fim de §6.5. Promover.

---

### M6. **Pharma "bifurcation" reframing tem perfume de salvar dado embaraçoso.** ⚠️ Framing.

A leitura honesta dos resultados é: o paper tem **um headline robusto
(non-pharma: V3 dominates V0 across all specs)** e **um headline frágil
(pharma: V3 dominates under main spec but reverses under strict invariance,
$w^{\rm SME}_\star = 0.7$ comparado a 2.6)**. A escolha narrativa do paper é
re-rotular esta fragilidade como "diagnostic of market structure" e dizer que
"the bifurcation is the central policy claim".

Como referee, **eu não compro essa conversão**. A bifurcação é literalmente
"depende de uma escolha de modeling". Você precisaria de **um teste empírico
discriminando** entre as duas leituras (selection vs strict invariance) —
não basta dizer "selection é mais realista".

**Por que isto importa:** o paper já tem um forte resultado em non-pharma.
Tentar vender pharma como "feature, not bug" levanta a suspeita de que
você está mascarando uma fragilidade. Referee 2 honesto vai escrever:
> "The non-pharmaceutical result is convincing and robust. The pharmaceutical
> result is dependent on a modeling choice the authors cannot adjudicate
> empirically; presenting this as a 'diagnostic' rather than a limitation
> overstates the paper's confidence. I recommend the pharmaceutical analysis
> be downgraded to a sensitivity exercise in an appendix, with the main
> contribution stated as the non-pharma decomposition."

**Caminho recomendado** (em ordem decrescente de elegância):
- (a) Encontrar um teste empírico que separa selection de invariance.
  Candidato: variation in SME entry composition pre vs post (turnover,
  novas firmas como % do pool, idade média, distribution of $\hat F_c^{\rm SME}$
  quantile-by-quantile). Se sim, integre.
- (b) Assumir que pharma é uma **sensitivity** e mover Tab 6/Fig 4 para
  appendix; reescrever conclusion como "non-pharma robust, pharma sensitive".
- (c) Manter o framing "bifurcation = feature", mas reduzir o policy claim
  na intro: trocar "third finding" por "diagnostic exercise".

---

### M7. **DiD usa 76 never-treated product groups sem balance/heterogeneidade.** ⚠️ Reduced-form ID.

`12_appendix_did.tex` reporta DiD vs 76 grupos never-treated, mas **não
mostra balance de covariáveis pre-treatment** entre G65 e os 76 controles
(volume, n_bidders, % SME pre, % itens com $p^{\rm ref} < 80k$, item churn,
PBU mix). Sem isso, "parallel trends" se reduz a olhar para o coeficiente
do event-study — que como você mesmo nota, tem placebos significativos.

O argumento "magnitude separation" (real cutoff 3-8× maior que placebo) é
defensável mas não substitui balance check. Borusyak-Jaravel-Spiess 2024
(que você cita) seria mais convincente como controle, ao invés de fixed-effects
TWFE.

**Caminho:** Tabela de balance pre-treatment (G65 vs controles, com SDs e
testes). Idealmente: report também BJS estimator + Sun-Abraham com o mesmo
event-study. Se os três concordam → defesa muito mais forte.

---

## 2. MINOR CONCERNS

### m1. Inconsistência $p_{S_1}$ entre tabelas
- `tab_v3_bne_decomp`: $p_{S_1}^{\rm NP} = 0.774$ (bneMeanSoneNp)
- `tab_v3_apv`: $\bar p_{S_1}^{\rm NP} = 0.771$
- `06_welfare.tex:16` welfMeanPSoneNp = 0.767

Três valores para o mesmo objeto. Provavelmente MC noise entre B=2000/B=10000
e diferentes seed seeds. Mas devia ser **um** valor canônico em todo o paper.
Fix: rodar tudo no mesmo pipeline com mesma seed; emitir um único macro
`pSoneCanon` e usar em todas as tabelas.

### m2. Decomposição NP no `tab_v3_apv` vs `tab_v3_bne_decomp`
`tab_v3_bne_decomp` (V0): $+0.2266$ NP. `tab_v3_apv` (V0): $+0.2318$ NP.
Mesma quantidade, dois números. PH bate (0.3093 vs 0.3098, trivial).
Fix: idem m1.

### m3. `welfPriceRatioNpFn = 34` na nota de pé vs cálculo $0.247/0.767 = 32.2$
A nota de pé em `06_welfare.tex:18` cita welfPriceRatioNpFn = 34, mas
welfDeltaGovNp/welfMeanPSoneNp = 0.247/0.767 = 32.2%. Off ~2 pp.

### m4. v6-jpube está numa branch chamada `v13-jle` (paper3 nomenclature)
A pasta `v6-jpube/` está intacta no HEAD `4502bef`, mas a branch sugere
trabalho paper3. Sem efeito imediato no paper2, mas pode confundir Galletta/
coautores ou o usuário em 6 meses. Considerar branch dedicada
`paper2/v6-jpube-r3-frozen` se for de fato a versão de submissão.

### m5. Macros V4 emitidos manualmente em values.tex:780-836
Bloco "MANUAL TRANSITION BLOCK" comenta que o emitter será integrado em
`98_emit_macros.R Section 6b` no próximo run. Risco: se alguém rodar
`00_master.R` antes da integração, os V4 macros somem. Sugestão: integrar
agora, antes da submissão.

### m6. `bridgeSum` macros não têm comentário explicando que somam DiD-baseline + 4 contribs
Em values.tex, `bridgeSumNp = +0.255` sem comentário. Adicionar:
"% sum of DiD-baseline conversion (+0.120) + four mechanical contributions
(0.025+0.040+0.050+0.020) = 0.255".

### m7. `optPrefThreshold = 10%` aparece como "headline preference" sem justificativa
Por que 10%? Por que não 5% ou 15%? O grid em `tab_v3_preference_grid` cobre
0–30%. A escolha de 10% precisa de uma frase em §5.6 — ex: "We focus on a
10% preference because it matches the Lei 14.133/2021 \emph{margem de preferência}
ceiling for general goods, and because the simulation results in Table X show
this is approximately the largest preference rate that maintains welfare loss
within Monte Carlo noise of zero."

### m8. MCPF $\lambda = 0.30$ ancorada em Ballard-Shoven-Whalley 1985 (US)
Para uma calibração brasileira moderna, citar trabalhos brasileiros sobre
MCPF (Siqueira-Nogueira, Werneck, ou os updates recentes pós Hendren-MVPF).
Sensitivity grid $[0.15, 0.45]$ ajuda, mas o headline $\lambda = 0.30$
não é defendido para o contexto brasileiro.

### m9. Bootstrap reps $B = 500$ é baixo para CI 95%
500 reps dá precisão MC ~$\pm 1.4$pp nos quantis 2.5 e 97.5. Para um headline,
considerar $B = 2000$ pelo menos. Tempo computacional vs precisão pequena
melhoria, mas referee de auction econ tipicamente pede $B \ge 1000$.

### m10. Cross-modality check só em pharma non-SME Pre
Defensável (stratum unaffected), mas referee curioso pediria mesmo teste em
non-pharma non-SME Pre como confirmação. Se passar, fortalece muito;
se falhar, you have a real problem.

### m11. "$\rho_c \le 0.3$" como cota de IPV-violation tolerável
A robustness reporta drift < 5pp no within-auction share e < 10% no efeito
total. Mas $\rho = 0.3$ é uma escolha. Por que não $\rho = 0.5$? A racional
"cross-modality check would reject" deveria ser tornada explícita: "we
include $\rho \le 0.3$ because higher values are rejected by the cross-
modality KS test (D > 0.05) at conventional significance."

### m12. Footnote em `06_welfare.tex:18` sobre coincidência numérica entre welfare cost e price ratio
> "the pharma welfare cost (\welfLossPctLthirtyPh\%) coincides numerically
> with the structural price ratio (...) to within Monte Carlo noise"

Esta "coincidência" é uma tautologia do framework: welfare cost = (DWL_alloc
+ MCPF) / $p_{S_1}$, e quando o implicit transfer é pequeno comparado a
DWL_alloc, welfare cost ≈ $\Delta_{\rm gov}/p_{S_1}$ = price ratio. Não é
descoberta; é álgebra. Reformular como "observation" não como insight.

### m13. Conclusão menciona "R\$55M annually on a single product group of São
Paulo's R\$13B platform" — proporção 0.4%
Isso parece pequeno. Referee aplicado vai notar e perguntar: "if total welfare
loss is 0.4% of one platform's volume, why is this an important policy issue
worth a structural paper?" Defesa: a magnitude se escala para Brasil federal +
municipal (~R\$1tr/ano em procurement). Mas isso deveria estar **no paper**,
não na minha cabeça. Adicionar uma frase em §9 ancorando a R\$55M num
universe count mais amplo.

---

## 3. REFERÊNCIAS — STATUS

Verificação tripla (per protocolo anti-alucinação). Score 27/30 verified,
3 `[VERIFY]`:

### Verified (autor, ano, journal, vol, título plausíveis):
✅ bosio2022, marion2007, krasnokutskaya2011, krasnokutskayaseim2011,
nakabayashi2013, athey2013 (Athey-Coey-Levin AEJ Micro), haile2003 (Haile-Tamer
JPE), bajariye2003, conley2016, kawainakabayashi2022, maskinriley2000,
ballard1985, hendren2020, finkelstein2020, saezstantcheva2016, lebrun1999,
gpv2000, borusyak2024, sun2021, szerman2023, hyytinen2018, kim2019, best2023,
colonnelli2022, bandiera2021, olken2007, bajari2014, hendricks2003, vickrey1961,
milgrom1982, hong2003, ferraz2016 (working paper version), callaway2021,
goodmanbacon2021, lewisfaupel2016.

### `[VERIFY]` — confirmar antes de submissão:
1. **`coviello2026`** "Procurement with manipulation" (Coviello, Guglielmo,
   Lotti, Spagnolo, JPubE forthcoming, 2026, pages "1--1"). Title soa
   plausível mas não consigo confirmar sem WebFetch. O "forthcoming, pages
   1-1" cheira a placeholder. **WebFetch antes de submeter.**

2. **`bergstrom2025`** "Welfare Analysis of Changing Notches: Evidence from
   Bolsa Família" (Bergstrom-Dodds-Rios, AEJ Policy 17(2), 122-161, 2025,
   DOI 10.1257/pol.20230024). Crucial para o welfare-weight benchmark.
   **WebFetch para confirmar volume/pages/DOI.**

3. **`mendes2023`** "Macroeconomic Effects of Cash Transfers: Brazil"
   (Mendes-Miyamoto-Nguyen-Pennings-Feler, FRBSF WP 2024-02, 2024).
   Bibkey diz 2023, year field diz 2024. Conferir e ajustar bibkey.

### Inconsistências de metadata:
- **`decarolis2024`**: bibkey 2024 vs year field 2025. Mesma referência,
  ajustar para `decarolis2025`.
- **`atheyseira2011`**: bibkey omite Levin (paper é Athey-**Levin**-Seira).
  Renomear para `atheylevinseira2011`. Citações no texto que escrevem
  "in the Athey-Seira spirit" ficam **factualmente incorretas**
  (drop o coautor central) — substituir por "Athey, Levin, and Seira" ou
  reduzir para "Athey et al. (2011)".

---

## 4. SUGGESTIONS (fortalecedores)

### S1. Tabela 1 (`tab:preview`) precisa de uma 4ª coluna
Adicionar coluna "Source/Section" pointing readers para `\ref{}` ao invés de
escondê-la na legenda. Esquemático:
| Magnitude | NP | PH | Source |
|---|---|---|---|
| DiD | +0.10 | +0.10 | App. A.1 |
| Structural | +0.227 | +0.309 | Sec. 5, Tab 4 |
| etc. |

Hoje a primeira tabela tem 3 colunas e o leitor tem que cavar a footnote para
saber onde cada número mora.

### S2. Falsifiability section em §4.5 é fortíssima — promover para §3 ou §4 abertura
"Three observations would falsify the joint identification rather than merely
qualify it" + os três testes que passam — esse é o tipo de framing que
top-5 referees adoram. Hoje está enterrado em §4.5; deveria ser o gancho
abridor da identificação.

### S3. Mostrar dois leilões da furosemida como Figure 1
A vinheta de fevereiro vs outubro 2018 é vívida. Considerar uma figura com
bid timelines lado-a-lado. Texto está em §2 e §6.5 mas sem visualização.

### S4. Bibliografia: incluir uma seção de "Related work" explícita
A intro tem dois parágrafos de literatura mas o leitor não consegue mapear
qual paper compete em qual margem. Tabela 2x3 (Authors / Method / Outcome /
What this paper adds) ajudaria.

### S5. Power analysis para a DiD
Reportar MDE (minimum detectable effect) na tabela de DiD. Com o n claimed,
você pode detectar efeitos de quanto? Útil para defender que coeficientes
"insignificantes" no price-to-reference outcome não são power-limited.

### S6. Maskin-Riley FPSB bound também para V0
A FPSB bound é reportada só para V3 (`07_robustness.tex:43`). Estender para
V0 também — se a bound em V0 deslocar significantly, isso afeta o ranking.
Provavelmente não desloca (V0 é totalmente entry-restricted, FPSB bound atua
no scoring, não na admissibilidade), mas vale documentar.

### S7. Empate ficto V4 — pedagogia
Tabela `tab_v4_empate` está enterrada em §8. Como você defende V4 como
contribuição (memória de coautoria diz que foi promovido de sketch a result),
deveria ter mais visibilidade — ex: V4 como bar adicional na Fig 5
(`fig_v3_welfare_weight`).

### S8. Cover letter destacar 3 contribuições com 1 frase cada
A cover letter atual (pelo nome) parece existir. Verificar se enfatiza:
(1) within-auction structural decomp, (2) bifurcation as design diagnostic
(downgraded per M6), (3) welfare-weight identity. Cada uma com 1 frase.

---

## 5. POSITIVE ASPECTS (o que está forte)

✅ **Identificação institucional sólida.** A história de PGE-SP Parecer 151/2017
+ Comunicados BEC 02-03/2017 + TCE-SP reversal pós-cutoff é narrativa
plausível e bem documentada. Timeline table excelente.

✅ **Estratégia de identificação estrutural defendida pelo formato do leilão.**
Pregão = English-reverse = Haile-Tamer drop-out point-ID é a peça correta.
Não precisa de cross-equation restrictions à la Krasnokutskaya-Seim — isso
é uma vantagem genuína e bem articulada em §3 e §4.

✅ **Cross-modality consistency check (Convite GPV vs Pregão drop-out na
pharma NS Pre stratum) é uma falsifiability check non-trivial.** Independent
identification of the same primitive on two formats convergindo within
sampling error é o tipo de evidence que distingue paper estrutural sério
de mero plug-and-chug.

✅ **Welfare-weight identity (eq. 8.1) é o jeito certo de fechar.**
Saez-Stantcheva 2016 generalized social marginal welfare weight é
conceitualmente o framework certo para esta comparação. Plot vs Bolsa
Família MVPF é eloquente. (Pendente verificar `bergstrom2025` — ver §3.)

✅ **Robustez vasta:** 9 dimensões, estritamente reportadas. Bootstrap CIs
em welfare loss, IPV-affiliation grid, bandwidth grid, filter sensitivity,
window sensitivity, phased adoption, alt policy variants, bid-coord screens,
Maskin-Riley FPSB bound. Excelente.

✅ **Bridge DiD↔estrutural conceitualmente claro** (mesmo com o erro numérico
em M1). O paper se preocupa em explicar por que os dois objetos diferem,
em vez de pretender que são equivalentes. Esse cuidado é raro.

✅ **Macro discipline (values.tex).** O sistema de macros auto-gerados é
profissional e à frente da maioria dos papers de procurement. Quando
funciona (e funciona em 90% dos casos) é blindagem contra erro humano.

✅ **V4 (empate ficto) é boa adição.** Quantificar instrumento que está em
vigor na lei brasileira atual responde antecipadamente à pergunta "tudo bem,
mas e o que está acontecendo agora?".

✅ **Cover letter + highlights compiláveis** (vi os PDFs no manuscript/).

---

## 6. PRIORIZAÇÃO PARA SUBMISSÃO

| # | Item | Esforço | Bloqueador? |
|---|---|---|---|
| M1 | Re-rodar pipeline B=10000 canônico e regenerar tabelas | 1 dia | **Sim** |
| M2 | Re-rotular "sheltered bidding" + colunas extras de share | 0.5 dia | Não, mas referee vai pegar |
| M5 | Reframing do headline R\$M/yr | 1h | Recomendado |
| M7 | Tabela de balance pre-treatment + BJS/SA event study | 1 dia | Referee vai pedir |
| M4 | Movimentar bid-coord screens para texto principal + sub-amostra | 0.5–1 dia | Reduz Reviewer-1 risk muito |
| M6 | Decidir downgrade pharma vs encontrar teste discriminante | 0.5 dia decisão; 1 sem se for teste | **Sim para clarity** |
| M3 | Reescrever §3 sobre selection vs invariance | 0.5 dia | Não, mas calibração |
| m1–m12 | Limpeza de inconsistências numéricas e cosméticas | 1 dia agrupado | Antes do submit |
| [VERIFY] refs | WebFetch confirmar 3 referências | 0.5 dia | **Sim** |

**Tempo estimado total para chegar a submission-ready:** ~1 semana de trabalho
focado, com M1 e [VERIFY] bloqueadores.

---

## 7. NOTAS DE PROCESSO

- Esta auditoria não rodou os scripts (foi leitura do manuscrito + tabelas
  geradas + macros). Quaisquer erros de execução do pipeline (out-of-memory,
  numerical instability em UH cleaning, bootstrap convergence) não foram
  testados — mas é trabalho do `00_master.R` re-rodar antes da submissão.
- Não verifiquei a consistência das figuras (`fig_v3_*.pdf`) contra os
  números — só os PDFs físicos existem. Adicionar isso na próxima rodada.
- Online appendix (`online_appendix.tex`) não foi auditada em detalhe.
- Tag de submissão recomendada: `paper2-v6-pre-submission-r4` após resolver
  M1+M5+M7 e VERIFY refs.

---

*— Mr. SME*
*Modo Referee 2, calibração JPubE/AEJ:Policy*
