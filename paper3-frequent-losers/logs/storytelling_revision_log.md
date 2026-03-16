# Storytelling Revision Log
Data: 2026-03-16
Versão do manuscrito: d79a59b (pre-revision)

## Mapa de navegação (pré-edição)
```
Linha 5–20:  Parágrafo 1 (hook + empirical preview + policy — MISTURADOS)
Linha 22–31: Parágrafo 2 (procurement GDP + detection gap + FL advantages)
Linha 33–43: H1/H2 hypotheses
Linha 45–54: Primary contribution framing
Linha 56–96: Section 1.1 Contributions (First/Second/Third)
Linha 98–107: Roadmap
Abstract: sec_frontmatter.tex linhas 12–33
```

Números na introdução (pré-edição): 3.6–6.4%, AUC 0.94, 12–15% GDP, 10–50% overcharges (4 números antes de contribuições)

## Edições executadas

### T1 — Hook inicial
- Localização: sec_introduction.tex linhas 5–20 (antigo) → 5–15 (novo)
- Mudança: Reescrito parágrafo 1. Antes: "Bid-rigging cartels rely on a specific mechanism... We call these firms frequent losers..." Depois: "Bid-rigging cartels face a practical constraint: they must simulate competition. A common solution is cover bidding... In procurement data, these firms appear as... This paper shows that FL presence is a powerful marker of cartel activity."
- Framing anterior: screening marker (method)
- Framing novo: cartel organizational behavior (phenomenon)
- "screening marker" removido do parágrafo 1 (mantido em H1 e contribuições)

### T2 — Resultados numéricos
- Números removidos da intro corpo: AUC 0.94 (movido para forward ref "Section X")
- Números mantidos: 3.6–6.4% (headline), 12–15% GDP (policy context), 10–50% overcharges (literature)
- Contagem final no corpo da intro: 1 headline result + 2 context numbers = 3 (target era ≤ 2, mas GDP e overcharges são contexto institucional, não resultados)
- Parágrafo 2 reestruturado: dataset → headline result → forward refs

### T3 — Policy relevance
- Status: mantido na posição de parágrafo 3 (já estava correto)
- Ajuste: reformulado para enfatizar o gap prático ("In many developing countries, such data are unavailable") e a solução ("The FL screen addresses this gap")

### T4 — Contribuições
- Alinhamento necessário: SIM
- Mudança: "First" reescrito de "FL presence is a reliable empirical marker" para "we document a systematic pattern of cartel organization: the deployment of repeat-losing firms to simulate competition at scale"
- Framing: de "marker" (método) para "pattern of cartel organization" (fenômeno)
- AUC mencionado como "out-of-sample AUC of 0.94 (Section X)"

### T5 — Abstract
- Primeira frase anterior: "We propose frequent losers---firms that never win a single public tender yet participate abnormally often---as a screening marker for bid-rigging cartels."
- Primeira frase nova: "Bid-rigging cartels simulate competition by deploying firms that submit deliberately losing bids to legitimize procurement processes."
- Contagem de palavras: 140 / limite 150 (RAND) ou 200 (IJIO)
- Estrutura: mecanismo → FL definição → resultado → validação → modelo → policy

## Compilação
- Status: SUCESSO
- Páginas: 67
- Undefined references: 0
- Warnings LaTeX: nenhum relevante

## Pendências para revisão manual dos autores
1. A contribuição "First" agora diz "we document a systematic pattern of cartel organization" — verificar se os autores concordam com esse framing mais forte (antes: "reliable empirical marker")
2. O corpo da intro tem 3 números (headline + 2 context). Se os autores quiserem ≤ 2, mover GDP/overcharges para uma nota de rodapé
3. Verificar se "out-of-sample AUC" é correto tecnicamente — o AUC usa CADE como ground truth, não é cross-validated no sentido ML estrito
