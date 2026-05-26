#!/bin/bash
# Deploy the Bitter Pills v10 site to its canonical home:
#   https://darciogm.github.io/research/bitter-pills/
# and refresh the working-papers listing:
#   https://darciogm.github.io/research/working-papers/
#
# The personal site (darciogm.github.io) builds via a GitHub Action from docs/,
# so the paper's markdown + assets must land in docs/research/bitter-pills/.
# (The old /papers/bitter-pills/ path is retired and now 301-style redirects
#  to /research/bitter-pills/ via docs/papers/bitter-pills/index.html.)

set -e

DEST="../../darciogm.github.io/docs/research/bitter-pills"
REPO_PESSOAL="../../darciogm.github.io"

if [ ! -d "$REPO_PESSOAL/docs/research" ]; then
  echo "❌ Personal site research dir not found at $REPO_PESSOAL/docs/research"
  echo "   Make sure darciogm.github.io is cloned at ../../darciogm.github.io"
  exit 1
fi

echo "Refreshing v10 PDFs into docs/assets/pdf ..."
mkdir -p docs/assets/pdf
cp v10-causal-mechanism/manuscript/paper/main.pdf          docs/assets/pdf/sourcing-under-sanctions-v10.pdf
cp v10-causal-mechanism/manuscript/paper/OnlineAppendix.pdf docs/assets/pdf/sourcing-under-sanctions-v10-online-appendix.pdf

echo "Verifying the standalone site builds (mkdocs --strict) ..."
rm -rf site/
mkdocs build --strict

echo ""
echo "Syncing docs/ into $DEST ..."
mkdir -p "$DEST"
rsync -a --delete docs/ "$DEST/"

echo ""
echo "Refreshing research/working-papers links for Bitter Pills v10 ..."
perl -pi -e 's/sourcing-under-sanctions-v9-online-appendix\.pdf/sourcing-under-sanctions-v10-online-appendix.pdf/g; s/sourcing-under-sanctions-v9\.pdf/sourcing-under-sanctions-v10.pdf/g; s/updated May, 2026 — v9/updated May, 2026 — v10/g' "$REPO_PESSOAL/docs/research/working-papers.md"
python3 - <<'PY'
from pathlib import Path

p = Path("../../darciogm.github.io/docs/research/working-papers.md")
s = p.read_text()
start = s.index('??? abstract "Abstract"\n', s.index("Sourcing under Sanctions"))
end = s.index('\n??? note "Media coverage"', start)
abstract = '''??? abstract "Abstract"
    Court mandates secure access to medicines, but they can also change how governments buy. We study São Paulo pharmaceutical procurement on BEC, covering 479,330 purchase-offer-item observations from 2009--2019. Higher prices under legal urgency can reflect two very different margins: incumbent suppliers charging more to sanctioned buyers, or fragmented sourcing that changes scale and supplier matching. Because court orders originate outside procurement offices, we interpret ordinary-versus-urgent estimates as the procurement effect of externally imposed legal urgency, conditional on item, time, and purchasing-unit fixed effects. A selected administrative urgent channel provides the closest feasible comparison without court sanctions; Lee bounds place the litigated-over-administrative price gap between 15.9% and 21.1%. The cost margin is not mainly a broad same-firm markup in deep repeated urgent markets: within the same firm, buyer, and item, prices are statistically indistinguishable across urgent regimes. Instead, judicial urgency operates through sourcing. Administrative orders are 3.3 times larger, and modal winners differ in 70.2% of item-buyer pairs. A residual within-firm price gap persists in thinner or earlier markets. The policy margin is not weaker access, but procurement capacity that preserves aggregation and supplier matching under legal urgency.
'''
p.write_text(s[:start] + abstract + s[end:])
PY

echo ""
echo "Committing on personal repo (GitHub Action rebuilds the site) ..."
cd "$REPO_PESSOAL"
git pull origin main --rebase --autostash
git add docs/research/bitter-pills/ docs/research/working-papers.md

if git diff --staged --quiet; then
  echo "Nenhuma mudanca detectada; site ja esta atualizado."
else
  git commit -m "research/bitter-pills: refresh v10 site $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "Deploy enviado. Action 'Deploy MkDocs' vai rebuildar o site."
  echo "https://darciogm.github.io/research/bitter-pills/"
  echo "https://darciogm.github.io/research/working-papers/"
  echo "Aguarde ~1m20s + cache do Pages."
fi
