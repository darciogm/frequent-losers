# HonestDiD Mortality Sensitivity Gap

The mortality sensitivity analysis could not be estimated in this environment because the optional R package `HonestDiD` is not installed.

Package check:

```r
requireNamespace("HonestDiD", quietly = TRUE)
# FALSE
```

Install command:

```sh
Rscript -e "install.packages('remotes'); remotes::install_github('asheshrambachan/HonestDiD')"
```

After installation, rerun:

```sh
Rscript 03_analysis/58_honestdid_mortality_revision.R --force
```

The script will use `02_data/intermediate/staggered_panel_pnash48_ext.parquet`, estimate population-weighted Sun--Abraham event studies for `suicide_per100k` and `selfharm_per100k`, extract the event-study coefficient vector and covariance matrix, and call `HonestDiD::createSensitivityResults_relativeMagnitudes()` over a grid of relative-magnitude restrictions.

No `fig_honestdid_suicide.pdf` or `fig_honestdid_selfharm.pdf` was generated in the gap path. Producing placeholder figures would make the manuscript look more complete than the computation supports.
