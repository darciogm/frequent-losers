#!/usr/bin/env bash
# =============================================================================
# r1_diff_classify.sh  --  benign-diff taxonomy classifier for R1-EXTENDED.
# -----------------------------------------------------------------------------
# Compares ONE current output file against its frozen baseline copy and emits a
# single verdict from the SAME taxonomy gate R1 (scripts 00+02) established:
#
#   identical          : byte-for-byte equal to baseline.
#   benign-metadata    : PDF whose pdftotext-extracted content is identical;
#                        only cairo_pdf CreationDate/ID stream bytes differ.
#   benign-tokenorder  : CSV identical after sorting the DISTINCT tokens inside
#                        the known nondeterministic column `case_ids_broad`
#                        (STRING_AGG(DISTINCT ...) with no ORDER BY).
#                        INACTIVE FOR THIS MANIFEST: no R1-EXTENDED manifest row
#                        carries the `tokenorder` hint (all rows are plain/pdf/
#                        telemetry), so this branch is never reached by the
#                        current harness. The code is retained for parity with
#                        gate R1's taxonomy and for future manifests that emit a
#                        case_ids_broad column.
#   benign-telemetry   : timestamped telemetry log (*_audit_log.txt) whose only
#                        diffs are run timestamps / RSS / a SOURCE= line.
#   new-expected       : baseline absent AND file is on the known new-file list
#                        (caller decides; this script only reports `new-baseline`
#                        when the baseline copy is missing).
#   DIFF               : genuinely different data -> FAIL.
#
# USAGE: r1_diff_classify.sh <current_file> <baseline_file> [hint]
#   hint in {pdf, telemetry, tokenorder, plain} steers which benign test runs;
#   default "plain" => only byte-equality and a generic line diff.
# Prints:  "<status>\t<note>"  on stdout. Exit 0 always (status is in stdout).
# =============================================================================
set -u

cur="${1:?current file}"
base="${2:?baseline file}"
hint="${3:-plain}"

emit() { printf '%s\t%s\n' "$1" "$2"; exit 0; }

# --- baseline missing => caller classifies as new-expected/new-baseline -------
if [[ ! -e "$base" ]]; then
  if [[ -e "$cur" ]]; then emit "new-baseline" "no baseline copy (file is new vs frozen tree)"
  else                     emit "absent-both"  "neither baseline nor current present"; fi
fi
if [[ ! -e "$cur" ]]; then
  emit "vanished" "baseline existed but current run did not write the file"
fi

# --- fast path: byte-identical ------------------------------------------------
if cmp -s "$cur" "$base"; then emit "identical" "byte-identical"; fi

# --- they differ: classify by hint -------------------------------------------
case "$hint" in
  pdf)
    if command -v pdftotext >/dev/null 2>&1; then
      ct="$(mktemp)"; bt="$(mktemp)"
      pdftotext -q "$cur"  "$ct" 2>/dev/null; rc_cur=$?
      pdftotext -q "$base" "$bt" 2>/dev/null; rc_base=$?
      # benign-metadata requires PROOF the content is genuinely identical: both
      # extractions must succeed AND at least one must yield non-empty text.
      # A failed extraction (or two empty extractions that trivially compare
      # equal) cannot prove metadata-only -> DIFF.
      if [[ "$rc_cur" -ne 0 || "$rc_base" -ne 0 ]]; then
        rm -f "$ct" "$bt"
        emit "DIFF" "PDF pdftotext extraction FAILED (cur rc=$rc_cur, base rc=$rc_base) -- cannot prove metadata-only"
      fi
      if [[ ! -s "$ct" && ! -s "$bt" ]]; then
        rm -f "$ct" "$bt"
        emit "DIFF" "PDF pdftotext extracted NO text from either file -- cannot prove metadata-only"
      fi
      if cmp -s "$ct" "$bt"; then
        rm -f "$ct" "$bt"
        emit "benign-metadata" "cairo_pdf metadata-only: pdftotext content IDENTICAL (both extractions succeeded, non-empty); byte diff in trailing stream (CreationDate/ID)"
      fi
      rm -f "$ct" "$bt"
      emit "DIFF" "PDF pdftotext content DIFFERS -- not metadata-only"
    fi
    emit "DIFF" "PDF differs and pdftotext unavailable (cannot prove metadata-only)"
    ;;

  telemetry)
    # Strip lines that legitimately change every run: timestamps, RSS, elapsed,
    # host, SOURCE= line, and any ISO date/time tokens. If the residue matches,
    # the log is benign-telemetry.
    strip='s/[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9:.]+//g; s/RSS=[0-9.]+ ?MB//g; s/[0-9.]+ ?s(ec)?\b//g'
    if diff -q \
        <(sed -E "$strip;/^SOURCE=/d;/^host=/d;/elapsed/Id;/start=/Id;/RSS=/d" "$cur") \
        <(sed -E "$strip;/^SOURCE=/d;/^host=/d;/elapsed/Id;/start=/Id;/RSS=/d" "$base") \
        >/dev/null 2>&1; then
      emit "benign-telemetry" "timestamped telemetry log: only run-clock / RSS / SOURCE= lines differ; substantive numbers identical"
    fi
    emit "DIFF" "telemetry log differs in SUBSTANTIVE lines (not just timestamps)"
    ;;

  tokenorder)
    # INACTIVE FOR THIS MANIFEST (no manifest row carries the tokenorder hint).
    # Retained for gate-R1 parity / future manifests; see header note.
    # The only sanctioned nondeterminism is intra-cell DISTINCT-token ORDER in
    # the column `case_ids_broad` (STRING_AGG DISTINCT, no ORDER BY). Compare
    # after sorting the semicolon/comma-separated tokens within that column.
    # Implementation: an awk pass that, for every cell in the case_ids_broad
    # column, splits on [;,| ] and re-emits tokens sorted. If files match after
    # this canonicalization -> benign-tokenorder, else DIFF.
    helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    canon() {  # $1 = file
      awk -F',' -v OFS=',' '
        NR==1 { for(i=1;i<=NF;i++) if($i=="case_ids_broad"||$i=="\"case_ids_broad\"") col=i; print; next }
        {
          if(col>0 && col<=NF){
            cell=$col; gsub(/^"|"$/,"",cell);
            n=split(cell, a, /[;,| ]+/);
            for(i=1;i<n;i++) for(j=i+1;j<=n;j++) if(a[i]>a[j]){t=a[i];a[i]=a[j];a[j]=t}
            s=""; for(i=1;i<=n;i++) s=s (i>1?";":"") a[i];
            $col="\"" s "\""
          }
          print
        }' "$1"
    }
    if [[ -z "$(awk -F',' 'NR==1{for(i=1;i<=NF;i++) if($i ~ /case_ids_broad/) print i}' "$cur")" ]]; then
      emit "DIFF" "differs and has no case_ids_broad column -> token-order benignity does not apply"
    fi
    if diff -q <(canon "$cur") <(canon "$base") >/dev/null 2>&1; then
      emit "benign-tokenorder" "CSV identical after sorting DISTINCT tokens within case_ids_broad (STRING_AGG nondeterminism); all other columns byte-identical"
    fi
    emit "DIFF" "CSV differs beyond case_ids_broad token order"
    ;;

  *)
    emit "DIFF" "files differ (no benign hint applies)"
    ;;
esac
