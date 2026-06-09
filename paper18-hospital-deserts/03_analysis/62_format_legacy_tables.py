from __future__ import annotations

from revision_utils import TAB, begin_log, end_log, ensure_dirs, logger_for, parse_args, write_text


SCRIPT = "62_format_legacy_tables"
SUMMARY = TAB / "tab_summary_stats.tex"


def format_summary_table() -> bool:
    if not SUMMARY.exists():
        return False
    text = SUMMARY.read_text(encoding="utf-8")
    if "\\resizebox{\\textwidth}{!}{%" in text:
        return False
    text = text.replace(
        "\\begin{tabular}{lrrrrrr}",
        "\\resizebox{\\textwidth}{!}{%\n\\begin{tabular}{lrrrrrr}",
        1,
    )
    text = text.replace("\\end{tabular}\n\\\\[0.5em]", "\\end{tabular}\n}%\n\\\\[0.5em]", 1)
    write_text(SUMMARY, text)
    return True


def main() -> None:
    parse_args("Format legacy generated LaTeX tables without changing numbers.")
    ensure_dirs()
    log = logger_for(SCRIPT)
    t0 = begin_log(log, SCRIPT)
    changed = format_summary_table()
    log.info("formatted_summary_table=%s", changed)
    end_log(log, t0)


if __name__ == "__main__":
    main()
