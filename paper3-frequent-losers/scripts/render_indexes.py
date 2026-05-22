#!/usr/bin/env python3
"""Render the "Generated index" section in analyses/, hypotheses/, and
findings/ index.md files. Reads each page's frontmatter (and body when
needed) to produce a consistent linked table at the bottom of each
index. Idempotent: replaces the existing "## Generated index" block
each run.
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

CONFIDENCE_EMOJI = {
    "green": "🟢",
    "yellow": "🟡",
    "red": "🔴",
    "pending": "—",
    None: "—",
}

# Map hypothesis frontmatter `status` to display
H_STATUS_DISPLAY = {
    "pending": "Not yet tested",
    "partial": "Partial",
    "partial (strongly supported)": "Partial (strongly supported)",
    "mixed": "Mixed",
    "confirmed": "Confirmed",
}


def parse_frontmatter(file: Path) -> dict:
    """Return YAML frontmatter as a dict (or empty if absent)."""
    text = file.read_text()
    m = re.match(r"^---\n(.*?)\n---\n", text, flags=re.DOTALL)
    if not m:
        return {}
    try:
        return yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return {}


def short(text: str, limit: int = 110) -> str:
    if not text:
        return ""
    text = text.replace("\n", " ").strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def replace_generated_index(file: Path, new_section: str):
    text = file.read_text()
    pattern = re.compile(
        r"## Generated index.*?(?=^## (?!Generated)|\Z)",
        flags=re.DOTALL | re.MULTILINE,
    )
    if pattern.search(text):
        new_text = pattern.sub(new_section, text, count=1)
    else:
        new_text = text.rstrip() + "\n\n" + new_section
    file.write_text(new_text)


# ─── Analyses ───────────────────────────────────────────────────────────
def render_analyses():
    yaml_file = BASE / "reference" / "analysis-index.yaml"
    entries = yaml.safe_load(yaml_file.read_text()) or []

    def find_an_filename(an_id: str) -> str:
        ms = list((BASE / "analyses").glob(f"{an_id}-*.md"))
        return ms[0].name if ms else ""

    rows = []
    for e in entries:
        an_id = e.get("id", "")
        fname = find_an_filename(an_id)
        link = f"[{an_id.upper()}]({fname})" if fname else an_id.upper()
        h = e.get("hypothesis")
        hyp = f"[{h}](../hypotheses/{h}.md)" if h else "—"
        rows.append(
            f"| {link} | {e.get('type', '—')} | {e.get('status', '—')} | "
            f"{CONFIDENCE_EMOJI.get(e.get('confidence'), '—')} | {hyp} | "
            f"{short(e.get('question'))} |"
        )

    section = (
        "## Generated index\n\n"
        f"All {len(entries)} AN pages, auto-generated from the YAML "
        "frontmatter of each `docs/analyses/an-NNN-*.md` via "
        "`scripts/gen_analysis_index.py` + `scripts/render_indexes.py`. The "
        "machine-readable form lives at "
        "[`docs/reference/analysis-index.yaml`](../reference/analysis-index.yaml).\n\n"
        "| AN | Type | Status | Conf. | Hypothesis | Question |\n"
        "|---|---|---|:-:|---|---|\n"
        + "\n".join(rows)
        + "\n\n"
        "**Status legend.** `done` = analysis run and interpretation written; "
        "`pending` = scaffolded only; `stale` = superseded.\n\n"
        "**Confidence legend.** 🟢 green (clean identification, robust); 🟡 "
        "yellow (informative with caveats); 🔴 red (kept for the record, not "
        "load-bearing).\n"
    )
    replace_generated_index(BASE / "analyses" / "index.md", section)
    print(f"  analyses/index.md updated ({len(entries)} rows)")


# ─── Hypotheses ─────────────────────────────────────────────────────────
def render_hypotheses():
    files = sorted(
        f for f in (BASE / "hypotheses").glob("*.md") if f.name != "index.md"
    )
    entries = []
    for f in files:
        fm = parse_frontmatter(f)
        entries.append(
            {
                "slug": f.stem,
                "id": fm.get("id", "").upper(),
                "title": fm.get("title", ""),
                "cluster": fm.get("cluster", "—"),
                "paper_section": fm.get("paper_section", "—"),
                "status": fm.get("status", "—"),
                "filename": f.name,
            }
        )
    # Sort by id (H1, H2, ...)
    entries.sort(key=lambda e: e["id"])

    rows = []
    for e in entries:
        link = f"[{e['id']}]({e['filename']})"
        status = e.get("status", "")
        status_display = H_STATUS_DISPLAY.get(status.lower(), status.title())
        rows.append(
            f"| {link} | {e['cluster']} | {e['paper_section']} | "
            f"**{status_display}** | [{e['slug']}]({e['filename']}) — "
            f"{short(e['title'])} |"
        )

    section = (
        "## Generated index\n\n"
        f"All {len(entries)} hypothesis pages, auto-generated from the YAML "
        "frontmatter of each `docs/hypotheses/<slug>.md` via "
        "`scripts/render_indexes.py`. Maintained in lockstep with the "
        "scorecard above.\n\n"
        "| H# | Cluster | Paper section | Status | Slug + title |\n"
        "|---|:-:|:-:|---|---|\n"
        + "\n".join(rows)
        + "\n\n"
        "**Status legend.** `Not yet tested` → `Not confirmed` / `Mixed` / "
        "`Partial` → `Partial (strongly supported)` → `Confirmed`. Promotion "
        "to `Confirmed` requires non-BEC replication; see "
        "[`COMPRASNET_PATH_TO_CONFIRMED.md`](https://github.com/darciogm/bitter-pills/blob/main/paper3-frequent-losers/COMPRASNET_PATH_TO_CONFIRMED.md).\n"
    )
    replace_generated_index(BASE / "hypotheses" / "index.md", section)
    print(f"  hypotheses/index.md updated ({len(entries)} rows)")


# ─── Findings ───────────────────────────────────────────────────────────
def extract_finding_metadata(file: Path) -> dict:
    """Parse a finding page body: extract title (h1), confidence emoji,
    and short summary (first paragraph after the H1)."""
    text = file.read_text()
    # Strip frontmatter
    body = re.sub(r"^---\n.*?\n---\n", "", text, flags=re.DOTALL)
    # H1
    m_title = re.search(r"^# (.+)$", body, flags=re.MULTILINE)
    title = m_title.group(1).strip() if m_title else file.stem
    # First confidence emoji (🟢/🟡/🔴) in body
    m_conf = re.search(r"(🟢|🟡|🔴)", body)
    conf = m_conf.group(1) if m_conf else "—"
    # First non-empty line after the H1 (skipping admonition blocks
    # like !!! info)
    after_h1 = body.split(m_title.group(0), 1)[1] if m_title else body
    # Accumulate lines until the first sentence end, skipping admonitions
    para_lines = []
    in_admonition = False
    for line in after_h1.splitlines():
        s = line.strip()
        if not s:
            if para_lines:
                break  # paragraph break
            continue
        if s.startswith("!!!"):
            in_admonition = True
            continue
        if in_admonition:
            if line.startswith("    ") or s.startswith("!!!"):
                continue
            in_admonition = False
        if s.startswith("#") or s.startswith(">") or s.startswith("---") or s.startswith("```"):
            continue
        para_lines.append(s)
    paragraph = " ".join(para_lines)
    # Strip leading confidence emoji
    paragraph = re.sub(r"^(🟢|🟡|🔴)\s*", "", paragraph)
    # Strip markdown bold/italic markers from display string
    paragraph = re.sub(r"\*\*([^*]+)\*\*", r"\1", paragraph)
    paragraph = re.sub(r"\*([^*]+)\*", r"\1", paragraph)
    # Strip markdown link syntax [label](url) → label
    paragraph = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", paragraph)
    # Cap at ~220 chars on word boundary (sentence splitting is unreliable
    # in prose with numeric expressions like "0.491" that confuse period-
    # based parsers; clean character cap is more predictable).
    summary = paragraph
    if len(summary) > 220:
        cut = summary[:220].rsplit(" ", 1)[0]
        summary = cut + "…"
    return {"title": title, "confidence": conf, "summary": summary}


def render_findings():
    files = sorted(
        f for f in (BASE / "findings").glob("*.md") if f.name != "index.md"
    )
    entries = [(f, extract_finding_metadata(f)) for f in files]

    rows = []
    for f, m in entries:
        link = f"[{m['title']}]({f.name})"
        rows.append(f"| {m['confidence']} | {link} | {m['summary']} |")

    section = (
        "## Generated index\n\n"
        f"All {len(entries)} finding pages, auto-generated from the body of "
        "each `docs/findings/<slug>.md` via `scripts/render_indexes.py`. "
        "Confidence and one-line summary extracted from the page lede.\n\n"
        "| Conf. | Finding | Summary |\n"
        "|:-:|---|---|\n"
        + "\n".join(rows)
        + "\n\n"
        "**Confidence legend.** 🟢 replicated / load-bearing for paper "
        "framing; 🟡 single-source own-project estimate; 🔴 provisional, kept "
        "for the record only. Promotion to 🟢 generally requires independent "
        "replication on a non-BEC procurement panel.\n"
    )
    replace_generated_index(BASE / "findings" / "index.md", section)
    print(f"  findings/index.md updated ({len(entries)} rows)")


def main():
    print("Rendering generated-index sections:")
    render_analyses()
    render_hypotheses()
    render_findings()
    print("Done.")


if __name__ == "__main__":
    main()
