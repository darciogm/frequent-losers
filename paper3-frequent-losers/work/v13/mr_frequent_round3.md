# mr-frequent — Round 3: avaliação da reframe winner/loser-side detection
## TL;DR
- A reframe winner-side versus loser-side **melhora muito** a coerência do paper em relação ao v13 e ao path-β, porque ela transforma o AUC≈0,50 contra réus diretos de um “fracasso embaraçoso” em uma implicação de desenho.
- Dito isso, a contribuição **não é automaticamente conceptually new**; no melhor cenário, ela é uma recombinação esperta de duas ideias existentes na literatura: screens baseados em bids/winners e limites informacionais da enforcement architecture.
- O argumento de custo informacional **é bom**, talvez o melhor do pacote, mas ele sustenta uma contribuição de *law-and-economics operacional*; por si só, ele **não** sustenta a versão ambiciosa “general framework of loser-side detection” sem um horse race explícito e institucionalmente disciplinado.
- Meu veredicto frio: **path-γ só vale a pena se vocês fizerem primeiro três diagnósticos duros**; sem isso, eu iria direto para **JLEO** com um framing honesto de screen administrativo de baixo custo.
## A reframe é conceptually new?
O ponto de partida correto é separar três perguntas.
- A pergunta 1 é: existe precedente para **winner-side screening**?
- A pergunta 2 é: existe precedente para **participant-side ou group-side screening sem microdados completos**?
- A pergunta 3 é: existe precedente para a formulação precisa “**systematic losers are the right screening object because cartel defendants are disproportionately winners and the losers are the dense, cheap margin**”?
Minha leitura é a seguinte.
**1. O bloco clássico da literatura mira bids, winners, ou a distribuição interna dos bids.**
- Porter e Zona estudam padrões de bids e winning behavior, não concentração de derrotas. % VERIFY: [Porter and Zona, 1993, Journal of Political Economy, Detection of Bid Rigging in Procurement Auctions]
- Porter e Zona no paper de Ohio também trabalham com bids e padrões compatíveis com cartel conhecido; novamente, não é uma teoria de loser-side concentration. % VERIFY: [Porter and Zona, 1999, RAND Journal of Economics, Ohio School Milk Markets: An Analysis of Bidding]
- Bajari e Ye propõem testes de exchangeability e conditional independence nas funções de bid; isso exige bids e uma partição suspeitos/franja. Não é um screen de losers. % VERIFY: [Bajari and Ye, 2003, International Economic Review, Deciding Between Competition and Collusion]
- Imhof 2019 é explicitamente um paper de screens descritivos derivados da distribuição de bids dentro do certame. % VERIFY: [Imhof, 2019, Journal of Competition Law and Economics, Detecting Bid-Rigging Cartels with Descriptive Statistics]
- Imhof, Karagök e Rutz 2018 perguntam “screening for bid rigging — does it work?”, mas o objeto estatístico continua sendo bid-level/tender-level descriptive screens. % VERIFY: [Imhof, Karagök and Rutz, 2018, Journal of Competition Law and Economics, Screening for Bid Rigging—Does It Work?]
- Huber e Imhof 2019 combinam screens com machine learning; de novo, screens construídos a partir de bids. % VERIFY: [Huber and Imhof, 2019, International Journal of Industrial Organization, Machine Learning with Screens for Detecting Bid-Rigging Cartels]
- Wallimann, Huber e Imhof 2023 endereçam cartéis incompletos com subgroup statistics dentro de tender, o que reforça precisamente o ponto de que o mainstream recente continua preso ao **espaço dos bids**. % VERIFY: [Wallimann, Huber and Imhof, 2023, Computational Economics, A Machine Learning Approach for Flagging Incomplete Bid-Rigging Cartels]
Até aqui, a intuição da reframe está correta.
- A literatura canônica de detecção observa lances.
- Quando ela não observa lances individuais, observa estrutura de grupos ou padrões de alocação próximos da margem de vitória.
- Ela não opera, em geral, com um score construído a partir da **massa de derrotas persistentes de firmas sem vitória**.
**2. Há, sim, literatura que se aproxima do lado “não-winner”, mas por outra porta.**
- Conley e Decarolis 2016 detectam **bidder groups** em leilões colusivos a partir de padrões de co-bidding; isso é mais próximo de estrutura de rede do que de winner-side. % VERIFY: [Conley and Decarolis, 2016, AEJ Micro, Detecting Bidder Groups in Collusive Auctions]
- Esse precedente importa porque enfraquece qualquer claim do tipo “ninguém nunca olhou para não-vencedores”.
- O que Conley-Decarolis fazem não é loser-side concentration screen.
- Mas eles já deslocam o foco do winning bid para a **estrutura relacional dos participantes**.
- Logo, vocês precisam escrever com precisão.
- A novidade não é “moving beyond winners” em abstrato.
- A novidade potencial é “usar **persistent losing intensity** como estatística de triagem de baixo custo, apoiada por um ambiente institucional em que a participação dos perdedores é densamente observável”.
**3. Kawai e Nakabayashi também reduzem o espaço conceitual disponível para uma claim maximalista de novidade.**
- Kawai e Nakabayashi, no JPE de 2022, identificam grande escala de colusão explorando rebids e padrões de alocação incompatíveis com competição. % VERIFY: [Kawai and Nakabayashi, 2022, Journal of Political Economy, Detecting Large-Scale Collusion in Procurement Auctions]
- Kawai, Nakabayashi, Ortner e Chassang usam RD com winning/losing bids muito próximos para inferir bid rotation e incumbency prioritization. % VERIFY: [Kawai, Nakabayashi, Ortner and Chassang, 2023, Review of Economic Studies, Using Bid Rotation and Incumbency to Detect Collusion: A Regression Discontinuity Approach]
- O programa deles não é winner-side no sentido banal.
- Mas continua sendo um programa que extrai sinal de **allocation patterns near the winning margin**.
- Ou seja, também não lhes entrega o espaço para dizer “a literatura só olha vencedores”.
- O máximo seguro é dizer:
- a literatura dominante de screens e testes operacionais usa bids, winners, margens de vitória ou grupos de co-bidding;
- ela não oferece, até onde consigo ver, uma formulação madura de **loser-side concentration** como screen administrativo de baixo custo.
**4. O caso Schurter precisa ser tratado com muito cuidado.**
- O item “Schurter 2017” que consegui localizar é a tese/dissertação “Identification and Inference in First-Price Auctions with Collusion”. % VERIFY: [Schurter, 2017, dissertation, Identification and Inference in First-Price Auctions with Collusion]
- Pelo resumo disponível, Schurter testa colusão bidder-by-bidder usando variação exógena no nível de competição e bids observados.
- Isso é um paper de identificação/inferência com bids.
- Não vejo nele, com o que está verificável agora, um predecessor direto do loser-side screen.
- Portanto, usar “Schurter já antecipou a assimetria winner/loser” seria arriscado.
- No máximo: Schurter ajuda no pano de fundo “detecção versus identificação”, não no objeto empírico loser-side.
**5. O item “Olson-Schurter 2024” está, para mim, bibliograficamente solto.**
- Eu não consegui ancorar com segurança um paper reconhecível “Olson-Schurter 2024” nesta literatura.
- Tratem isso como placeholder até que alguém encontre referência precisa.
- Se não encontrarem, retirem do argumento.
- Referee atento mata facilmente uma reframe que depende de uma citação fantasma.
- % VERIFY: [Olson-Schurter, 2024, ?, ?]
**6. A reframe é nova em que sentido, então?**
- Ela **não** é nova no sentido forte “introduz uma classe inteiramente inédita de detecção que rompe com toda a literatura”.
- Ela **pode ser nova** no sentido relevante para JLE:
- uma teoria operacional de triagem antitruste baseada no **lado dos perdedores**,
- motivada por uma **assimetria de custo informacional**,
- e testada num ambiente em que a regra jurídica induz densidade observável dessa margem.
Esse é um claim defensável.
Esse não é um claim trivial.
Mas ele precisa ser escrito com disciplina.
**7. O que é novo no pacote, se funcionar, é a conjunção, não cada peça isolada.**
- Peça A: a observação de que os benchmarks canônicos usam bids e/ou winner-side outputs.
- Peça B: a observação de que registros de participantes são mais baratos e mais disponíveis.
- Peça C: a hipótese de que, em alguns desenhos institucionais, a margem dos losers é mais informativa porque sua presença é parcialmente forçada pela regra.
- Peça D: a evidência de que um screen loser-side pega cobidders/ambientes suspeitos mesmo quando falha contra réus winner-heavy.
Separadamente, nenhuma dessas peças é revolucionária.
Juntas, elas podem compor uma contribuição boa.
Mas isso é contribuição de **arquitetura de enforcement**.
Não é contribuição de “nova identificação de cartel”.
**8. A claim “general framework” ainda está um degrau acima do que os números suportam hoje.**
- Hoje o paper sustenta, no máximo, uma proposição geral:
- “em sistemas de compras onde bids não são observáveis ou são caros de tratar, e onde a participação de losers é registrável, um loser-side concentration screen pode ser um instrumento útil de triagem”.
- Isso é um princípio geral.
- Mas “framework geral de loser-side detection” pede mais.
- Pede delimitar em que instituições o objeto loser-side é exógeno, parcialmente exógeno, ou totalmente endógeno.
- Pede comparar convites/concorrências/pregões em bases compatíveis.
- Pede mostrar quando o screen colapsa.
- Pede, sobretudo, dizer com precisão o que é “mercado”, “loss concentration”, e “administrative deployment unit”.
Sem isso, “framework” soa inflado.
Com isso, pode soar ambicioso e sério.
**9. O argumento de assimetria de custo informacional é, sim, o melhor caminho de contribuição.**
- Aqui a reframe ganha tração real.
- A literatura de screens com bids exige uma camada de dado mais cara.
- Mesmo quando o bid microdata existe, ele costuma exigir limpeza, reconstrução e matching muito mais intensivos.
- O registro de participantes, por contraste, costuma estar mais próximo do que o administrador efetivamente tem à mão.
- Em termos de JLE, isso é interessante porque desloca a pergunta de “qual screen é estatisticamente mais bonito?” para “qual screen é institucionalmente implementável?”.
Essa mudança é boa.
Ela é plausível.
Ela conversa com JLE.
Mas tem duas limitações.
- Primeiro, ela é uma contribuição mais de desenho institucional do que de IO empírica.
- Segundo, ela só sustenta um claim forte se vier acompanhada de evidência de que o custo mais baixo compra **pouca** perda de performance relativa.
Daí a centralidade do horse race Imhof versus FL no **mesmo universo**.
**10. O argumento jurídico-institucional brasileiro ajuda, mas precisa ser usado sem hipertrofia.**
- O Art. 22, §3º da Lei 8.666/93 de fato previa convite em número mínimo de 3 convidados; e o §7º tratava da impossibilidade de atingir o mínimo com justificativa. Fonte jurídica localizada. % VERIFY: [Lei 8.666/1993, art. 22, §§3º e 7º, Brasil]
- O Decreto 9.412/2018 atualizou valores-limite das modalidades; ele não é, por si, a origem da exigência de três convidados, apenas preserva a arquitetura da modalidade convite ao atualizar os thresholds. % VERIFY: [Decreto 9.412/2018, Brasil]
- Este detalhe importa porque um referee jurídico vai notar se vocês atribuírem ao decreto o que pertence à lei.
Portanto:
- a intuição institucional é boa;
- a redação jurídica precisa ser cirúrgica.
**11. A tese “loser participation is institutionally forced, therefore denser and cleaner” é promissora, mas ainda não está provada.**
- “Mais densa” é plausível.
- “Mais limpa” já é mais delicado.
- O fato de haver mínimo de convidados não garante que o registro reflita comportamento colusivo e não apenas cumprimento formal da regra.
- Na verdade, ele também pode aumentar justamente a mistura entre participation for compliance e participation for competition.
Isso não mata a reframe.
Mas muda o tom.
- O argumento correto não é que a regra produz um sinal limpo.
- O argumento correto é que a regra produz uma **margem observável e institucionalmente relevante**, sobre a qual vale a pena fazer triagem.
Isso é menos triunfalista.
Isso é mais defensável.
**12. O ponto mais forte que vocês têm é o seguinte.**
- Se a enforcement reality observa fácil e barato quem participou e perdeu,
- e observa mal ou caro os bids completos,
- então um screen loser-side pode ser valioso mesmo que não seja o screen estatisticamente ótimo em laboratório.
Isso é puro JLE.
- É custo de informação.
- É desenho de monitoramento.
- É arquitetura escalonada de enforcement.
Mas, repito, isso sustenta uma paper proposition do tipo:
- “low-cost, administratively deployable complement”.
Não sustenta, sozinho:
- “new general theory of cartel detection”.
**13. Em suma, meu julgamento sobre novidade conceitual é este.**
- A reframe **não é velha a ponto de ser trivial**.
- A reframe **não é nova a ponto de permitir grandstanding**.
- O espaço honesto está no meio.
Formulação que eu compraria como referee:
- “A literatura dominante de detecção em procurement extrai sinal dos bids, dos vencedores, ou de margens/alocações próximas ao vencedor. Este paper mostra que, em ambientes de dado administrativo incompleto e participação parcialmente induzida por regra, um screen construído sobre a concentração de derrotas persistentes fornece um complemento operacional de baixo custo para triagem.”
Formulação que eu rejeitaria como referee:
- “A literatura olha vencedores; nós mostramos que o lado certo é o dos perdedores.”
Esta segunda frase é atraente.
E excessiva.
**14. Resposta curta à pergunta central desta seção.**
- Conceptually new? **Parcialmente.**
- Suficientemente novo para JLE? **Talvez, se o paper vender a novidade como arquitetura informacional e não como ruptura teórica da literatura de cartel detection.**
- Já coberto por Schurter/Olson/Wallimann/Conley/Kawai? **Não de forma direta, mas todos eles comprimem o espaço para uma claim maximalista.**
## Strongest referee attack
Vou separar entre ataque fatal e ataques importantes, mas recuperáveis.
**Ataque fatal 1: isto parece rebatismo ex post de um resultado ruim, não contribuição ex ante.**
- A narrativa cética é simples.
- O paper primeiro se vendeu como detector de cartel.
- Depois descobriu que contra os 47 réus diretos CADE no universo BEC o AUC do `FL flag` é 0,491 e contra os 28 réus pós-2019 é 0,505.
- Isso é chance.
- Então os autores renomearam o objeto:
- “ah, mas nosso screen é loser-side, e os réus são winner-heavy”.
- Referee duro dirá:
- “isto não é insight; isto é racionalização posterior”.
Esse ataque é forte porque conversa com vários fatos ao mesmo tempo.
- O AUC bom aparece quando o ground truth vira os 193 cobidders.
- O binário FL14 perde para `log(tenders_count)` com AUC 0,939 contra 0,911, e no modelo conjunto o FL14 vira negativo.
- A história de mecanismo baseada em rotação/cartel clássico desorganiza no desenho unificado, com o maior efeito em Low HHI × Low pairs (+10,0%) e não na célula “assinatura”.
- O first-time-FL cai para +0,06 e p=0,31 no PS matching.
Um referee pode, portanto, resumir assim:
- “sempre que o objeto fica duro, o paper recua para uma versão mais frouxa”.
Se vocês não prevenirem isso frontalmente, o reframe morre.
**Ataque fatal 2: o paper não demonstra que winner-side versus loser-side é uma distinção empiricamente substantiva; apenas a declara.**
- Dizer que CADE defendants são winner-heavy e cobidders são losers não basta.
- É preciso mostrar, no mesmo universo de firmas e no mesmo horizonte temporal, que:
- winner-side statistics perform on winner-cartelists;
- loser-side statistics perform on loser-cobidders;
- e cada screen falha exatamente onde a teoria prevê.
Sem esse quadro, a distinção parece construída para salvar um caso particular.
Com esse quadro, ela vira um teste de mecanismo observacional.
Hoje, pelo que está posto, esse quadro ainda não está demonstrado.
Vocês têm fragmentos.
Ainda não têm a tabela matadora.
**Ataque forte 3: a diferença FL 0,903 versus Imhof full 0,888 é pequena demais para carregar a retórica de “complementaridade nova”.**
- Um gap de 1,5 ponto percentual em AUC é econometricamente interessante só se:
- for calculado na mesma amostra;
- tiver incerteza claramente reportada;
- vier acompanhado de DeLong;
- e, idealmente, vier com ganho incremental do combinado.
Sem isso, “complement” pode soar como eufemismo para “quase igual”.
Referee vai perguntar:
- se são quase iguais, por que não preferir o benchmark canônico mais próximo do objeto econômico?
- se FL é só mais barato, então a contribuição é custo, não performance;
- se a contribuição é custo, por que o paper continua escrito como contribuição de detecção?
Ou seja, o ponto pequeno no AUC é perigoso.
- Se supervendido, parece inflation.
- Se bem usado, ajuda justamente a tese operacional.
**Ataque forte 4: continuous-FL domina binary-FL; logo o paper está intitulado com a estatística errada.**
- Os números do round 2 são ruins para a ontologia “frequent losers”.
- `log(tenders_count)` tem AUC 0,939.
- `FL14` tem AUC 0,911.
- DeLong Z=-4,30, p<0,001.
- No preço conjunto, `FL14` é -0,075 com p=0,05 e `log_tc` é +0,071 com p<0,001.
Referee vai dizer:
- “o verdadeiro objeto é persistent losing intensity ou participation intensity among losers; o cutoff FL14 é só uma discretização conveniente”.
Essa crítica é tecnicamente séria.
Ela não é cosmética.
Ela afeta título, abstração e contribuição.
**Ataque forte 5: a heterogeneidade de mecanismo já não é compatível com a narrativa canônica de bid rotation ou market allocation.**
- No desenho unificado, Low HHI × High pairs vira +2,7% n.s.
- Low HHI × Low pairs vira +10,0% significativo.
- High HHI × High pairs vira -7,9% significativo.
Isso mina a leitura “o screen pega precisamente ambientes de cartel clássico”.
Referee vai concluir:
- ou o screen pega um conjunto muito mais amplo de ambientes relacionais;
- ou o padrão é ruído/sample mining;
- ou a interpretação causal do mecanismo era ex post.
Qualquer uma dessas leituras reduz a ambição do paper.
**Ataque forte 6: first-time-FL não resiste ao matching; portanto o paper perde seu fato micro mais intuitivo.**
- O resultado bruto de +0,20 com p=0,019 é interessante.
- Mas o CEM cai para +0,10 com p=0,08.
- O PS cai para +0,06 com p=0,31.
Logo, a versão forte:
- “quando o FL entra, o preço sobe”
fica sem sustentação disciplinada.
E justamente esse era o pedaço mais narrável para público não técnico.
**Ataque forte 7: a distinção entre “screen de loser-side” e “screen de ecossistema relacional” continua mal resolvida.**
- Se o screen não pega réus diretos winners,
- pega cobidders losers,
- e tem maior efeito justamente em célula sem assinatura clássica de rotação,
- então talvez o objeto real seja:
- firmas hiperparticipantes, sem vitórias, que orbitam mercados já pouco competitivos por outras razões.
Isto ainda pode ser policy-relevant.
Mas não é o mesmo que bid-rigging screen.
Referee hostil vai exigir que vocês escolham:
- ou “cartel screen”,
- ou “relational risk screen”.
Tentar ocupar os dois espaços ao mesmo tempo é instável.
**Ataque forte 8: a tese institucional convite versus pregão é bonita demais para a evidência disponível.**
- A promessa é excelente:
- convite/concorrência com loser participation mais institucionalizada;
- pregão com entry mais livre e loser participation mais endógena;
- comparar AUC por modalidade como teste natural.
Mas isso ainda é promessa.
Se o teste não vier, a reframe fica na fronteira da boa história.
JLE punirá isso.
JLEO pode tolerar.
**Ataque forte 9: a magnitude econômica encolhe quando o paper é honestamente reclassificado como screen.**
- Se vocês abandonam causal price effect,
- abandonam welfare headline,
- abandonam claim de cartel detection contra réus diretos,
- e abandonam mecanismo clássico,
- o que sobra é:
- um screen barato,
- com boa performance contra cobidders,
- e com correlação de preços que não é causal.
Isso é potencialmente bom.
Mas o referee pode perguntar:
- “isso é paper de JLE ou nota aplicada muito bem feita?”
Essa pergunta precisa de resposta substantiva, não retórica.
**Ataque forte 10: a paper proposition ainda depende demais de um único setting.**
- O argumento geral é sobre administrative data regimes.
- A evidência é sobre BEC/SP 2009–2019.
- Sem uma comparação interna forte entre modalidades, thresholds e availability regimes, o “general framework” fica sobrecarregado para um único caso.
JLE aceita artigos de um caso só.
Mas quando aceita, o mecanismo institucional precisa estar muito afiado.
Hoje, ele ainda não está.
**Síntese dos 2 ataques fatais que eu colocaria no meu relatório.**
Ataque fatal A:
- “The paper’s new loser-side framing reads as ex post relabeling of a direct-validation failure rather than as an ex ante conceptual contribution. The authors must show that the purported asymmetry generates testable out-of-sample predictions that distinguish loser-side from winner-side screens on the same sample.”
Ataque fatal B:
- “Even if the asymmetry is real, the paper does not yet show that it matters enough to support a general framework. At present it supports, at most, a low-cost administrative complement.”
Se vocês responderem A e B, o resto é manejável.
Se não responderem, o resto é ornamento.
## Rebuttals
Vou responder em modo coautor pragmático.
Não são respostas mágicas.
São as melhores respostas possíveis dado o estado do paper.
**Rebuttal ao ataque fatal 1: “isto é rebatismo ex post”.**
- Admitir metade da crítica.
- Resistir à outra metade.
Resposta possível:
- “Sim, a distinção não estava conceitualmente madura no v13, e os novos resultados forçaram a formulação explícita do objeto.”
- “Não, isso não é mera racionalização, porque a nova formulação gera previsões observacionais específicas que o v13 não gerava.”
- “Se a tela é de winner-side, ela deve performar melhor entre winners/defendants.”
- “Se a tela é de loser-side, ela deve performar melhor entre loser-cobidders e pior justamente contra direct defendants winner-heavy.”
- “A falha contra 47 réus diretos e o sucesso contra 193 cobidders não é ruído idiossincrático; é a predição central da assimetria.”
Esta resposta só funciona se vocês fizerem duas coisas.
- Primeiro, parar de vender o paper como “cartel detector” em sentido geral.
- Segundo, mostrar as previsões lado a lado numa tabela que pareça desenhada ex ante, não improvisada.
Se a redação for defensiva, perde.
Se a redação for:
- “the new evidence clarifies the object”
ganha alguma dignidade.
**Rebuttal ao ataque fatal 2: “vocês não provaram que a distinção winner/loser importa empiricamente”.**
- Concordar com a exigência.
- E satisfazê-la.
Resposta possível:
- “Nós concordamos que a distinção só é crível se ela gerar contrastes observáveis no mesmo universo.”
- “Por isso, reportamos um horse race harmonizado: winner-side screen(s), loser-side screen(s), e composição conjunta, na mesma janela, mesma amostra e mesmos rótulos.”
- “Mostramos então que cada score carrega informação em subconjuntos distintos e que o score combinado melhora a triagem total.”
Isto precisa de design claro.
- Mesmo sample.
- Mesmos positivos.
- Mesmo horizonte temporal.
- AUC, DeLong, calibration, e talvez precision at fixed FPR.
Sem isso, não há rebuttal real.
Há apenas insistência.
**Rebuttal ao ataque 3: “0,903 versus 0,888 é pequeno demais”.**
Esta objeção é boa, mas administrável.
Resposta possível:
- “Justamente: o ponto não é dominância estatística ampla; é custo marginal de informação.”
- “Se um score construído apenas com participação e derrotas entrega performance próxima de um benchmark baseado em bid microdata, isso é economicamente importante para desenho de enforcement.”
- “O paper não alega que FL substitui Imhof em bases ricas; alega que ele é um complemento barato e, em bases pobres, um substituto factível.”
Essa resposta muda o métrico de vitória.
- Não é “ganhar AUC por muito”.
- É “perder pouco AUC enquanto economiza muito custo de dado”.
Isso é um argumento de JLE.
Não é um argumento de Econometrica.
E tudo bem.
Mas a retórica tem de acompanhar.
- Nunca dizer “outperforms decisively”.
- Dizer “delivers comparable discrimination at substantially lower informational cost”.
**Rebuttal ao ataque 4: “continuous-FL domina binary-FL”.**
Aqui a defesa correta é concessão com reclassificação.
Resposta possível:
- “Concordamos que a estatística contínua é o objeto mais informativo.”
- “O binário FL14 não é apresentado como estatística fundamental, e sim como regra administrativa interpretável e de implementação simples.”
- “A contribuição conceitual do paper não é o cutoff 14; é o foco na margem de derrotas persistentes.”
- “O contínuo valida a tese geral loser-side; o binário operacionaliza uma versão deployable.”
Isso exige mudanças claras no paper.
- O título não pode fingir que 14 é ontologicamente especial.
- A seção metodológica precisa dizer explicitamente que FL14 é uma discretização administrativa de um sinal contínuo.
- Se vocês insistirem que FL14 é “a” categoria econômica, perdem.
Aqui, curiosamente, o contínuo ajuda.
- Ele mostra que o loser-side thesis pode sobreviver mesmo que a implementação binária precise ser relativizada.
Mas isso só ajuda se vocês abraçarem a relativização.
**Rebuttal ao ataque 5: “o mecanismo clássico não aparece”.**
Resposta possível:
- “Correto: a evidência não sustenta uma leitura afiada de cartel rotation clássica.”
- “O papel do paper não é mais identificar mecanismo específico, mas detectar concentração anormal de derrotas em ambientes de risco relacional.”
- “Mixed cells são esperadas em um screen geral de triagem: elas podem conter cartel, acomodação relacional, entry deterrence, ou mera estrutura repetida de mercado.”
- “Para enforcement, isso não zera o valor do screen; apenas redefine o output como triage rather than verdict.”
Isto salva o paper.
Mas ao preço de abandonar elegantemente a narrativa anterior.
Não dá para dizer:
- “não identificamos mecanismo, mas também isto é prova de cover bidding canônico”.
Escolham.
Minha recomendação:
- mechanism-agnostic screen;
- cartel-consistent, not cartel-specific.
**Rebuttal ao ataque 6: “first-time-FL não sobrevive matching”.**
Resposta possível:
- “Concordamos que o first-entry result não suporta inferência comportamental forte.”
- “Nós o rebaixamos a evidência descritiva de seleção de ambientes.”
- “O fato de o efeito cair com matching é consistente com a leitura de que FLs entram em mercados já diferentes, o que reforça a distinção entre screen e causal effect.”
Isto é uma defesa honesta.
Não é uma defesa sexy.
Mas funciona melhor do que teimar.
Em termos de manuscrito:
- o first-time-FL sai do corpo principal como ‘prova de mecanismo’;
- vira nota curta, apêndice ou limitação substantiva.
**Rebuttal ao ataque 7: “talvez seja relational risk, não cartel risk”.**
Esta é a objeção mais perigosa depois do rebatismo ex post.
Resposta possível:
- “A crítica é parcialmente correta e, por isso, o paper passa a usar linguagem mais precisa.”
- “Nosso screen não entrega verdict-level cartel identification.”
- “Ele entrega uma priorização de ambientes/firms-in-context onde loser-side concentration é anormal.”
- “Em nosso setting, esse risco relacional se sobrepõe de maneira estatisticamente relevante a casos CADE expandidos por co-participação.”
- “A pergunta de enforcement não é ‘isso prova cartel?’, e sim ‘isso reduz o custo de selecionar onde investigar?’.”
Esta resposta é boa para JLE.
Ela é menos boa se o editor quiser IO empírica mais substantiva.
Esse é justamente o trade-off de venue.
**Rebuttal ao ataque 8: “a comparação institucional por modalidade ainda é promessa”.**
Resposta possível:
- “Concordamos, e por isso não pedimos ao leitor que a aceite por mera narrativa.”
- “Reportamos AUCs e performance comparada por modalidade.”
- “Se loser-side funciona melhor onde loser participation é mais institucionalizada, isso fortalece a tese.”
- “Se não funciona, nós moderamos a claim.”
Ou seja:
- aqui não há rebuttal sem teste.
- há apenas compromisso de não overclaim.
**Rebuttal ao ataque 9: “sobrou pouco demais para JLE”.**
Resposta possível:
- “Sobrou exatamente o que JLE valoriza quando o paper é honesto: um problema de desenho institucional sob restrição de informação.”
- “O paper não pergunta mais qual é o markup do cartel.”
- “Pergunta qual é o objeto monitorável por uma autoridade que não tem bid microdata limpo.”
- “A resposta inclui uma estatística simples, uma discussão de custo informacional, uma comparação com benchmarks mais ricos, e um pathway de triagem.”
Esta defesa tem alguma chance em JLE.
Não teria muita chance em RAND se escrita assim.
Por isso o venue question é real.
**Rebuttal ao ataque 10: “um caso só é pouco para framework”.**
Resposta possível:
- “A paper does not claim universal external validity.”
- “It claims a portable logic.”
- “Brazil provides a useful institutional laboratory because participation records are centralized and the legal architecture creates modality contrasts.”
- “We therefore offer a framework proposition and one unusually clean test bed, not a universal estimate.”
Novamente:
- trocar “general framework” por “portable framework proposition” ou “general logic”.
- Isso tira pompa.
- E aumenta credibilidade.
**O que eu diria, em uma frase, para salvar o pacote.**
- “The reframing is viable if and only if the paper becomes explicitly about the economics of monitoring under asymmetric data costs, with loser-side concentration presented as a screening object whose value is administrative and complementary, not as a superior detector of cartelists per se.”
**O que eu NÃO diria.**
- “The paper shows that the literature has looked at the wrong side of the market.”
Essa frase pede punição.
## Diagnostics needed before §3 NEW
Esta é a seção mais importante do parecer.
Se vocês começarem a escrever §3 NEW antes de rodar estes diagnósticos, estarão escrevendo retórica sem saber se a retórica tem suporte.
1. **Fechar a bibliografia da assimetria winner/loser com precisão cirúrgica.**
- Identificar exatamente quais papers são:
- winner-side/bid-side;
- group-side/network-side;
- allocation-side near the winner;
- identification papers com bids;
- screens com incomplete cartels.
- Retirar qualquer referência não ancorada.
- Em particular, resolver “Olson-Schurter 2024”.
- Se não existir como referência limpa, apagar.
2. **Produzir uma tabela-mestra de objetos, dados exigidos e output de cada literatura comparada.**
- Colunas mínimas:
- Paper.
- Unit of analysis.
- Data required.
- Output object.
- Detects winners?
- Detects losers?
- Needs bid microdata?
- Needs ex post cartel labels?
- Can run on participant registry only?
- Essa tabela pode matar metade da discussão de novidade.
3. **Rodar o horse race harmonizado FL versus Imhof na mesma amostra.**
- Não aceito mais comparações de números gerados em amostras ou universos diferentes.
- Definir um universo comum.
- Reportar AUC FL binário.
- Reportar AUC loser-intensity contínuo.
- Reportar AUC Imhof full ou a melhor aproximação viável.
- Reportar AUC do combinado.
- Reportar DeLong para cada comparação relevante.
- Sem isso, “complementarity” é conversa.
4. **Rodar o horse race harmonizado contra dois ground truths diferentes.**
- Ground truth A: réus diretos CADE.
- Ground truth B: cobidders identificados.
- Idealmente Ground truth C: pós-2019 prospective subset, se o universo permitir.
- O ponto é mostrar que o contraste winner-side/loser-side depende do rótulo de verdade de forma previsível.
5. **Construir a decomposição winner-heavy do universo CADE com transparência total.**
- Quantos dos 47 são winners?
- Quantos são always-losers?
- Quantos dos 193 cobidders são always-losers?
- Quantos são losers persistentes?
- Como isso varia por modalidade?
- Hoje a narrativa depende desses números.
- Eles precisam virar tabela canônica do paper, não nota oral.
6. **Fazer o teste institucional convite versus pregão que a reframe promete.**
- Reportar AUC por modalidade.
- Reportar prevalência de FL por modalidade.
- Reportar performance de continuous loss intensity por modalidade.
- Reportar, se possível, performance do benchmark winner/bid-side por modalidade.
- Se a tese institucional estiver certa, convite/concorrência devem parecer diferentes de pregão de maneira interpretável.
7. **Testar sensibilidade da tese a definições de loser-side.**
- FL14.
- Percentis.
- IQR-based continuous tail.
- Rank-based loss intensity.
- Participation count among always-losers.
- Share of participations in repeated markets.
- Se a tese só funciona com um cutoff arbitrário, morreu.
- Se funciona em família, ganhou robustez conceitual.
8. **Testar se o screen usa apenas escala de participação ou algo além dela.**
- O round 2 já sugere que `log(tenders_count)` carrega muito.
- Falta mostrar se a informação adicional vem de:
- zero wins;
- concentração em mercados específicos;
- repetição com certos vencedores;
- persistência temporal;
- cross-market concentration.
- Se tudo vier apenas do count, então o paper deve mudar de nome.
9. **Calcular métricas administrativas além de AUC.**
- Precision at fixed FPR.
- Recall at fixed investigative capacity.
- Top-k hit rate.
- PPV em percentis superiores do score.
- AUC é bom para paper.
- Autoridade usa fila de investigação.
- O argumento de JLE melhora muito se vocês mostrarem valor operacional em budget-constrained triage.
10. **Fazer calibration plot ou tabela simples por vintis/decis do score.**
- Um screen administrativo precisa parecer calibrado, não apenas rankear bem.
- Se a taxa de positivos cresce monotonicamente nos decis superiores do continuous loser score, isso ajuda a vender a generalidade do objeto.
11. **Escrever uma seção interna só para decidir o que é o objeto.**
- É “frequent losers”?
- É “persistent losing intensity”?
- É “loser-side concentration”?
- É “participant-side concentration among non-winners”?
- Vocês precisam decidir antes de escrever.
- O paper hoje corre o risco de usar quatro nomes para quatro objetos levemente diferentes.
12. **Rebaixar formalmente o resultado first-time-FL antes da redação principal.**
- Não entrar em §3 NEW com a ilusão de que esse bloco ainda sustenta mecanismo.
- Definir desde já:
- apêndice,
- nota curta,
- ou limitação.
13. **Reescrever a interpretação do bloco de heterogeneidade antes de qualquer nova teoria.**
- O padrão Low HHI × Low pairs +10,0% precisa ser encarado de frente.
- Escrever duas ou três leituras alternativas que não sejam cartel clássico.
- Depois decidir qual linguagem mínima sobra no corpo principal.
- Se vocês não fizerem isso antes, §3 NEW vai nascer contaminado pela narrativa antiga.
14. **Verificar juridicamente a redação da tese institucional.**
- Art. 22 §3º.
- Art. 22 §7º.
- Relação entre convite mínimo e efetiva observabilidade de participantes.
- Papel exato do Decreto 9.412/2018.
- Base legal/administrativa da publicidade dos registros de participantes no BEC e/ou sob LAI.
- Não para citar lei em excesso.
- Para não errar onde o argumento é mais verificável.
15. **Mensurar, mesmo que grosseiramente, o custo informacional relativo.**
- Número de arquivos.
- Número de campos.
- Necessidade ou não de reconstruir bids.
- Tempo de processamento/limpeza aproximado.
- Não precisa transformar em paper de engineering.
- Mas algum quantificador concreto melhora muito um argumento hoje ainda qualitativo.
16. **Produzir a tabela “quando o screen deveria falhar” e mostrar que ele falha ali.**
- Against direct defendants winner-heavy: should fail or weaken.
- Against loser-cobidders: should improve.
- In free-entry settings: should weaken.
- In invitation/minimum-participation settings: should strengthen.
- Esta tabela é essencial.
- Ela converte a reframe de desculpa em hipótese testável.
17. **Testar se a comparação loser-side versus winner-side muda com a janela temporal.**
- Vocês já têm monotonicidade 0,82→0,94 com janela, segundo a proposta.
- O que importa agora é saber:
- o contraste entre os dois tipos de screen aumenta com mais tempo?
- some com janelas curtas?
- Isso dirá se o loser-side object depende de repetição longa para existir.
18. **Checar overfitting narrativo do score cobidder.**
- Se o screen é bom apenas porque co-bidder labels estão muito próximos de repeated participation networks, o resultado pode ser tautológico.
- Precisam discutir isso explicitamente.
- Idealmente, separar cobidders próximos versus distantes do núcleo CADE.
19. **Definir se a contribuição comparativa com Imhof é performance ou feasibility.**
- Não pode ser as duas com igual ênfase.
- Escolham a primária.
- Minha recomendação:
- primária = feasibility under low data cost.
- secundária = performance close enough to matter.
20. **Rodar placebo substantivo onde loser-side não deveria dizer nada.**
- Se houver um subconjunto institucional em que loser participation é claramente não informativa, usem-no.
- Um bom placebo negativo aumenta muito a credibilidade da assimetria.
21. **Decidir ex ante se o score final do paper será contínuo ou binário.**
- Minha preferência é:
- score principal contínuo;
- regra operacional binária como derivação.
- Isto reduz a exposição ao ataque “cutoff opportunism”.
22. **Escrever o abstract provisório só depois dos testes acima.**
- Antes disso, o risco de cristalizar a história errada é alto.
23. **Se qualquer um dos testes cruciais falhar, abortar o path-γ.**
- Cruciais:
- horse race harmonizado;
- modalidade por modalidade;
- tabela winner-heavy;
- robustez do objeto contínuo.
- Não escrever 30 páginas para depois descobrir que a distinção não se sustenta.
## Probabilidades atualizadas
Antes da tabela, uma observação metodológica.
- As probabilidades abaixo não somam 100% por construção simples de journal placement.
- Há massa residual de:
- desk reject,
- revise que morre,
- ou queda para outlet abaixo de JLEO/IJIO.
- O objetivo aqui é comparar caminhos, não fechar uma distribuição total perfeita.
| Caminho | JLE | JLEO |
|---|---|---|
| Path-γ: reframe winner/loser **com** diagnósticos duros confirmando a assimetria | 0,22 | 0,27 |
| Path-γ: reframe winner/loser **sem** confirmação limpa da assimetria | 0,06 | 0,18 |
| Path-A: ir direto com framing honesto de screen administrativo de baixo custo | 0,00 | 0,55 |
Leitura da tabela.
- O teto de JLE com path-γ existe.
- Ele é real.
- Mas é bem menor do que os 38% estimados pelo autor.
Minha conta mental é esta.
- O reframe melhora a inteligibilidade do paper.
- JLE gosta de papers sobre o que instituições podem saber sob restrição de dados.
- Porém JLE também pune duramente papers que soam como reconstrução ad hoc após resultados desconfortáveis.
- O path-γ só sobe para algo em torno de 20–25% se vocês fizerem o dever de casa empírico antes da escrita.
Já o path-A tem uma virtude simples.
- Ele renuncia ao upside de JLE.
- Em troca, preserva melhor a integridade do resultado e aumenta a chance de placement eficiente.
Se eu tivesse de converter isso em expected value prático:
- path-γ tem maior upside, maior variância e maior custo de tempo;
- path-A tem menor upside, maior previsibilidade e provavelmente melhor retorno marginal por semana de trabalho.
## Recomendação final
Minha recomendação é **A, salvo se vocês aceitarem um gatilho decisório muito rígido para γ**.
Em português claro:
- Eu **não** iniciaria a reescrita JLE winner/loser agora.
- Eu primeiro rodaria os diagnósticos cruciais.
- Se eles confirmarem a assimetria de forma limpa, aí sim eu autorizaria path-γ.
- Se não confirmarem, eu iria direto para JLEO sem remorso.
Portanto, minha decisão formal é:
- **Hoje: A condicional.**
- **Operacionalmente: tratar γ como opção, não como decisão tomada.**
Se você me forçar a escolher um caminho **já**:
- eu escolho **A**.
Por quê.
- Porque o risco dominante não é falta de inteligência da reframe.
- É falta de prova de que ela é mais do que uma reorganização retórica.
- E esse risco é grande demais para justificar começar §3 NEW como se a tese estivesse resolvida.
O que me faria mudar para γ.
- Horse race harmonizado mostra contraste winner-side/loser-side claro.
- Modalidades confirmam a predição institucional.
- Objeto contínuo preserva a tese loser-side sem depender do cutoff FL14.
- Tabela winner-heavy do universo CADE fica forte e limpa.
Se esses quatro blocos saírem, γ vira aposta racional.
Sem eles, γ vira consumo de tempo.
**Sobre o target exato se for direto para o journal abaixo de JLE.**
- **JLEO**.
Não RAND.
Não JLE.
Não JEEA.
Não EJ.
IJIO é o melhor plano B do plano B, mas eu não o colocaria acima de JLEO para esta versão do paper.
Razão:
- o objeto remanescente é mais law-and-economics/institutional screening do que IO com mecanismo duro;
- JLEO tolera melhor uma contribuição útil, honesta e delimitada;
- IJIO exigiria, para me convencer, mais clareza sobre mecanismo econômico e menos dependência de narrativa institucional.
Se o path-A for executado bem, eu miraria:
- **1ª opção: JLEO**
- **2ª opção, se JLEO não encaixar por escopo/editor: IJIO**
Mas o target exato, pedido por você, é:
- **JLEO**.
## Para o coautor (Claude): instruções operacionais
Vou escrever isso como lista de trabalho real.
Sem literatura ornamental.
Sem escrever seção nova antes de saber se ela sobrevive.
**Hoje**
1. Montar uma tabela única com todos os números que já viraram pivôs da narrativa.
- AUC 0,491 contra 47 réus diretos.
- AUC 0,505 contra 28 réus pós-2019.
- AUC 0,911 contra 193 cobidders.
- AUC 0,939 do `log(tenders_count)`.
- AUC 0,911 do `FL14`.
- Coeficiente conjunto `FL14 = -0,075 (p=0,05)`.
- Coeficiente conjunto `log_tc = +0,071 (p<0,001)`.
- Low HHI × Low pairs = +10,0%.
- Low HHI × High pairs = +2,7% n.s.
- High HHI × High pairs = -7,9%.
- first-time-FL bruto +0,20.
- CEM +0,10.
- PS +0,06 (p=0,31).
2. Montar uma tabela de bibliografia com status.
- Verificado.
- Parcialmente verificado.
- Placeholder.
3. Resolver a referência “Olson-Schurter 2024”.
- Encontrar referência precisa.
- Ou deletar do plano.
4. Reescrever, em um memo interno de 1 página, o claim máximo e o claim mínimo da reframe.
- Claim máximo.
- Claim mínimo.
- Claim aceitável.
5. Tomar decisão semântica preliminar sobre o objeto.
- “frequent losers”
- ou
- “loser-side concentration”.
Minha sugestão:
- usar “loser-side concentration” como conceito;
- deixar “frequent losers” como implementação.
**Esta semana**
6. Rodar o horse race harmonizado FL/contínuo/Imhof/combinado na mesma amostra.
7. Rodar o mesmo horse race contra dois rótulos.
- réus diretos;
- cobidders.
8. Gerar a tabela de composição do universo CADE.
- winners;
- losers;
- always-losers;
- cobidders;
- por modalidade, se possível.
9. Rodar AUC por modalidade.
- convite;
- pregão;
- qualquer outra quebra institucional que seja limpa.
10. Rodar sensibilidade do objeto contínuo versus binário.
11. Preparar uma tabela “predição da tese / evidência observada”.
- This is crucial.
- Sem isso, o paper continua narrando depois do fato.
12. Fazer uma nota jurídica curta com os dispositivos corretos.
- Sem tese normativa ampla.
- Só o estritamente necessário para não errar.
13. Decidir formalmente o destino do bloco first-time-FL.
- se apêndice,
- se nota curta,
- se exclusão.
Minha recomendação:
- apêndice/limitação.
14. Decidir formalmente o destino do bloco de mecanismo antigo.
- retirar qualquer linguagem de “assinatura de cartel” se o desenho unificado não sustenta.
15. Estimar, ainda que grosseiramente, o custo de dado.
- Quantos arquivos.
- Quantos campos.
- Qual preprocessing.
- Qual parte depende de reconstrução pesada.
Não precisa ser paper de data engineering.
Mas precisa virar um parágrafo sério.
**Próxima semana**
16. Reunir os resultados e aplicar uma regra de decisão binária.
- Se 4/4 testes cruciais confirmarem a tese, seguir para γ.
- Se 3/4 ou menos, abortar γ e ir para A.
Minha proposta de 4 testes cruciais:
- contraste winner/loser harmonizado;
- modalidade confirma a assimetria;
- contínuo preserva a tese loser-side;
- tabela CADE winner-heavy limpa e forte.
17. Só então escrever o esqueleto da nova introdução.
- Não antes.
18. Se γ sobreviver, escrever primeiro uma nota conceitual de 2 páginas, não a seção completa.
- Objetivo.
- Definições.
- Predições observacionais.
- Limites.
19. Circular essa nota entre coautores e alguém cético.
- O teste é simples:
- a nota soa como insight ex ante ou como defesa ex post?
20. Se soar como defesa ex post, ainda dá tempo de abortar.
21. Se A for escolhido, consolidar imediatamente o framing JLEO.
- low-cost monitoring tool;
- administrative screening;
- loser-side concentration as risk marker;
- sem ambição de mechanism identification.
22. No caminho A, limpar o texto de qualquer resquício de “cartel detector” em sentido forte.
23. No caminho γ, limpar o texto de qualquer resquício de “FL14 é a estatística fundamental”.
24. Em ambos os caminhos, remover da linha de frente:
- welfare headline;
- first-time-FL como mecanismo;
- heterogeneidade como assinatura cartelística afiada.
25. Regra editorial para Claude:
- nunca usar “proves”;
- raramente usar “detects cartelists”;
- preferir “flags”, “prioritizes”, “screens”, “concentrates risk”, “is consistent with”.
26. Regra de honestidade substantiva.
- Se o objeto real acabou virando relational-risk screen,
- escrevam isso.
- Um paper menor e coerente publica mais do que um paper maior e nervoso.
27. Regra de venue.
- Se γ sobreviver, submeter a JLE sabendo que a taxa de sobrevivência ainda é baixa.
- Se γ não sobreviver, não hesitar: JLEO.
28. Regra de ego.
- Não tentar “salvar” o v13.
- O v13 já cumpriu sua função.
- Agora a pergunta é qual paper verdadeiro os dados ainda permitem.
29. Minha frase de orientação para o coautor.
- “Teste primeiro se a assimetria winner/loser existe como fato disciplinado; só depois escreva como se ela fosse contribuição.”
30. Minha frase final, em seco.
- Se vocês precisarem da reframe para explicar por que o AUC duro é ruim, ela é defesa.
- Se a reframe gerar previsões novas que batem nos dados e organizam o conjunto inteiro dos resultados desconfortáveis, ela vira contribuição.
- Hoje, ela ainda está no meio do caminho.
