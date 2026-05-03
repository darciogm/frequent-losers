#!/bin/bash
# Sync the latest paper2-me-epp PDFs into the personal site's MkDocs source.
# The personal site (darciogm.github.io) builds via a GitHub Action from docs/,
# so files must land in docs/research/sme-public/assets/ — anything outside
# docs/ is ignored by the Action.
#
# Source of truth for v6: v6-jpube/manuscript/{paper_v6,online_appendix,highlights}.pdf
# Live URLs preserved: assets/sme_public_procurement.pdf,
#                      assets/sme_public_online_appendix.pdf,
#                      assets/sme_public_highlights.pdf

set -e

SRC_DIR="v6-jpube/manuscript"
DEST_DIR="../../darciogm.github.io/docs/research/sme-public/assets"
REPO_PESSOAL="../../darciogm.github.io"

if [ ! -d "$DEST_DIR" ]; then
  echo "❌ Destination not found: $DEST_DIR"
  echo "   Make sure darciogm.github.io is cloned at ../../darciogm.github.io"
  exit 1
fi

for f in paper_v6.pdf online_appendix.pdf highlights.pdf; do
  if [ ! -f "$SRC_DIR/$f" ]; then
    echo "❌ Missing source: $SRC_DIR/$f"
    exit 1
  fi
done

echo "📄 Copying v6 PDFs into $DEST_DIR ..."
cp "$SRC_DIR/paper_v6.pdf"        "$DEST_DIR/sme_public_procurement.pdf"
cp "$SRC_DIR/online_appendix.pdf" "$DEST_DIR/sme_public_online_appendix.pdf"
cp "$SRC_DIR/highlights.pdf"      "$DEST_DIR/sme_public_highlights.pdf"

echo ""
echo "🚀 Commitando no repo pessoal..."
cd "$REPO_PESSOAL"
git pull origin main --rebase --autostash
git add docs/research/sme-public/assets/sme_public_procurement.pdf \
        docs/research/sme-public/assets/sme_public_online_appendix.pdf \
        docs/research/sme-public/assets/sme_public_highlights.pdf

if git diff --staged --quiet; then
  echo "ℹ️  Nenhuma mudança detectada — site já está atualizado."
else
  git commit -m "sme-public: refresh paper PDFs $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "✅ Push enviado. Action 'Deploy MkDocs' vai rebuildar o site."
  echo "🌐 https://darciogm.github.io/research/sme-public/"
  echo "⏱️  Aguarde ~1m20s + cache do Pages."
fi
