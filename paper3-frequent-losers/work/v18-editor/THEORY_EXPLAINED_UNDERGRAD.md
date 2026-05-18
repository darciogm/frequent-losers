# Aula: O framework teórico do paper, passo a passo para graduação

Vou usar uma linguagem direta. Quando aparecer algo técnico, paro e explico. Não pulo passos. A meta é: ao final, você deve conseguir explicar para outra pessoa por que o paper escolhe a estatística `log(1+tenders_count)` como ranking primitivo, por que filtra por `wins=0`, e por que isso tem fundamentação econômica.

---

## Aula 1 — O problema econômico

Imagine que você é um auditor do TCU (Tribunal de Contas da União). Sua missão é detectar cartéis em licitações públicas. Você sabe que cartéis existem (há condenações do CADE provando isso), mas eles são rotativos e se escondem.

**O problema central:** os cartéis usam uma técnica chamada "cover bidding". Funciona assim:
- O cartel decide internamente quem vai ganhar uma licitação específica
- Esse vencedor designado submete o lance vencedor (chamemos `b*`)
- Outras firmas do cartel também participam, mas submetem lances **propositadamente acima de `b*`** para perder
- O objetivo dos lances acima de `b*` é **simular competição**: "olha, teve 5 firmas competindo, parece um leilão competitivo"

As firmas que submetem lances perdedores propositais são chamadas de **cover bidders** (firmas-cobertura).

**Aqui está a chave do paper:** se você só observa quem ganhou e quem perdeu (sem ver os valores dos lances), você consegue identificar essas cover bidders? E se conseguir, você consegue usar essa identificação para priorizar quais firmas o TCU deve investigar primeiro com auditoria mais cara?

---

## Aula 2 — Modelando o cartel

Antes de derivar resultados, precisamos formalizar. **"Formalizar" significa escrever em matemática o que estamos descrevendo em palavras.**

### Os atores do modelo

- **O cartel:** um grupo de `n` firmas que coordenam suas ações em um mercado de procurement chamado `k`
- **O vencedor designado:** uma firma do cartel escolhida para ganhar; submete lance `b*`
- **As cover bidders:** outras firmas do cartel, em número `m`, que submetem lances perdedores (`b_ℓ > b*`)
- **As firmas genuínas (tipo G):** firmas legítimas que não fazem parte do cartel; participam para tentar ganhar de verdade

### As variáveis-chave

| Símbolo | O que significa | Por que importa |
|---|---|---|
| `m` | Quantas cover bidders o cartel deploya por período | É a escolha estratégica do cartel |
| `c_1` | Custo por cover bidder (taxa de inscrição, tempo administrativo, etc.) | Cada cover bidder custa caro para o cartel |
| `θ_k` | Probabilidade de o cartel ser detectado em mercado `k` | Mercados pequenos/mal-supervisionados têm `θ_k` baixo |
| `φ_0` | Penalidade marginal esperada por cada cover bid | Se for detectado, paga `φ_0` por cover bid |
| `R(m, θ_k)` | Lucro bruto que o cartel ganha deployando `m` cover bidders | Função econômica genérica; não precisamos especificar a forma exata |
| `κ` | Sanção interna do cartel se uma cover bidder ganhar por engano | "Não pode ganhar, senão tem castigo" |

### A função de lucro do cartel

O lucro líquido do cartel por período é:

$$\pi(m, \theta_k, c_1) = R(m, \theta_k) - (c_1 + \theta_k \phi_0) \cdot m$$

**Em palavras:** lucro = receita bruta menos (custo por cover bidder + custo esperado de detecção) vezes número de cover bidders.

### As suposições (Assumptions)

São 6 suposições. Vou explicar cada uma com analogia.

**A1 (Vale a pena ter pelo menos 1 cover bidder):**

$$\frac{\partial R}{\partial m}\bigg|_{m=0} > c_1 + \theta_k \phi_0$$

