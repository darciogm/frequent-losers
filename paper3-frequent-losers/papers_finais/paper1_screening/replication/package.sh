#!/bin/bash
# ============================================================================
# package.sh — Create replication ZIP for JLE submission
# Run from the replication/ directory
# ============================================================================

set -e

OUTFILE="replication_genicolomartins_azevedo_2026.zip"

echo "Creating replication package: $OUTFILE"
echo "================================================"

# Resolve symlinks and copy to temp directory
TMPDIR=$(mktemp -d)
PKGDIR="$TMPDIR/replication"
mkdir -p "$PKGDIR"/{code,data/processed,output/{tables,figures},manuscript/{sections,tables}}

echo "Copying files (resolving symlinks)..."

# README
cp README.md "$PKGDIR/"

# Code (resolve symlinks)
for f in code/*.R; do cp -L "$f" "$PKGDIR/code/"; done

# Data (resolve symlinks — large files)
echo "  Copying data files (~480 MB)..."
for f in data/processed/*; do cp -L "$f" "$PKGDIR/data/processed/"; done

# Output
for f in output/tables/*.tex; do cp -L "$f" "$PKGDIR/output/tables/"; done
for f in output/figures/*.pdf; do [ -f "$f" ] && cp -L "$f" "$PKGDIR/output/figures/"; done

# Manuscript
for f in manuscript/*.tex manuscript/*.bib; do [ -f "$f" ] && cp -L "$f" "$PKGDIR/manuscript/"; done
for f in manuscript/sections/*.tex; do [ -f "$f" ] && cp -L "$f" "$PKGDIR/manuscript/sections/"; done
for f in manuscript/tables/*.tex; do [ -f "$f" ] && cp -L "$f" "$PKGDIR/manuscript/tables/"; done

echo "Creating ZIP..."
cd "$TMPDIR"
zip -r "$OLDPWD/$OUTFILE" replication/ -x "*.DS_Store" > /dev/null

echo "Cleaning up..."
rm -rf "$TMPDIR"

SIZE=$(du -h "$OLDPWD/$OUTFILE" | cut -f1)
echo "================================================"
echo "Done: $OUTFILE ($SIZE)"
echo "Contents: $(zipinfo -1 "$OLDPWD/$OUTFILE" | wc -l) files"
