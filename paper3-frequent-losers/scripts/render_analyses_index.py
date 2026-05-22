#!/usr/bin/env python3
"""Render the analyses/index.md "Generated index" section from
reference/analysis-index.yaml — replacing the placeholder
"Suggested initial AN slots" stub that the paper-site skill scaffolded.

The table lists every AN page with a clickable link, its type,
status, confidence, hypothesis it bears on, and one-line question.
"""
import re
from pathlib import Path

try:
    import yaml
except ImportError:
    import subprocess
    subprocess.run(["pip", "install", "--quiet", "pyyaml"], check=True)
    import yaml

BASE = Path("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/docs")
INDEX_MD = BASE / "analyses" / "index.md"
INDEX_YAML = BASE / "reference" / "analysis-index.yaml"

CONFIDENCE_EMOJI = {
    "green": "🟢",
    "yellow": "🟡",
    "red": "🔴",
    "pending": "—",
    None: "—",
}


def short_question(q: str, limit: int = 110) -> str:
    """Trim long question strings; keep first sentence or first `limit` chars."""
    if q is None:
        return ""
    q = q.replace("\n", " ").strip()
    if len(q) <= limit:
        return q
    return q[: limit - 1].rstrip() + "…"


def hypothesis_link(h: str | None) -> str:
    if h is None or h == "null":
        return "—"
    return f"[{h}](../hypotheses/{h}.md)"


def find_an_filename(an_id: str) -> str:
    """Find the actual filename for an-NNN — files have slugs."""
    matches = list((BASE / "analyses").glob(f"{an_id}-*.md"))
    if not matches:
        return ""
    return matches[0].name


def render_table(entries):
    lines = []
    lines.append("| AN | Type | Status | Conf. | Hypothesis | Question |")
    lines.append("|---|---|---|:-:|---|---|")
    for e in entries:
        an_id = e.get("id", "")
        fname = find_an_filename(an_id)
        if not fname:
            link = an_id.upper()
        else:
            link = f"[{an_id.upper().replace('AN-', 'AN-')}]({fname})"
        an_type = e.get("type", "—")
        status = e.get("status", "—")
        confidence = CONFIDENCE_EMOJI.get(e.get("confidence"), "—")
        hypo = hypothesis_link(e.get("hypothesis"))
        question = short_question(e.get("question"))
        lines.append(
            f"| {link} | {an_type} | {status} | {confidence} | {hypo} | {question} |"
        )
    return "\n".join(lines)


def parse_yaml(path: Path):
    """Parse the analysis-index.yaml file (which uses `- id:` blocks)."""
    text = path.read_text()
    # Strip comments and parse with pyyaml; the file is valid YAML
    entries = yaml.safe_load(text)
    # If file had no entries we get None
    return entries or []


def main():
    entries = parse_yaml(INDEX_YAML)
    print(f"Loaded {len(entries)} entries from {INDEX_YAML.name}")

    table = render_table(entries)

    # Build the new "Generated index" section
    new_section = (
        "## Generated index\n\n"
        f"All {len(entries)} AN pages, machine-generated from the YAML "
        "frontmatter of each `docs/analyses/an-NNN-*.md` file via "
        "`scripts/gen_analysis_index.py`. The same machine-readable form "
        "lives at [`docs/reference/analysis-index.yaml`](../reference/analysis-index.yaml).\n\n"
        "Sort by clicking any column header (rendered table is non-"
        "interactive; use Ctrl/Cmd+F to filter by hypothesis or type).\n\n"
        f"{table}\n\n"
        "**Status legend.** `done` = analysis run and interpretation written; "
        "`pending` = scaffolded only; `stale` = superseded.\n\n"
        "**Confidence legend.** 🟢 green (clean identification, robust); 🟡 "
        "yellow (informative with caveats); 🔴 red (kept for the record, not "
        "load-bearing).\n\n"
        "---\n"
    )

    # Replace the old "Generated index ... Suggested initial AN slots ..."
    # section with the new one. The block starts at "## Generated index"
    # and ends at the next top-level "---" + h2 OR end of file.
    text = INDEX_MD.read_text()

    pattern = re.compile(
        r"## Generated index.*?(?=^## (?!Generated)|\Z)",
        flags=re.DOTALL | re.MULTILINE,
    )

    match = pattern.search(text)
    if match is None:
        print("WARN: '## Generated index' section not found — appending instead.")
        new_text = text + "\n\n" + new_section
    else:
        new_text = text[: match.start()] + new_section + text[match.end():]

    INDEX_MD.write_text(new_text)
    print(f"Wrote {INDEX_MD}")
    print(f"  Table has {len(entries)} rows with proper links.")


if __name__ == "__main__":
    main()
