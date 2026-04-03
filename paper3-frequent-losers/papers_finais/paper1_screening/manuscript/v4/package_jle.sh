#!/bin/bash
# ============================================================================
# package_jle.sh — Create JLE submission ZIP from v4
# Run from the v4/ directory
# ============================================================================
set -e

OUTFILE="genicolomartins_azevedo_jle_2026.zip"
TMPDIR=$(mktemp -d)
PKGDIR="$TMPDIR/submission"

echo "Creating JLE submission package: $OUTFILE"
echo "================================================"

mkdir -p "$PKGDIR"/{latex/{sections,tables},replication}

# 1. Manuscript PDF
cp paper_screening_v4.pdf "$PKGDIR/manuscript.pdf"

# 2. Cover letter PDF
cp cover_letter.pdf "$PKGDIR/cover_letter.pdf"

# 3. LaTeX source
cp paper_screening_v4.tex "$PKGDIR/latex/"
cp sec_*.tex "$PKGDIR/latex/"
cp references.bib "$PKGDIR/latex/"
cp paper_screening_v4.bbl "$PKGDIR/latex/"
cp sections/*.tex "$PKGDIR/latex/sections/"
cp tables/*.tex "$PKGDIR/latex/tables/"

# 4. Checklist
cp jle_submission_checklist.md "$PKGDIR/"

# 5. Replication README (data too large for ZIP — note in README)
if [ -f ../../replication/README.md ]; then
  cp ../../replication/README.md "$PKGDIR/replication/README.md"
fi

echo "Creating ZIP..."
cd "$TMPDIR"
zip -r "$OLDPWD/$OUTFILE" submission/ > /dev/null

rm -rf "$TMPDIR"

SIZE=$(du -h "$OLDPWD/$OUTFILE" | cut -f1)
FILES=$(zipinfo -1 "$OLDPWD/$OUTFILE" | wc -l)
echo "================================================"
echo "Done: $OUTFILE ($SIZE, $FILES files)"
echo ""
echo "Contents:"
echo "  submission/manuscript.pdf          — Main manuscript"
echo "  submission/cover_letter.pdf        — Cover letter"
echo "  submission/latex/                  — LaTeX source bundle"
echo "  submission/jle_submission_checklist.md"
echo "  submission/replication/README.md   — Replication instructions"
echo ""
echo "Upload to: https://www.editorialmanager.com/jlawecon"
echo "Fee: \$100 (non-subscriber) / \$75 (subscriber)"
