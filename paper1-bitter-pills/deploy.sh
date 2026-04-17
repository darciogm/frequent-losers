#!/bin/bash
set -e

DESTINO="../../darciogm.github.io/papers/bitter-pills"
REPO_PESSOAL="../../darciogm.github.io"

echo "🔨 Building MkDocs..."
rm -rf site/
mkdocs build --strict

echo ""
echo "📦 Copiando para $DESTINO..."
mkdir -p "$DESTINO"
rsync -av --delete site/ "$DESTINO/"

echo ""
echo "🚀 Commitando no repo pessoal..."
cd "$REPO_PESSOAL"
git pull origin main --rebase --autostash  # garante que está atualizado; autostash handles rsync changes
git add papers/bitter-pills/

if git diff --staged --quiet; then
  echo "ℹ️  Nenhuma mudança detectada — site já está atualizado."
else
  git commit -m "docs(papers/bitter-pills): update site $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "✅ Deploy concluído!"
  echo "🌐 https://darciogm.github.io/papers/bitter-pills/"
  echo "⏱️  Aguarde ~1 minuto para o GitHub Pages atualizar."
fi
