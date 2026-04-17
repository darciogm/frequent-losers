# Regex classifier validation --- hand-labeling protocol

## Goal

Produce F1, precision, and recall for the regex-based purchase-type
classifier that assigns each BEC-G65 tender notice to one of three
classes: **ordinary**, **administrative**, or **litigated**. The table
goes into Online Appendix §A.8; the one-line summary goes into the
existing F1 footnote in `DataAndSample.tex`.

## Files

| File                              | Role                                        |
|-----------------------------------|---------------------------------------------|
| `validation_sample.csv`           | 500 tender-notice subjects to label         |
| `../../analysis/33_regex_validation_sample.R` | generates the CSV (already run)  |
| `../../analysis/34_regex_validation_f1.R`     | computes F1 once labels are in   |
| `tab_regex_f1.tex` (will be created)          | LaTeX table for OA §A.8         |

## Sampling design

500 unique **tender-notice subjects** (field `po_subject`), stratified
by predicted class:

| Predicted class    | Count | Universe (unique subjects) |
|--------------------|-------|----------------------------|
| Ordinary (0)       | 166   | 46,369                     |
| Administrative (1) | 167   | 1,103                      |
| Litigated (2)      | 167   | 3,354                      |

Sampling uses `set.seed(20260417)` for reproducibility. The universe is
unique subjects (not POIs), since the regex classifies at subject level
and each subject spawns multiple POIs that inherit the label.

## How to label

1. Open `validation_sample.csv` in a spreadsheet (Excel, LibreOffice,
   Numbers, Google Sheets). The file is UTF-8 with comma delimiter.
2. For each row, read `po_subject` and fill the `true_class` column
   with one of:
   - `0` --- ordinary procurement. Standard purchase with no court
     order and no administrative-request mechanism. Phrasing: routine
     acquisition, stock replenishment, no mention of sanctions or
     individual patients.
   - `1` --- administrative. Urgent request routed through the
     SES/SP's administrative channel (scientific committee screen).
     Phrasing: reference to "solicitação administrativa", "demanda
     administrativa", absence of court reference, urgent delivery but
     no lawsuit.
   - `2` --- litigated. References a court order, injunction, lawsuit,
     writ, judicial mandate, or "ação judicial". Phrasing: "ordem
     judicial", "ação judicial", "mandado", "liminar", explicit
     reference to a case number.
3. Optionally fill `notes` for borderline or ambiguous cases (free
   text; will be ignored by the F1 script but useful to audit
   disagreements later).
4. Save the file back as `validation_sample.csv` (keep column order,
   keep `predicted_class` and `predicted_name` untouched).

## Guidelines for borderline cases

- If a subject mentions "registro de preços" without further context,
  it is usually **ordinary** (class 0) unless explicit judicial
  reference.
- If a subject references both court order and administrative request,
  label as **litigated** (class 2): the sanction regime dominates.
- If the subject is truncated/illegible or unclear, fill `true_class`
  with your best guess and leave a note. The F1 script will still
  process these rows; you can filter manually later.
- Expected labeling rate: ~2--3 min per row after warm-up; total ~20
  hours for 500 rows. Can be split over multiple sessions.

## Computing F1

Once the CSV is labeled, run:

```bash
Rscript v6-jpub-short/analysis/34_regex_validation_f1.R
```

Output:
- Stdout: confusion matrix, per-class precision/recall/F1,
  macro-average, accuracy, and a ready-to-paste footnote sentence for
  `DataAndSample.tex`.
- File: `tab_regex_f1.tex` (LaTeX table for OA §A.8). Add to
  `Appendix.tex` via `\input{../../output/validation/tab_regex_f1}`
  (canonical path) or `\input{tables/tab_regex_f1}` (packages).

If the sample is only partially labeled, the script still runs on the
labeled subset with a warning.

## Target

A minimally defensible result for JPubE is **per-class F1 $\geq$ 0.80**.
For borderline F1, a sensitivity block showing UTG estimates with the
regex-classified sample versus a clean hand-labeled subset is a good
hedge.

## Expected timeline

- Labeling: 2--3 days part-time (~20 h focused).
- F1 computation: 1 minute.
- Integration into the paper: 30 minutes (add \input, recompile 3
  packages, regenerate zips).
