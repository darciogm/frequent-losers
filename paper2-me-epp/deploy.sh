#!/bin/bash
# Deploy paper2-me-epp MkDocs site to darciogm.github.io/research/sme-public/
# Mirrors the deploy.sh pattern of paper1-bitter-pills but targets /research/
# instead of /papers/ per the project memory (feedback_deploy_paper2).

set -e

DESTINO="../../darciogm.github.io/research/sme-public"
REPO_PESSOAL="../../darciogm.github.io"

echo "🔨 Building MkDocs..."
rm -rf site/
mkdocs build --strict

echo ""
echo "📄 Copying current manuscript PDF into site/"
if [ -f manuscript/main.pdf ]; then
  mkdir -p site/assets
  cp manuscript/main.pdf site/assets/paper.pdf
  echo "  copied main.pdf -> site/assets/paper.pdf"
fi

echo ""
echo "📦 Copiando para $DESTINO..."
mkdir -p "$DESTINO"
rsync -av --delete site/ "$DESTINO/"

echo ""
echo "🚀 Commitando no repo pessoal..."
cd "$REPO_PESSOAL"
git pull origin main --rebase --autostash
git add research/sme-public/

if git diff --staged --quiet; then
  echo "ℹ️  Nenhuma mudança detectada — site já está atualizado."
else
  git commit -m "docs(research/sme-public): update site $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "✅ Deploy concluído!"
  echo "🌐 https://darciogm.github.io/research/sme-public/"
  echo "⏱️  Aguarde ~1 minuto para o GitHub Pages atualizar."
fi
