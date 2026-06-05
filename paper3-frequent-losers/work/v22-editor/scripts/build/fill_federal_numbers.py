#!/usr/bin/env python3
"""
fill_federal_numbers.py

Mechanical fill EXTRACTOR for the ComprasNet (federal) wiring block. Eliminates
human transcription once the federal chain finishes: parses the staging draft
`docs/jleo_rr_revision/values_tex_federal_block_DRAFT.tex`, and for each TODO
macro READS the exact named output file/column under `outputs/comprasnet/`,
extracts and formats the value per house conventions, and emits a verification
report. It NEVER writes into values.tex or the DRAFT block — report only; the
human applies each value by hand with a `% src:` comment.

WHAT IT PARSES (the DRAFT line pair, per macro):
    % src: <file> :: <row/cell spec> | <metric description> [| FILLED... | TODO_NUMBER]
    \newcommand{\valFedAud...}{<value or TODO>}

The `<file> :: <spec>` part is the machine-readable locator. For wide CSV tables
(e.g. table_C: a `design`/`label` key column + metric columns), the spec is
`<row-key> <column>` (e.g. `S0_raw_score roc_auc`). For key-value diagnostic
CSVs (e.g. canonical_target_counts.csv `target,count`; phase0_*.csv
`check,result`) the spec names the row key and the script reads the value cell.
For `.tex` twins, the spec names the macro and the value is regex'd out.

STRICT FAILURE HONESTY (rule 4): a macro whose src file/column is absent or whose
row spec matches 0 or >1 rows -> status missing/ambiguous with the exact reason.
No silent guesses, no fuzzy column-name matching (exact token or fail).

OUTPUT: outputs/comprasnet/diagnostics/federal_fill_report.csv with columns:
    macro, src_file, status (found|missing|ambiguous|todo_parse_fail|filled_already),
    raw_value, formatted_value, bec_twin_value, notes

CLI:
    --dry-run   Parse the DRAFT + numbers map only; list what WOULD be extracted
                from where, WITHOUT reading any output file. Reports coverage:
                how many TODO macros have a parseable, unambiguous src spec, and
                which are unparseable (these need src-spec fixes BEFORE the chain
                finishes). Also cross-checks every referenced src file against the
                chain's artifact tables (federal_run_chain.md) and flags files the
                chain will NOT produce.

House style mirrors build_federal_price_panel.py: telemetry log, stdlib +
duckdb/pandas only (csv module suffices here; no heavy reads), deterministic.
"""
import argparse
import csv
import os
import re
import sys
import time

BASE = "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
WORK = os.path.join(BASE, "work/v22-editor")
DRAFT = os.path.join(WORK, "docs/jleo_rr_revision/values_tex_federal_block_DRAFT.tex")
NUMBERS_MAP = os.path.join(WORK, "docs/jleo_rr_revision/NEW_NUMBERS_MAP_COMPRASNET.md")
VALUES_TEX = os.path.join(WORK, "submission_clean/values.tex")
COMPRASNET = os.path.join(WORK, "outputs/comprasnet")
CHAIN_MD = os.path.join(COMPRASNET, "diagnostics/federal_run_chain.md")
REPORT = os.path.join(COMPRASNET, "diagnostics/federal_fill_report.csv")

# Macro-name substrings that classify how the raw value is formatted.
# Order matters: first match wins. (house conventions, mirrored from values.tex)
#   AUC / ROC / PR / prob -> 3-decimal float, BUT detection probabilities ->2 dec
#   p-value -> 3 dec, scientific when < 0.001
#   count -> integer with {,} thousands separator
#   share/pct/retention -> percent with one decimal + \%
#   verdict -> verbatim string (no numeric format)
NUMERIC_VERDICT = {"verdict"}


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


# --------------------------------------------------------------------------- #
# 1. DRAFT parsing
# --------------------------------------------------------------------------- #

# A `% src:` comment line immediately precedes (most) \newcommand lines.
SRC_RE = re.compile(r"^\s*%\s*src:\s*(.*)$")
NEWCMD_RE = re.compile(r"^\s*\\newcommand\{\\(?P<macro>val[A-Za-z]+)\}\{(?P<val>.*?)\}")


