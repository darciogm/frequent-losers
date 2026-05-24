"""Generate docs/reference/analysis-index.yaml from AN page frontmatter.

Adapted from Henrik Sigstad's paper6-procure project for use in any
bitter-pills paper site. The index is a derived artifact — each entry is
built by parsing the corresponding `docs/analyses/an-NNN-<slug>.md`
frontmatter. AN frontmatter is the source of truth; the index exists as a
single scannable summary file (used by humans browsing the analyses and
any future linting).

Vendored from `~/.claude/skills/paper-site/scripts/gen_analysis_index.py`.
Run standalone:

    python3 scripts/gen_analysis_index.py

The generator is idempotent — running it twice produces identical output.
If running it produces a non-empty `git diff` against the checked-in
index, the index had drifted (or you edited frontmatter without
regenerating).

Assumes the standard layout:
    <project_root>/
      docs/
        analyses/an-*.md
        reference/analysis-index.yaml   (written here)
      scripts/gen_analysis_index.py     (this file)

If your project uses a different layout, adjust PROJECT_ROOT below.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml  # PyYAML
except ImportError:  # pragma: no cover
    sys.stderr.write("PyYAML required (pip install pyyaml)\n")
    raise


PROJECT_ROOT = Path(__file__).resolve().parents[1]
AN_DIR = PROJECT_ROOT / "docs" / "analyses"
OUT_DIR = PROJECT_ROOT / "docs" / "reference"
OUT = OUT_DIR / "analysis-index.yaml"

HEADER = """\
# Analysis index — summary for scanning
# Full details in docs/analyses/an-NNN-<slug>.md
#
# THIS FILE IS GENERATED — do not edit by hand.
# Source of truth: YAML frontmatter on each docs/analyses/an-NNN-*.md page.
# Regenerate via `python3 scripts/gen_analysis_index.py`.
#
# Fields:
#   id:         an-NNN (sequential)
#   hypothesis: hypothesis slug or null
#   status:     pending | done | stale
#   type:       descriptive | causal | placebo | robustness
#   question:   one-line research question
#   confidence: pending | green | yellow | red
#   tags:       free-form list for filtering
#   file:       path to analysis file (relative to project root)
#   script:     path to source script (relative to project root)
#   target:     primary output path under build/

"""

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def parse_frontmatter(text: str) -> dict | None:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None
    try:
        return yaml.safe_load(m.group(1))
    except yaml.YAMLError as exc:
        sys.stderr.write(f"  WARN: YAML parse error: {exc}\n")
        return None


def _yaml_scalar(s) -> str:
    """Render a scalar with double quotes if it contains YAML-significant
    characters. Mirrors the in-tree style on hand-edited entries."""
    if s is None:
        return "null"
    s = str(s)
    needs_quote = any(c in s for c in ":#") or \
                  s.startswith(("-", "?", "!", "&", "*", "[", "{")) or \
                  s.strip() != s
    return ('"' + s.replace('"', '\\"') + '"') if needs_quote else s


def _yaml_inline_list(items) -> str:
    if not items:
        return "[]"
    parts = []
    for item in items:
        s = str(item)
        needs_quote = any(c in s for c in ":#,[]{}") or \
                      s.startswith(("-", "?", "!", "&", "*"))
        parts.append(('"' + s.replace('"', '\\"') + '"') if needs_quote else s)
    return "[" + ", ".join(parts) + "]"


def emit_entry(meta: dict) -> str:
    """Render one index entry."""
    lines = [
        f"- id: {meta['id']}",
        f"  hypothesis: {_yaml_scalar(meta.get('hypothesis'))}",
        f"  status: {meta.get('status', '')}",
        f"  type: {meta.get('type', '')}",
        f"  question: {_yaml_scalar(meta.get('question', ''))}",
        f"  confidence: {meta.get('confidence', 'pending')}",
        f"  tags: {_yaml_inline_list(meta.get('tags', []) or [])}",
        f"  file: docs/analyses/{meta['_filename']}",
        f"  script: {meta.get('script', '')}",
        f"  target: {meta.get('target', '')}",
    ]
    return "\n".join(lines)


def collect_entries() -> list[dict]:
    out = []
    if not AN_DIR.exists():
        sys.stderr.write(f"  WARN: {AN_DIR} does not exist; nothing to index\n")
        return out
    for md in sorted(AN_DIR.glob("an-*.md")):
        if md.name == "index.md":
            continue
        meta = parse_frontmatter(md.read_text())
        if not meta or "id" not in meta:
            sys.stderr.write(f"  WARN: skipping {md.name} (no frontmatter id)\n")
            continue
        meta["_filename"] = md.name
        out.append(meta)
    out.sort(key=lambda m: m["id"])
    return out


def render(entries: list[dict]) -> str:
    if not entries:
        return HEADER + "# (no AN pages yet — add docs/analyses/an-NNN-<slug>.md to populate)\n"
    return HEADER + "\n\n".join(emit_entry(m) for m in entries) + "\n"


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    entries = collect_entries()
    OUT.write_text(render(entries))
    print(f"Wrote {OUT.relative_to(PROJECT_ROOT)} ({len(entries)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
