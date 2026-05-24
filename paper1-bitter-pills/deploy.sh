#!/bin/bash
# Deploy the Bitter Pills v9 site to its canonical home:
#   https://darciogm.github.io/research/bitter-pills/
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

echo "Refreshing v9 PDFs into docs/assets/pdf ..."
mkdir -p docs/assets/pdf
cp v9-jpube-short/manuscript/paper/main.pdf          docs/assets/pdf/sourcing-under-sanctions-v9.pdf
cp v9-jpube-short/manuscript/paper/OnlineAppendix.pdf docs/assets/pdf/sourcing-under-sanctions-v9-online-appendix.pdf

echo "Verifying the standalone site builds (mkdocs --strict) ..."
rm -rf site/
mkdocs build --strict

echo ""
echo "Syncing docs/ into $DEST ..."
mkdir -p "$DEST"
rsync -a --delete docs/ "$DEST/"

echo ""
echo "Committing on personal repo (GitHub Action rebuilds the site) ..."
cd "$REPO_PESSOAL"
git pull origin main --rebase --autostash
git add docs/research/bitter-pills/

if git diff --staged --quiet; then
  echo "Nenhuma mudanca detectada; site ja esta atualizado."
else
  git commit -m "research/bitter-pills: refresh v9 site $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "Deploy enviado. Action 'Deploy MkDocs' vai rebuildar o site."
  echo "https://darciogm.github.io/research/bitter-pills/"
  echo "Aguarde ~1m20s + cache do Pages."
fi