def parse_draft(path):
    """Return list of dicts: macro, value(raw text inside braces), src_raw (text
    after 'src:'), and parsed (file, spec, status flags). The src comment is the
    line immediately above the \\newcommand; if absent, src_raw is None.
    """
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()

    macros = []
    pending_src = None
    for ln in lines:
        m_src = SRC_RE.match(ln)
        if m_src:
            pending_src = m_src.group(1).strip()
            continue
        m_cmd = NEWCMD_RE.match(ln)
        if m_cmd:
            macro = m_cmd.group("macro")
            # strip a trailing inline %comment from the value text, e.g. {94} % [map-only]
            raw_val = m_cmd.group("val")
            macros.append({
                "macro": macro,
                "value": raw_val.strip(),
                "src_raw": pending_src,
            })
            pending_src = None
        elif ln.strip() and not ln.lstrip().startswith("%"):
            # any non-comment, non-newcommand content line resets the src binding
            pending_src = None
    return macros


# src comment grammar:  <file> :: <spec> | <metric description> [| tail...]
SRC_SPLIT_RE = re.compile(r"^(?P<file>[^:]+?)\s*::\s*(?P<rest>.*)$")


def parse_src(src_raw):
    """Parse the src comment into (file, spec, descr, tail_flags). Returns a dict
    with keys file, spec, descr, parse_ok, parse_err. spec is the row/cell
    locator (everything before the first ' | ' after '::'). Exact, no fuzzing.
    """
    out = {"file": None, "spec": None, "descr": None, "parse_ok": False, "parse_err": ""}
    if not src_raw:
        out["parse_err"] = "no `% src:` comment line precedes the \\newcommand"
        return out
    m = SRC_SPLIT_RE.match(src_raw)
    if not m:
        out["parse_err"] = "missing ' :: ' separator between file and spec"
        return out
    file_part = m.group("file").strip()
    rest = m.group("rest").strip()
    # The spec is the segment before the first ' | '. Remaining pipes are the
    # human description + tail flags (FILLED/TODO_NUMBER/[src-INFERRED]/...).
    pipe_parts = [p.strip() for p in rest.split("|")]
    spec = pipe_parts[0].strip()
    descr = pipe_parts[1].strip() if len(pipe_parts) > 1 else ""
    if not file_part:
        out["parse_err"] = "empty file path before ' :: '"
        return out
    if not spec:
        out["parse_err"] = "empty row/cell spec after ' :: '"
        return out
    out["file"] = file_part
    out["spec"] = spec
    out["descr"] = descr
    out["parse_ok"] = True
    return out


# --------------------------------------------------------------------------- #
# 2. BEC twin values from the numbers map (for instant delta reading)
# --------------------------------------------------------------------------- #

def parse_bec_twins(map_path):
    """Map federal \\valFedAud* / \\valFed* macro -> BEC twin value, by scanning the
    markdown rows. Each table row that ends in a `\\valFed...` macro cell carries
    the BEC value in its second column. Best-effort; report-only convenience.
    """
    twins = {}
    if not os.path.exists(map_path):
        return twins
    cell_macro_re = re.compile(r"\\(valFed[A-Za-z]+)")
    with open(map_path, encoding="utf-8") as fh:
        for ln in fh:
            if "|" not in ln:
                continue
            macs = cell_macro_re.findall(ln)
            if not macs:
                continue
            cells = [c.strip() for c in ln.strip().strip("|").split("|")]
            if len(cells) < 2:
                continue
            bec_val = cells[1]
            # the federal macro this row defines = last \valFed... on the line
            macro = macs[-1]
            # clean BEC value: keep first compact token-ish (e.g. **651**, 0.761, 32.0%)
            bec_clean = bec_val.replace("**", "").strip()
            twins.setdefault(macro, bec_clean)
    return twins


# --------------------------------------------------------------------------- #
# 3. Value extraction from output files (non-dry-run)
# --------------------------------------------------------------------------- #

def _read_csv_rows(path):
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.reader(fh)
        rows = list(reader)
    return rows


