# External Validation Protocol For Closure-Motive Labels

## Purpose

This protocol audits the LLM-generated closure-motive labels used to construct
the F6 documentary sample. It is an external validation step, not an extension
of the model prompt. The goal is to compare the LLM label against independent
human coders who are blinded to the LLM verdict.

## Sampling

- Universe: closures in `02_data/intermediate/closures_classified_v2.parquet`
  that also survive the F5 exogeneity filter.
- Audit sample: a fixed-seed simple random sample of 10 percent of that
  universe, rounded up to at least 6 closures.
- Sampling seed: 20260501.
- The sampled rows are exported to
  `02_data/intermediate/closure_validation_sample.csv`.

## Blinding

- Coders receive closure metadata, Receita fields, and documentary snippet
  fields, but not `motivo_v2`, `confidence_v2`, `reasoning_v2`, or any mention
  of the model verdict.
- The sample sheet uses a neutral `validation_id` rather than CNES as the first
  visible identifier.

## Coding Frame

Each coder must assign exactly one label from:

- `administrativo`
- `fiscal`
- `falencia`
- `fusao`
- `demanda`
- `pandemia`
- `outros`
- `unknown`

Coders also record:

- `coder_confidence` in `{1,2,3,4,5}`
- `coder_notes` with brief evidence used
- `needs_escalation` if the case is too ambiguous for independent adjudication

## Two-Coder Workflow

1. Coder A labels the blinded sample independently.
2. Coder B labels the same sample independently.
3. Rows with agreement move directly to `adjudicated_label`.
4. Rows with disagreement are reviewed by a third adjudicator.
5. The adjudicated file is stored in
   `02_data/intermediate/closures_human_validated.parquet`.

## Audit Outputs

- Agreement rate and Cohen's kappa between coder A and coder B.
- Confusion matrix between the adjudicated human label and `motivo_v2`.
- Sensitivity result dropping fragile subclasses:
  `stale_receita_status` and `only_web_snippet_evidence`.

## Current Status

The repository now contains the blinded sample, the empty two-coder scaffold,
and a synthetic sensitivity placeholder. Human coding has not yet been
performed, so any table row referring to external validation is explicitly
marked as pending human labels.
