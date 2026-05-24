#!/bin/bash
set -e

DESTINO="../../darciogm.github.io/papers/bitter-pills"
REPO_PESSOAL="../../darciogm.github.io"

echo "Syncing v9 PDFs into docs..."
mkdir -p docs/assets/pdf
cp v9-jpube-short/manuscript/paper/main.pdf docs/assets/pdf/sourcing-under-sanctions-v9.pdf
cp v9-jpube-short/manuscript/paper/OnlineAppendix.pdf docs/assets/pdf/sourcing-under-sanctions-v9-online-appendix.pdf

echo "Building MkDocs..."
rm -rf site/
mkdocs build --strict

echo ""
echo "Copiando para $DESTINO..."
mkdir -p "$DESTINO"
rsync -av --delete site/ "$DESTINO/"

echo ""
echo "Commitando no repo pessoal..."
cd "$REPO_PESSOAL"
git pull origin main --rebase --autostash
git add papers/bitter-pills/

if git diff --staged --quiet; then
  echo "Nenhuma mudanca detectada; site ja esta atualizado."
else
  git commit -m "docs(papers/bitter-pills): update site $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "Deploy concluido."
  echo "https://darciogm.github.io/papers/bitter-pills/"
  echo "Aguarde ~1 minuto para o GitHub Pages atualizar."
fi