def extract_from_csv(abspath, spec):
    """Locate a value in a CSV given a `<row-key> <column>` or `<row-key>` spec.

    Two CSV shapes are supported, decided by header inspection:
      (W) WIDE keyed table: a leading key column ('design','label','target',
          'check','scenario','granularity','design'...) + named metric columns.
          spec = '<row-key-token> <column-name>'. The column name must be the
          LAST whitespace token of spec and must exactly match a header cell; the
          remaining leading tokens form the row-key, matched exactly against the
          first column (or, if not unique there, against any of the first two
          'key' columns). Exact match; 0 rows -> missing; >1 -> ambiguous.
      (KV) key-value diagnostic table ('target,count', 'check,result'): spec is
          the row key alone; value = the 2nd column of the matched row.

    Returns (status, raw_value, note).
    """
    if not os.path.exists(abspath):
        return ("missing", "", f"file not found: {abspath}")
    rows = _read_csv_rows(abspath)
    if not rows:
        return ("missing", "", "file is empty")
    header = [h.strip() for h in rows[0]]
    data = rows[1:]

    tokens = spec.split()
    # ---- decide shape: is the last token an exact header column name? ----
    last_tok = tokens[-1] if tokens else ""
    col_idx = None
    if last_tok in header:
        col_idx = header.index(last_tok)
        row_key = " ".join(tokens[:-1]).strip()
    else:
        row_key = spec.strip()

    # candidate key columns: any header named like a key, else col 0
    KEY_HEADERS = {"design", "label", "target", "check", "scenario",
                   "granularity", "metric", "name", "key", "row", "case"}
    key_cols = [i for i, h in enumerate(header) if h.lower() in KEY_HEADERS]
    if not key_cols:
        key_cols = [0]

    if col_idx is not None:
        # WIDE: match row_key against key columns, read col_idx
        matches = []
        for r in data:
            for kc in key_cols:
                if kc < len(r) and r[kc].strip() == row_key:
                    matches.append(r)
                    break
        if len(matches) == 0:
            avail = sorted({r[key_cols[0]].strip() for r in data
                            if key_cols[0] < len(r)})[:20]
            return ("missing",
                    "",
                    f"row-key '{row_key}' not found in key column(s) "
                    f"{[header[i] for i in key_cols]}; available keys: {avail}")
        if len(matches) > 1:
            return ("ambiguous",
                    "",
                    f"row-key '{row_key}' matched {len(matches)} rows; spec must be unique")
        val = matches[0][col_idx].strip() if col_idx < len(matches[0]) else ""
        if val == "":
            return ("missing",
                    "",
                    f"cell ['{row_key}','{last_tok}'] is empty")
        return ("found", val, f"WIDE: col '{last_tok}' @ row '{row_key}'")
    else:
        # KV: spec is a row key; value is 2nd column
        if len(header) < 2:
            return ("ambiguous", "",
                    f"KV read needs >=2 columns; header={header}; and last token "
                    f"'{last_tok}' is not a known column name")
        matches = [r for r in data if r and r[0].strip() == row_key]
        if len(matches) == 0:
            avail = sorted({r[0].strip() for r in data if r})[:20]
            return ("missing", "",
                    f"row key '{row_key}' not found in column '{header[0]}'; "
                    f"available keys: {avail}; header columns: {header}")
        if len(matches) > 1:
            return ("ambiguous", "",
                    f"row key '{row_key}' matched {len(matches)} rows")
        val = matches[0][1].strip()
        if val == "":
            return ("missing", "", f"value cell for '{row_key}' is empty")
        return ("found", val, f"KV: value of '{row_key}' (col '{header[1]}')")


def extract_from_tex(abspath, spec):
    """Read a macro twin from a .tex file. spec should name the macro (with or
    without leading backslash); fall back to the macro defined on the draft line.
    """
    if not os.path.exists(abspath):
        return ("missing", "", f"file not found: {abspath}")
    tok = spec.split()[0].lstrip("\\")
    pat = re.compile(r"\\newcommand\{\\" + re.escape(tok) + r"\}\{(.*?)\}")
    with open(abspath, encoding="utf-8") as fh:
        text = fh.read()
    found = pat.findall(text)
    if len(found) == 0:
        return ("missing", "", f"macro \\{tok} not found in {os.path.basename(abspath)}")
    if len(found) > 1:
        return ("ambiguous", "", f"macro \\{tok} defined {len(found)} times")
    return ("found", found[0].strip(), f"TEX twin \\{tok}")