**Tradução:** se o cartel não tem cover bidder nenhuma, a receita marginal de adicionar a primeira é maior que o custo dela. Logo, vale a pena ter pelo menos uma. Sem essa suposição, o cartel não faria cover bidding nunca.

**A2 (Retornos decrescentes):**

$$\frac{\partial^2 R}{\partial m^2} < 0$$

**Tradução:** quanto mais cover bidders você já tem, menos a próxima adiciona em receita. Como em qualquer função econômica de produção/lucro normal. Garante que existe um número ótimo finito de cover bidders.

**A3 (Cartel-allocation incentive compatibility):**

Se uma cover bidder GANHASSE por desvio (em vez de perder propositalmente), ela ganharia `rents`. Mas o cartel a puniria com `κ`. A3 diz: `rents < κ`, ou seja, **o castigo é maior que a tentação**. Sem isso, cover bidders não obedeceriam a regra "submeta lance acima de `b*`".

**A4 (Tipos binários):** cada firma fora do cartel é OU cover bidder (tipo C) OU genuine entrant (tipo G). Tipos intermediários são absorvidos em G. **Tradução:** simplificação; o mundo tem outras variedades de firma, mas para o modelo basta esses dois.

**A5 (Deployment estacionário):** o cartel deploya em taxa constante ao longo do tempo, e os deployment events são conditionally independent across auctions. **Tradução:** o cartel não muda sua estratégia abruptamente; cada licitação que ele cobre é uma "amostra independente" com probabilidade fixa de ser cover-deployed.

**A6 (Selection no subset wins=0):** entre as firmas que NUNCA ganham, as cover bidders participam mais que as firmas genuínas. **Tradução:** firmas genuínas que sempre perdem são "perdedoras competitivas que desistiram de tentar"; cover bidders são "perdedoras profissionais pagas para participar".

---

## Aula 3 — O Lemma 1: Por que filtrar por wins=0?

**Statement do Lemma 1:** Em qualquer equilíbrio separating do bidding subgame, toda cover bidder satisfaz `b > b*`, e portanto `Pr(win | C) = 0`.

**Em português puro:** a probabilidade de uma cover bidder GANHAR é zero. Se você ver uma firma com `wins = 0` para sempre, ela é um candidato a cover bidder.

### Por que isso é verdade?

A prova é mais simples do que parece. É uma comparação de payoffs. Sigue:

**Caso 1 — Cover bidder obedece (submete lance `b > b*`):**
- Lance acima de `b*` → não ganha → `Pr(win) = 0`
- Payoff: `u_C(b) = -c_1 - θ_k φ_0` (paga custo de participação + sua parte do custo de detecção, **mas não recebe rents**)
- Custo total: `-c_1 - θ_k φ_0`

**Caso 2 — Cover bidder desobedece (submete lance `b' < b*` para tentar ganhar):**
- Se ela conseguir ganhar (lance dela é o menor), ela ganha rents = lucro do contrato
- Mas ela é punida pelo cartel (κ) e paga detecção (θ_k φ_0)
- Payoff: `u_C(b') = -c_1 - θ_k φ_0 - κ + rents`

**A comparação:**

