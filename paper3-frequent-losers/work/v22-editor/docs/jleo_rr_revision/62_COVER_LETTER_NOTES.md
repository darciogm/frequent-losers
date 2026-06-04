# 62 — Cover letter & admin package notes

Built the JLEO administrative submission package under
`work/v22-editor/submission_jleo/`. Notes on choices, HUMAN_DECISION flags, and
the exclusive-submission / fee / data positions.

## Files created

```
submission_jleo/
  cover_letter/
    cover_letter_jleo.md          # one-page, 5 paragraphs, "Dear Editor"
    cover_letter_jleo_short.md    # ~120-word Editorial Express text-field version
  admin/
    editorial_express_fields.md
    data_replication_statement.md
    confidential_data_exemption_note.md
    conflict_funding_permissions_preprint_statement.md
    suggested_reviewers_template.md   # EMPTY template, no names
```

## Sourcing / accuracy choices

- **Abstract** pasted verbatim (de-LaTeX'd) from
  `submission_clean/sec_frontmatter_submission.tex`. Measured **142 words** —
  within the JLEO 150-word cap. Keywords + JEL (D44, D73, H57, K21, L41) also
  pulled from that frontmatter.
- `\valSampleN` left as the macro in prose; the context value is 1,654,401
  tender-items. Cover letter keeps the macro so it tracks the manuscript.
- **Discipline language honored throughout:** "forensic priority" not "proof";
  cobidders = "adjudication-anchored exposure" not cartel members; price =
  "scope evidence" not damages/overcharge; cost-recall = "operating frontier"
  not optimal cutoff; no "cartel detector"; **no AUC numbers in the cover
  letter** (contributions framed qualitatively).
- Data positions taken straight from
  `work/v22-editor/replication/DATA_CONFIDENTIALITY.md` + `README.md`: CADE
  public; BEC microdata administrative/restricted/not redistributable; B3
  cobidder-builder absent → label funnel `79_label_funnel.R` is the reproducible
  alternative. **No claim that data/code are fully public.**

## Exclusive-submission / fee / data positions

- **Exclusive submission:** stated affirmatively in both the full and short
  cover letters and in `editorial_express_fields.md` ("submitted exclusively to
  JLEO; not under review elsewhere; not previously published"). JLEO requires
  exclusivity.
- **Fee:** $100 via PayPal on Editorial Express recorded in
  `editorial_express_fields.md`. Waiver only for OUP developing-nations lists
  A/B; **Brazil likely NOT exempt** → flagged HUMAN_DECISION (do not assume a
  waiver).
- **Data:** proprietary-data exemption to be **requested** for BEC microdata
  (`confidential_data_exemption_note.md`); replication supported by code +
  derived/anonymized frames + output map; restricted data NOT promised public.

## HUMAN_DECISION_REQUIRED flags (all listed)

1. **Fee/waiver eligibility** — confirm Brazil is not on OUP developing-nations
   list A/B before paying the $100 (editorial_express_fields.md).
2. **Corresponding-author email to register** — frontmatter lists
   `darciogm1@insper.edu.br`; brief specifies `darcio.g.martins@gmail.com`.
   Confirm which to use on Editorial Express (editorial_express_fields.md).
3. **Funding** — sources / grant numbers, or "none" (conflict_funding…,
   editorial_express_fields).
4. **Conflict of interest** — disclosures, or "none" (conflict_funding…,
   cover letter, editorial_express_fields).
5. **Legal/case involvement** — confirm authors are not parties to / counsel /
   experts in the CADE cases (default stated, needs confirmation)
   (conflict_funding…).
6. **Permissions** — confirm all figures author-generated and no third-party
   copyrighted material (working assumption: yes) (conflict_funding…).
7. **Preprint / prior circulation** — confirm whether any preprint/WP/conference
   version exists to disclose (conflict_funding…, editorial_express_fields).
8. **Suggested / non-preferred reviewers** — empty template; authors fill
   manually, no names invented (suggested_reviewers_template.md).

## Not invented (per rules)

No funding sources, grant numbers, conflicts, editor name ("Dear Editor"), IRB
facts (marked n.a. — administrative data, no human subjects), reviewer names, or
data-public claims were fabricated. Every unknown is a HUMAN_DECISION flag.

## Not done (per instructions)

Did **not** commit. Files are staged on disk only.