def extract(parsed):
    """Dispatch to CSV / TEX extractor based on file extension."""
    rel = parsed["file"]
    abspath = rel if os.path.isabs(rel) else os.path.join(WORK, rel)
    spec = parsed["spec"]
    if abspath.endswith(".tex"):
        return extract_from_tex(abspath, spec)
    # row-count specs ("... :: row count") are a whole-file metric, not a cell —
    # handle BEFORE the keyed-CSV path so 'row count' is not read as a row key.
    if "row count" in spec.lower():
        if not os.path.exists(abspath):
            return ("missing", "", f"file not found: {abspath}")
        with open(abspath, newline="", encoding="utf-8") as fh:
            n = sum(1 for _ in fh) - 1  # minus header
        return ("found", str(max(n, 0)), "row count (data rows, header excluded)")
    if abspath.endswith(".csv"):
        return extract_from_csv(abspath, spec)
    return ("ambiguous", "", f"unsupported file type for extraction: {abspath}")


# --------------------------------------------------------------------------- #
# 4. House-style formatting
# --------------------------------------------------------------------------- #

def _is_floatish(s):
    try:
        float(s)
        return True
    except (TypeError, ValueError):
        return False


def thousands(n):
    return "{:,}".format(int(round(float(n)))).replace(",", "{,}")


def format_value(macro, raw, descr=""):
    """Format raw extracted value to match values.tex conventions. Returns
    (formatted, fmt_note). Non-numeric (verdict strings) pass through verbatim.
    """
    if raw is None or raw == "":
        return ("", "empty")
    name = macro.lower()
    descr_l = (descr or "").lower()

    # verdict / string macros -> verbatim
    if "verdict" in name:
        return (raw, "verbatim verdict string")

    # already-percent literal (e.g. '99.5%' or '32.0%')
    pct_literal = raw.strip().endswith("%")
    val_str = raw.strip().rstrip("%")

    if not _is_floatish(val_str):
        # textual value that is not a verdict and not numeric -> pass through, flag
        return (raw, "non-numeric value passed through verbatim (CHECK)")

    val = float(val_str)

    # ---- counts: macros that are integer tallies ----
    count_keys = ("cobidders", "legaldef", "fedactivedef", "consbroadal",
                  "consfeddef", "compfl", "compnonfl", "defitems", "cases",
                  "conscases", "conscobidders", "directsn", "alwayslosers",
                  "firms", "flcount", "flthreshold", "frozenpool", "rawn",
                  "exposedn", "frozenprospn", "panelrows")
    is_count = any(k in name for k in count_keys)
    # but threshold(=32) and counts that are clearly integral
    if is_count and float(val).is_integer() and not pct_literal:
        iv = int(val)
        if iv >= 1000:
            return (thousands(iv), "count with {,} thousands separator")
        return (str(iv), "integer count")

    # ---- percentages / shares / retention ----
    share_keys = ("share", "retention", "sparseshare", "pct", "winshare",
                  "topcase", "pbarrange")
    if pct_literal or any(k in name for k in share_keys) or "%" in descr_l:
        # value may be a fraction (0.32) or already a percent number (32.0)
        if not pct_literal and abs(val) <= 1.0 and "topcase" in name:
            val = val * 100.0
        return (f"{val:.1f}\\%", "percent, 1 decimal, escaped %")

    # ---- detection probabilities (power curve): 2 decimals like \valArmorPower* ----
    if "power" in name or "oicontrol" in name:
        return (f"{val:.2f}", "probability, 2 decimals")

    # ---- p-values: 3 dec, scientific when < 0.001 ----
    is_p = name.endswith("p") or name.endswith("cp") or name.endswith("covp") \
        or "delongp" in name or name.endswith("nestedp") or "_p" in descr_l \
        or descr_l.strip().endswith(" p") or "p_pr" in descr_l or "p-value" in descr_l
    if is_p:
        if 0 < abs(val) < 0.001:
            return (f"{val:.1e}", "p-value, scientific (<0.001)")
        return (f"{val:.3f}", "p-value, 3 decimals")

    # ---- AUC / ROC / PR / increment / benchmark E -> 3 decimals ----
    auc_keys = ("auc", "roc", "pr", "increment", "exploo", "explb",
                "labelblind", "withincoarse", "withinmedium", "withinstrict",
                "exponly", "raw", "nested", "boundary", "placebo", "hvwinner",
                "strictfull", "strictcont", "strictfl", "frozenprosp",
                "frozenretro", "rollworst", "locofull", "locodroplargest",
                "locodroptwo", "breadth", "combined", "oicontrol", "withinfl",
                "within", "tp")
    if any(k in name for k in auc_keys):
        # increments may be signed and small; keep sign
        if "increment" in name and val >= 0:
            return (f"+{val:.3f}", "signed increment, 3 decimals")
        return (f"{val:.3f}", "AUC/ratio, 3 decimals")

    # default numeric: 3 decimals
    return (f"{val:.3f}", "default numeric, 3 decimals (CHECK macro class)")