$$u_C(b) - u_C(b') = -c_1 - \theta_k \phi_0 - (-c_1 - \theta_k \phi_0 - \kappa + \text{rents}) = \kappa - \text{rents}$$

Se `κ > rents` (que é exatamente A3), então `u_C(b) > u_C(b')`. A cover bidder prefere obedecer. Logo, em equilíbrio, ela submete `b > b*`. Logo, ela não ganha. Logo, `wins = 0` é a marca dela.

### O que esse Lemma NÃO prova

Atenção a essa nuance. O Lemma diz que CADA cover bidder não ganha. Mas não diz que existe um único valor de `b` que ela escolhe. Qualquer `b > b*` funciona — ela é indiferente entre `b = b* + 0.01`, `b = b* + 100`, etc. Todas levam a payoff `-c_1 - θ_k φ_0`.

**Por que isso importa?** Porque um referee atento poderia atacar dizendo "vocês alegaram unique equilibrium e isso é falso". O paper agora explicitamente diz: "the cover-bidder strategy correspondence is `{b: b > b*}`; the lemma pins down the equilibrium win probability and the wins-zero filter, not a unique numerical bid."

### Conclusão prática do Lemma 1

Se você só observa quem ganhou e quem perdeu (sem ver bid amounts), e quer encontrar candidates a cover bidder, você pode **descartar todas as firmas que algum dia ganharam**. Sobra um pool de "always-losers" — firmas que sempre perderam. Cover bidders ESTÃO nesse pool. Genuine entrants pode estar também (o pool é maior que o conjunto de cover bidders), mas nenhum cover bidder está fora dele.

**Esse é o primeiro grande resultado teórico:** justifica restringir a análise empírica ao subset always-losers.

---

## Aula 4 — A Proposition 1: Por que log(1+tenders_count) é a estatística certa?

**Statement:** No subset wins=0, o número de licitações em que uma firma participa segue uma distribuição de Poisson com taxa diferente para tipo C vs tipo G. Cover bidders participam mais (taxa `λ_C`) que genuine entrants (taxa `λ_G < λ_C`). Logo, `log(1 + tenders_count)` ranqueia firmas por sua probabilidade posterior de ser cover bidder.

**Em português puro:** dentro do pool de always-losers, quem participa mais provavelmente é cover bidder. A estatística `log(1+T_i)` é um índice que ranqueia a probabilidade de ser cover bidder.

### Por que Poisson?

A5 diz que deployment é estacionário e conditionally independent. Sob essa suposição, o número total de participações de uma firma sobre tenure τ anos segue:

$$T_i \sim \text{Poisson}(\lambda \tau_i)$$

onde `λ = λ_C` se for cover bidder e `λ = λ_G` se for genuine entrant.

Isso é apenas um modelo estatístico de eventos raros independentes. Pense: cada licitação que aparece, há uma probabilidade pequena de essa firma participar; quando você soma sobre muitas licitações, sai uma Poisson.

### Por que λ_C > λ_G?

Pela A6. Cover bidders são ATIVAS por design — o cartel as paga para participar. Genuine entrants permanente-perdedores são desistentes — firmas que tentaram, perderam, e participam pouco.

Se isso estiver errado (se genuine entrants permanente-perdedores também participarem muito), o resultado da Proposition 1 não vale. Por isso A6 é uma assumption explícita, não uma derivação.

### Por que log(1+T) é uma boa estatística para ranquear?

Aqui entra um pouco mais de matemática. A pergunta é: dado que observei T_i = t, qual a probabilidade de a firma ser cover bidder?

Pela regra de Bayes:

$$P(C \mid t) = \frac{P(t \mid C) \cdot \pi_C}{P(t \mid C) \cdot \pi_C + P(t \mid G) \cdot (1 - \pi_C)}$$

onde `π_C` é a probabilidade prior (chance ex-ante de qualquer firma ser cover bidder).

Esse posterior é uma função de `t`. Pergunta: ele é monotônico em `t`?

**Sim, sob MLR (Monotone Likelihood Ratio).** É um teorema clássico (Karlin-Rubin 1956): para a família Poisson com taxas diferentes (`λ_C > λ_G`), a razão `P(t | C)/P(t | G)` é não-decrescente em `t`. Se essa razão é monotônica, então o posterior `P(C | t)` também é monotônico em `t`.

**Consequência:** quanto maior `T_i`, maior a probabilidade da firma ser cover bidder.

### Por que log(1 + tenders_count), não simplesmente tenders_count?

`log(1+T)` é uma transformação monotônica de T. Ranquear firmas por `log(1+T)` é IDÊNTICO a ranquear por `T`. Então por que usar log?

**Razão econométrica:** quando você quer usar essa estatística como variável em uma regressão linear, log estabiliza variância e melhora ajuste. O `+1` evita log de zero (firmas com T=0). Mas matematicamente, para fins de ranqueamento posterior, `log(1+T)` e `T` são equivalentes.

**O que a Proposition 1 entrega:** justificativa econômica para usar `log(1 + tenders_count)` como o score primitivo do paper. Não é arbitrário — é o ranking statistic que segue do framework.

### A regra binária (Frequent Loser)

O paper também usa uma versão binária:

$$\text{FL}_i = \mathbf{1}[T_i > \text{med} + 1.5 \times \text{IQR}]$$

Isso é uma "coarsening" do ranking contínuo `log(1+T)`. Você está perdendo informação ao binarizar (dois cover bidders muito diferentes — um com T=20 e outro com T=200 — viram ambos FL=1). Mas binário é mais fácil de comunicar e de usar em policy. O paper reconhece o trade-off: "the binary frequent-loser rule is one information-coarsening of this posterior, with the empirical choice k = med + 1.5 × IQR a convention motivated by the empirical participation distribution rather than by the framework."

---

## Aula 5 — A Proposition 2: O cartel deploya mais onde detecção é cara

**Statement:** Sob A1 e A2, o cartel escolhe um deployment ótimo `m*` que satisfaz a condição de primeira ordem `∂R/∂m = c_1 + θ_k φ_0`. As comparative statics são:

$$\frac{\partial m^*}{\partial \theta_k} < 0 \quad \text{e} \quad \frac{\partial m^*}{\partial c_1} < 0$$

**Em português puro:**
- Se a probabilidade de detecção `θ_k` aumenta, o cartel deploya MENOS cover bidders
- Se o custo `c_1` por cover bidder aumenta, o cartel deploya MENOS cover bidders

### Por que isso é verdade?

O cartel maximiza o lucro líquido `π = R(m, θ_k) - (c_1 + θ_k φ_0) m`. Tomando derivada em `m` e igualando a zero:

$$\frac{\partial R}{\partial m} = c_1 + \theta_k \phi_0$$

Isso é a condição de primeira ordem. Em palavras: o cartel deploya cover bidders até o ponto em que **receita marginal = custo marginal**.

### Por que essa relação é negativa em θ_k?

Use o teorema da função implícita. Se você diferencia a FOC em relação a `θ_k`:

$$\frac{\partial m^*}{\partial \theta_k} = \frac{\phi_0}{\partial^2 R / \partial m^2}$$

O numerador é positivo (`φ_0 > 0`). O denominador é negativo (por A2: retornos decrescentes). Então a razão é **negativa**.

**Intuição econômica:** se a probabilidade de detecção aumenta, o cartel vê que cada cover bidder marginal é mais cara em expectation. Logo, reduz o número.

### Implicação empírica testável

Mercados com `θ_k` alto (compradores grandes, com mais oversight) deveriam ter MENOS cover bidder activity. Mercados com `θ_k` baixo (compradores pequenos, mal-supervisionados) deveriam ter MAIS cover bidder activity.

Se o paper encontra empiricamente que **o sinal do screen é maior em compradores menores**, isso é consistente com a Proposition 2. E é exatamente o que o paper encontra (sec_results_oversight, com gradient de Q1 vs Q4 quartile de buyer-size).

**Esse é um teste do framework.** Não prova causalmente o mecanismo, mas é uma comparativa estática derivada teoricamente que se confirma empiricamente.

---

## Aula 6 — A Proposition 3: Por que o sign reversal acontece

Essa é a Proposition mais difícil. Vou fazer com cuidado.

### O problema empírico que motiva

O paper roda regressões do preço contra a presença de Frequent Loser:

$$y_i = \alpha + \beta D_i + \delta x_i + \epsilon_i$$

onde `y_i` é log preço unitário, `D_i = 1` se item `i` tem pelo menos um FL participando, e `x_i` são fixed effects (item, ano, comprador).

O paper acha:
- **Broad sample** (todo o dataset): `β > 0` (FL presence está associado a preços mais altos)
- **Overlap restriction** (matching para garantir comparabilidade): `β^ov < 0` (oposto)

Por que o sinal flipa?

### O setup formal

Seja `u_i` um vetor de unobservables que governa a decisão do cartel de deployar em item `i`. O componente principal de `u_i` é o "rent shifter" — quanto rent o cartel pode extrair desse item específico.

Suposição: a probabilidade do cartel deployar é função estritamente crescente do rent component:

$$\Pr(D_i = 1 \mid x_i, u_i) = g(x_i, u_i)$$

com `g` crescente no rent component de `u_i`.

### Claim 1 — As distribuições de u diferem entre D=1 e D=0

Pela regra de Bayes, condicional em `D=1`, o cartel está em itens com `u` alto (rent alto). Condicional em `D=0`, em itens com `u` baixo. Logo, as distribuições de `u | D=1, x` e `u | D=0, x` diferem.

**Tradução:** itens onde o cartel deploya FL são SISTEMATICAMENTE diferentes (em rent) dos itens onde ele não deploya. Comparar diretamente é comparar maçãs com laranjas.

### Claim 2 — Common support overlap dentro de Ω

Se você restringe a comparação a itens onde existem counterfactuais comparáveis (common support), você obtém a região `Ω`. Dentro de `Ω`, as distribuições de `u` ainda são diferentes entre `D=1` e `D=0`, mas pelo menos os SUPORTES se sobrepõem.

**Tradução:** o overlap restriction garante que matching/IPW estimators são bem-definidos. Não garante que rent distributions sejam idênticas — só que existem comparáveis.

### Claim 3 — Por que o sinal flipa

Esse é o mais delicado. Suponha que rent shifter `u` afete tanto `P(D=1)` quanto realized log price na mesma direção. Por exemplo, "rent" é "margem que o cartel pode extrair", e essa margem é mais alta em itens caros (alta volume, alto valor unitário).

Decomposição:

$$\beta = \gamma + \delta \cdot \underbrace{(\mathbb{E}[\text{rent} \mid D=1, x] - \mathbb{E}[\text{rent} \mid D=0, x])}_{\text{selection bias}}$$

onde `γ` é o efeito causal direto da FL presence no preço, e `δ` é o efeito direto do rent no preço.

- `γ`: efeito causal verdadeiro da FL presence no preço
- `δ × (selection bias)`: efeito da SELEÇÃO endógena do cartel em itens com rent alto

**Cenário típico:**
- Se `γ < 0` (FL presence efetivamente baixa preços ou tem efeito pequeno)
- E `δ × (selection bias) > 0` e grande (rent shift positivo em ambas)

Então o broad-sample `β = γ + (positivo grande)` pode ser POSITIVO mesmo se `γ < 0`. Já o `β^ov` (overlap-restricted) atenua a selection bias e fica MAIS PRÓXIMO de `γ`. Pode ficar negativo.

**Conclusão da Proposition 3:** a sign reversal NÃO é evidence contra o cartel hypothesis. É consistente com o cartel selecionando endogenamente em itens com rent alto. O sign reversal RACIONALIZA-SE no framework, sem refutá-lo.

### Honesty da Proposition 3

A Proposition 3 explicitamente diz: "o framework NÃO deriva o sign reversal como predição única; identifica a auxiliary premise (rent co-movement) sob a qual ele é racionalizável."

**Isso é honesto.** O paper não afirma que o framework PREDIZ sign reversal. Apenas que ele é CONSISTENT com o framework. É uma estrutura de "interpretação" mais que "identificação".

Por isso o paper reduzido o destaque dado ao price imprint na main text e mantém a Proposition 3 in the OA — ela é estruturação interpretativa, não headline result.

---

## Aula 7 — Os testes econométricos: como o framework conecta com a empiria

Cada peça teórica produz uma predição testável. Aqui está o mapeamento clean:

### Lemma 1 → restrição amostral

**Predição:** cover bidders satisfazem `wins = 0`.
**Implementação empírica:** todas as análises do paper são restritas ao subset always-losers. Firmas que algum dia ganharam são descartadas do pool de candidatos.

### Proposition 1 → score contínuo + score binário

**Predição:** `log(1 + tenders_count)` ranqueia firmas por probabilidade de ser cover bidder.
**Implementação empírica:**
- Score contínuo: `log_tc` em todas as regressões e AUC tests
- Score binário: `FL_i = 1[T_i > med + 1.5 × IQR]` como treatment dummy

**Validação:** AUC contra cobidders adjudicados pelo CADE (ground truth). Se o framework está correto, AUC deve ser substancialmente acima de 0.5. Empiricamente: AUC ≈ 0.864 sob temporal holdout. **Confirmação forte.**

### Proposition 2 → buyer-size heterogeneity

**Predição:** `∂m*/∂θ_k < 0` significa que mercados com mais detection (compradores maiores) têm menos cover bidder activity.
**Implementação empírica:** sec_results_oversight mostra que o sinal do FL screen é maior em Q1 (compradores menores) versus Q4 (compradores maiores). Gradiente quase 5×.

**Confirmação direcional consistente** com a teoria. Não é prova causal mas é direcional alignment.

### Proposition 3 → estrutura de interpretação para sign reversal

**Predição:** β > 0 broad-sample é consistente com cartel selection em itens com rent alto. β^ov < 0 não refuta cartel hypothesis.
**Implementação empírica:** sec_results reporta β tanto broad quanto overlap-restricted, com decomposição segmentada por tender-value quintile. Interpretação como "two empirical objects under different sample compositions" + sensitivity bounds (Cinelli RV, Oster δ).

---

## Aula 8 — A grande síntese

O framework teórico do paper tem 4 peças:

1. **Lemma 1 (filtro):** wins=0 identifica candidatos cover bidder. Justifica restringir análise a always-losers.

2. **Proposition 1 (ranking):** `log(1+tenders_count)` é ranking statistic econômicamente fundamentado. Justifica usar essa variável como score do paper.

3. **Proposition 2 (heterogeneity):** cartel deploya mais onde detection é menor. Predição testável que se confirma empiricamente.

4. **Proposition 3 (interpretação):** sign reversal de β vs β^ov é consistente com cartel selection, não refutativo.

Essas 4 peças junto com 6 assumptions explicitas (A1-A6) formam o framework. Cada peça é matematicamente correta. Cada peça mapeia para um teste econométrico no paper.

**O framework não é "heavy theory"** — é um modelo simples e direto que justifica as escolhas empíricas centrais. **O framework também não é "no theory"** — há derivações reais, não apenas intuição. É **light theory aplicada** — o sweet spot para applied papers em IO/L&E.

**O que esse framework te dá como cidadão-leitor:** confidence de que as estatísticas usadas no paper (log_tc, FL flag, screening AUC) não são arbitrárias. Elas têm fundamentação econômica via Lemma 1 + Prop 1. As predições heterogeneidade (Prop 2) e interpretação (Prop 3) seguem da mesma estrutura.

**O que esse framework NÃO te dá:** prova causal de que FL = cartelista. Apenas evidência probabilística de que FL é cartel-adjacent. O paper é honesto sobre isso o tempo todo.

---

## Resumo de uma frase

O framework formaliza a intuição "cover bidders perdem propositadamente e participam muito" em quatro statements derivados, todos com proofs corretos, e cada um produz uma predição empírica testável que o paper confirma.

Isso é tudo que um framework de paper aplicado precisa fazer. Nada a mais. Nada a menos.
