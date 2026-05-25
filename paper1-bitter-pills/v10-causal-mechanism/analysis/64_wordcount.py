#!/usr/bin/env python3
"""Reproducible main-paper word count for the JPubE 6,000-word cap.

Counts abstract + body section files (Introduction, InstitutionalBackground,
DataAndSample, EmpiricalStrategy, Results, Conclusion). Excludes: references
(separate bib), tables (\\input'd table files), inline/display math, and the
Online Appendix (separate file). Macros (\\BP...) and citations each count as one
word (they render to a number or a short cite). Reports counts with and without
figure-caption text. Method mirrors texcount's default 'words in text'.
"""
import re, sys, os

PAPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "manuscript", "paper")
BODY = ["Introduction.tex", "InstitutionalBackground.tex", "DataAndSample.tex",
        "EmpiricalStrategy.tex", "Results.tex", "Conclusion.tex"]

def abstract_text(main_tex):
    s = open(main_tex, encoding="utf-8").read()
    m = re.search(r"\\begin\{abstract\}(.*?)\\end\{abstract\}", s, re.S)
    return m.group(1) if m else ""

def strip_comments(t):
    return "\n".join(re.sub(r"(?<!\\)%.*", "", ln) for ln in t.splitlines())

def count_words(t, keep_captions):
    t = strip_comments(t)
    t = re.sub(r"\\input\{[^}]*\}", " ", t)                       # \input tables
    t = re.sub(r"\\begin\{(equation|align|displaymath|gather)\*?\}.*?\\end\{\1\*?\}", " ", t, flags=re.S)
    t = re.sub(r"\\\[.*?\\\]", " ", t, flags=re.S)                # display math
    t = re.sub(r"(?<!\\)\$[^$]*\$", " ", t)                       # inline math
    if not keep_captions:
        t = re.sub(r"\\caption\{(?:[^{}]|\{[^{}]*\})*\}", " ", t, flags=re.S)
    # citations and cross-refs render to ~1 word
    t = re.sub(r"\\cite[a-z]*\*?\s*(\[[^\]]*\])?\{[^}]*\}", " CITE ", t)
    t = re.sub(r"\\cites\{[^}]*\}", " CITE ", t)
    t = re.sub(r"\\(ref|eqref|autoref|pageref)\{[^}]*\}", " REF ", t)
    t = re.sub(r"\\label\{[^}]*\}", " ", t)
    # paper macros render to a number / short string -> one word each
    t = re.sub(r"\\BP[A-Za-z]+\{\}", " NUM ", t)
    t = re.sub(r"\\BP[A-Za-z]+", " NUM ", t)
    # section/subsection: drop the command, keep the title text
    t = re.sub(r"\\(sub)*section\*?\{", " ", t)
    # remaining control sequences: drop the command name, keep brace contents
    t = re.sub(r"\\[a-zA-Z]+\*?", " ", t)
    t = re.sub(r"[{}\[\]~]", " ", t)
    t = t.replace("\\", " ")
    tokens = [w for w in re.split(r"\s+", t) if re.search(r"[A-Za-z0-9]", w)]
    return len(tokens)

def main():
    main_tex = os.path.join(PAPER, "main.tex")
    parts = [("abstract", abstract_text(main_tex))] + \
            [(f, open(os.path.join(PAPER, f), encoding="utf-8").read()) for f in BODY]
    print(f"{'component':<28}{'no captions':>14}{'with captions':>16}")
    tot_no = tot_yes = 0
    for name, txt in parts:
        n_no = count_words(txt, keep_captions=False)
        n_yes = count_words(txt, keep_captions=True)
        tot_no += n_no; tot_yes += n_yes
        print(f"{name:<28}{n_no:>14}{n_yes:>16}")
    print("-" * 58)
    print(f"{'TOTAL (excl refs/tables/math/appendix)':<28}{tot_no:>14}{tot_yes:>16}")
    print(f"\nJPubE cap: 6000.  Buffer (no-captions): {6000 - tot_no} words.")

if __name__ == "__main__":
    main()