# --------------------------------------------------------------------------- #
# 5. Chain artifact cross-check (dry-run): which referenced files will the
#    chain produce? Parse federal_run_chain.md producer DAG + table rows.
# --------------------------------------------------------------------------- #

# The chain runbook (federal_run_chain.md) names most outputs by SHORTHAND
# ("tables G/H", "audit_armor/{granularity_sweep,...}", "rolling-origin") rather
# than exact filenames, so an exact-basename match over the .md gives false
# positives. These regexes encode the producer DAG's shorthand: a basename
# matching ANY of them is a planned chain output (script 03/04/06/12/12b), even
# if not yet on disk. Anything matching NONE is a GENUINE spec bug (no producer).
CHAIN_OUTPUT_PATTERNS = [
    r"^defendant_roles\.csv$",  # produced by 12/12b (runbook glob shorthand missed it)
    r"^canonical_cobidders_broad\.csv$",          # 00
    r"^canonical_target_counts\.csv$",            # 00
    r"^canonical_(firm|case)_labels\.csv$",       # 00
    r"^table_[A-H]_.*\.(csv|tex)$",               # 01-06 table families (incl appendix/)
    r"^table_D_strict_\d{4}_\d{4}_to_\d{4}_\d{4}\.csv$",   # 03 timing strict
    r"^table_[DE]_rolling_origin.*\.csv$",        # 03 rolling-origin
    r"^table_[GH]_.*\.csv$",                       # 04 LOCO / dominance
    r"^table_D_clustered_randomization_inference\.csv$",   # 04 -> tables/appendix/
    r"^table_E_negative_controls\.csv$",          # 06 negative controls
    r"^granularity_sweep\.csv$",                   # 12/12b audit_armor
    r"^permutation_power_curve\.csv$",             # 12b audit_armor
    r"^frozen_timing\.csv$",                        # 12/12b audit_armor
    r"^audit_armor_macros\.tex$",                  # 12b audit_armor
    r"^leakage_check_cell_level\.csv$",            # 12 audit_armor
]
_CHAIN_RES = [re.compile(p) for p in CHAIN_OUTPUT_PATTERNS]


def chain_will_produce(basename, on_disk):
    """True iff the federal chain (per federal_run_chain.md producer DAG) will
    write this basename — either it is already on disk, or it matches one of the
    known producer-output patterns. False => genuine spec bug (no producer)."""
    if on_disk:
        return True
    return any(rx.match(basename) for rx in _CHAIN_RES)


def files_on_disk():
    seen = set()
    for _root, _dirs, files in os.walk(COMPRASNET):
        for f in files:
            seen.add(f)
    return seen


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true",
                    help="parse only; list what WOULD be extracted, no file reads")
    args = ap.parse_args()

    t0 = time.time()
    log(f"host={os.uname().nodename} cwd={os.getcwd()}")
    log(f"DRAFT  = {DRAFT}")
    log(f"MAP    = {NUMBERS_MAP}")
    log(f"OUTDIR = {COMPRASNET}")
    log(f"mode   = {'DRY-RUN (no output-file reads)' if args.dry_run else 'EXTRACT'}")

    for p in (DRAFT,):
        if not os.path.exists(p):
            log(f"FATAL: required input missing: {p}")
            sys.exit(2)

    macros = parse_draft(DRAFT)
    bec_twins = parse_bec_twins(NUMBERS_MAP)
    log(f"parsed {len(macros)} \\newcommand macros from DRAFT; "
        f"{len(bec_twins)} BEC twins from map")

    # classify each macro
    todo = []
    filled = []
    for m in macros:
        v = m["value"].strip()
        is_todo = (v.upper() == "TODO")
        m["is_todo"] = is_todo
        m["parsed"] = parse_src(m["src_raw"])
        (filled, todo)[is_todo].append(m)
    log(f"FILLED already: {len(filled)}  |  TODO: {len(todo)}")

    # ---- dry-run coverage on TODO macros ----
    parseable = [m for m in todo if m["parsed"]["parse_ok"]]
    unparseable = [m for m in todo if not m["parsed"]["parse_ok"]]

    on_disk = files_on_disk()
    # files referenced by parseable TODO specs that the chain won't produce
    # (genuine spec bugs) vs. planned-but-not-yet-on-disk (benign).
    spec_bugs = []          # (macro, file) — no producer anywhere
    pending_planned = []    # (macro, file) — chain will write it, not yet on disk
    seen_files = set()
    for m in parseable:
        f = m["parsed"]["file"]
        base = os.path.basename(f)
        disk = base in on_disk
        if not chain_will_produce(base, disk):
            spec_bugs.append((m["macro"], f))
        elif not disk:
            if base not in seen_files:
                pending_planned.append((m["macro"], f))
        seen_files.add(base)
    not_produced = spec_bugs  # kept for downstream report naming

    if args.dry_run:
        log("=" * 72)
        log("DRY-RUN COVERAGE")
        log(f"  TODO macros total      : {len(todo)}")
        log(f"  parseable src spec     : {len(parseable)}")
        log(f"  UNPARSEABLE src spec   : {len(unparseable)}")
        if unparseable:
            log("  -- unparseable list (fix the src spec in the DRAFT block) --")
            for m in unparseable:
                log(f"     \\{m['macro']:32s} : {m['parsed']['parse_err']}")
                log(f"        raw src: {m['src_raw']!r}")
        log("-" * 72)
        log(f"  GENUINE SPEC BUGS — src file has NO producer in the chain "
            f"(cross-check vs federal_run_chain.md producer DAG): {len(spec_bugs)}")
        for macro, f in spec_bugs:
            log(f"     \\{macro:32s} -> {f}  [FIX THE SRC SPEC]")
        log("-" * 72)
        log(f"  planned chain outputs not yet on disk (benign; chain still "
            f"running): {len(pending_planned)} distinct files")
        for macro, f in pending_planned:
            log(f"     {os.path.basename(f):54s} (first ref: \\{macro})")
        # also: list, per parseable macro, the planned extraction
        log("-" * 72)
        log("  PLANNED EXTRACTIONS (parseable TODO macros):")
        for m in parseable:
            pr = m["parsed"]
            on_disk = os.path.exists(os.path.join(WORK, pr["file"]))
            flag = "" if on_disk else "  [file not yet on disk]"
            log(f"     \\{m['macro']:30s} <= {pr['file']} :: {pr['spec']}{flag}")
        log("=" * 72)
        log(f"done (dry-run) in {time.time()-t0:.1f}s — NO files read, NO report written")
        return

    # ---- EXTRACT mode: read each parseable TODO macro's source ----
    rows_out = []
    n_found = n_missing = n_amb = 0
    for m in macros:
        macro = m["macro"]
        bec = bec_twins.get(macro, "")
        if m["is_todo"]:
            pr = m["parsed"]
            if not pr["parse_ok"]:
                rows_out.append([macro, pr.get("file") or "",
                                 "todo_parse_fail", "", "", bec,
                                 pr["parse_err"]])
                n_missing += 1
                continue
            status, raw, note = extract(pr)
            if status == "found":
                fmt, fmt_note = format_value(macro, raw, pr["descr"])
                rows_out.append([macro, pr["file"], "found", raw, fmt, bec,
                                 f"{note}; fmt: {fmt_note}"])
                n_found += 1
            else:
                rows_out.append([macro, pr["file"], status, raw, "", bec, note])
                if status == "ambiguous":
                    n_amb += 1
                else:
                    n_missing += 1
        else:
            # already-FILLED macros: record the bound value for delta reading
            pr = m["parsed"]
            rows_out.append([macro, (pr.get("file") or ""), "filled_already",
                             m["value"], m["value"], bec,
                             "value already bound in DRAFT (verify on integration)"])

    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["macro", "src_file", "status", "raw_value",
                    "formatted_value", "bec_twin_value", "notes"])
        w.writerows(rows_out)

    log("=" * 72)
    log(f"EXTRACT complete: found={n_found} missing={n_missing} "
        f"ambiguous={n_amb} filled_already={len(filled)}")
    log(f"report written: {REPORT}")
    log(f"done in {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
