#!/usr/bin/env python3
"""
Generate descriptive statistics LaTeX table from the classified SES group-65 dataset.

Reads 1_Only_SES_group65_classified.parquet, applies winsorization at 1st/99th
percentiles, computes means, SDs, and Welch t-tests by purchase type, and outputs
a publication-ready LaTeX table.

Usage:
    python3 gen_desc_stats_table.py
"""

import numpy as np
import pyarrow.parquet as pq
from scipy import stats
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
INPUT = BASE_DIR / '1_Only_SES_group65_classified.parquet'
OUTPUT = BASE_DIR.parent.parent / 'manuscript' / 'table_desc_stats_ses_g65.tex'

# Variables to winsorize (levels)
WINSOR_VARS = ['bid_price_ref', 'bid_price', 'bid_qty', 'n_firms_bids', 'n_bids_bids']


def winsorize(arr, lower=0.01, upper=0.99):
    """Winsorize array at given percentiles, ignoring NaNs."""
    valid = arr[~np.isnan(arr)]
    if len(valid) == 0:
        return arr
    p_lo, p_hi = np.nanpercentile(arr, [lower * 100, upper * 100])
    out = arr.copy()
    out[out < p_lo] = p_lo
    out[out > p_hi] = p_hi
    return out


def welch_ttest(a, b):
    """Two-sided Welch t-test, returns (diff, p-value)."""
    a_clean = a[~np.isnan(a)]
    b_clean = b[~np.isnan(b)]
    if len(a_clean) < 2 or len(b_clean) < 2:
        return (np.nan, np.nan)
    diff = np.mean(a_clean) - np.mean(b_clean)
    _, pval = stats.ttest_ind(a_clean, b_clean, equal_var=False)
    return (diff, pval)


def stars(pval):
    if pval < 0.01:
        return '***'
    elif pval < 0.05:
        return '**'
    elif pval < 0.1:
        return '*'
    return ''


def fmt_num(x, decimals=2, comma=False):
    """Format number with given decimals. Use comma=True for thousands separators."""
    if np.isnan(x):
        return '--'
    if comma:
        if decimals == 0:
            return f'{x:,.0f}'
        return f'{x:,.{decimals}f}'
    return f'{x:.{decimals}f}'


def main():
    print(f"Reading {INPUT}")
    table = pq.read_table(INPUT)
    df_dict = {}
    for col in table.column_names:
        df_dict[col] = table.column(col).to_pylist()
    n = table.num_rows
    print(f"  Rows: {n:,}")

    # Convert to numpy arrays
    purchase_type = np.array(df_dict['purchase_type'], dtype=float)

    arrays = {}
    for v in WINSOR_VARS + ['po_item_winner']:
        raw = df_dict[v]
        arrays[v] = np.array([float(x) if x is not None else np.nan for x in raw])

    # --- Winsorize ---
    print("Winsorizing at 1st/99th percentiles...")
    for v in WINSOR_VARS:
        before_nan = np.sum(np.isnan(arrays[v]))
        arrays[v] = winsorize(arrays[v])
        print(f"  {v}: {before_nan} NaNs, range [{np.nanmin(arrays[v]):.2f}, {np.nanmax(arrays[v]):.2f}]")

    # --- Log transformations (log of level, not log(1+x)) ---
    # Following the convention in the existing table where prices can be negative in log
    # Use np.log for positive values, NaN otherwise
    log_vars = {
        'log_bid_price_ref': 'bid_price_ref',
        'log_bid_price': 'bid_price',
        'log_bid_qty': 'bid_qty',
        'log_n_firms_bids': 'n_firms_bids',
        'log_n_bids_bids': 'n_bids_bids',
    }
    for lv, sv in log_vars.items():
        vals = arrays[sv].copy()
        with np.errstate(divide='ignore', invalid='ignore'):
            logged = np.log(vals)
        logged[~np.isfinite(logged)] = np.nan
        arrays[lv] = logged

    # --- Split by purchase type ---
    mask_ord = purchase_type == 0   # Ordinary
    mask_adm = purchase_type == 1   # Administrative
    mask_jud = purchase_type == 2   # Litigated (Judicial)

    print(f"  Ordinary: {np.sum(mask_ord):,}")
    print(f"  Administrative: {np.sum(mask_adm):,}")
    print(f"  Litigated: {np.sum(mask_jud):,}")

    # --- Unique counts ---
    po_arr = np.array(df_dict['po'])
    item_arr = np.array(df_dict['item'])
    pbu_arr = np.array(df_dict['pbu_code'])

    def unique_count(arr, mask):
        return len(set(v for v, m in zip(arr, mask) if m and v))

    # --- Build rows ---
    # Each row: (label, var_key, decimals_mean, decimals_sd, use_comma)
    panel_a = [
        ('Reference~Price',       'bid_price_ref',  2, 2, True),
        ('Negotiated~Price',      'bid_price',      2, 2, True),
        ('Quantity',              'bid_qty',         0, 0, True),
        ('No.~Participant~Firms', 'n_firms_bids',   2, 2, False),
        ('No.~Bids',             'n_bids_bids',     2, 2, False),
    ]

    panel_b = [
        ('Log~Reference~Price',  'log_bid_price_ref', 3, 3, False),
        ('Log~Negotiated~Price', 'log_bid_price',     3, 3, False),
        ('Log~Quantity',         'log_bid_qty',        3, 3, False),
        ('Log~No.~Firms',       'log_n_firms_bids',   3, 3, False),
        ('Log~No.~Bids',        'log_n_bids_bids',    3, 3, False),
    ]

    panel_c = [
        ('Successful~Tender~(\\%)', 'po_item_winner', 3, 3, False),
    ]

    def make_row(label, var_key, dec_m, dec_s, comma):
        v = arrays[var_key]
        vo = v[mask_ord]; va = v[mask_adm]; vj = v[mask_jud]

        m_o = np.nanmean(vo); s_o = np.nanstd(vo, ddof=1)
        m_a = np.nanmean(va); s_a = np.nanstd(va, ddof=1)
        m_j = np.nanmean(vj); s_j = np.nanstd(vj, ddof=1)

        diff_oj, p_oj = welch_ttest(vo, vj)
        diff_aj, p_aj = welch_ttest(va, vj)

        st_oj = stars(p_oj)
        st_aj = stars(p_aj)

        # Format means
        fm_o = fmt_num(m_o, dec_m, comma)
        fm_a = fmt_num(m_a, dec_m, comma)
        fm_j = fmt_num(m_j, dec_m, comma)
        fd_oj = fmt_num(diff_oj, dec_m, comma) + st_oj
        fd_aj = fmt_num(diff_aj, dec_m, comma) + st_aj

        # Format SDs
        fs_o = fmt_num(s_o, dec_s, comma)
        fs_a = fmt_num(s_a, dec_s, comma)
        fs_j = fmt_num(s_j, dec_s, comma)
        fp_oj = f'[{p_oj:.3f}]'
        fp_aj = f'[{p_aj:.3f}]'

        line1 = f'    {label} & {fm_o} & {fm_a} & {fm_j} & {fd_oj} & {fd_aj} \\\\'
        line2 = f'    & ({fs_o}) & ({fs_a}) & ({fs_j}) & {fp_oj} & {fp_aj} \\\\[3pt]'
        return line1 + '\n' + line2

    lines = []
    lines.append(r'\begin{table}[ht]')
    lines.append(r'  \centering')
    lines.append(r'  \caption{Descriptive Statistics by Purchase Type --- SES, Group 65}')
    lines.append(r'  \label{tab:desc_stats_ses_g65}')
    lines.append(r'  \footnotesize')
    lines.append(r'  \begin{threeparttable}')
    lines.append(r'  \setlength{\tabcolsep}{4pt}')
    lines.append(r'  \begin{tabular}{lccccc}')
    lines.append(r'    \hline\hline')
    lines.append(r'    & \multicolumn{3}{c}{Purchase Type} & \multicolumn{2}{c}{Difference in Means} \\')
    lines.append(r'    \cmidrule(lr){2-4} \cmidrule(lr){5-6}')
    lines.append(r'    & (1) Ordinary & (2) Administrative & (3) Litigated & (1)--(3) & (2)--(3) \\')
    lines.append(r'    \hline')

    # Panel A
    lines.append(r'    \multicolumn{6}{l}{\textit{Panel A: Levels}} \\[3pt]')
    for label, var, dm, ds, comma in panel_a:
        lines.append(make_row(label, var, dm, ds, comma))
    lines.append(r'    \hline')

    # Panel B
    lines.append(r'    \multicolumn{6}{l}{\textit{Panel B: Log Transformations}} \\[3pt]')
    for label, var, dm, ds, comma in panel_b:
        lines.append(make_row(label, var, dm, ds, comma))
    lines.append(r'    \hline')

    # Panel C
    lines.append(r'    \multicolumn{6}{l}{\textit{Panel C: Tender Characteristics}} \\[3pt]')
    for label, var, dm, ds, comma in panel_c:
        lines.append(make_row(label, var, dm, ds, comma))
    lines.append(r'    \hline')

    # Observation counts
    n_ord = int(np.sum(mask_ord))
    n_adm = int(np.sum(mask_adm))
    n_jud = int(np.sum(mask_jud))
    lines.append(f'    Observations & {n_ord:,} & {n_adm:,} & {n_jud:,} & & \\\\')
    lines.append(f'    Unique~Items & {unique_count(item_arr, mask_ord):,} & {unique_count(item_arr, mask_adm):,} & {unique_count(item_arr, mask_jud):,} & & \\\\')
    lines.append(f'    Unique~Purchase~Orders & {unique_count(po_arr, mask_ord):,} & {unique_count(po_arr, mask_adm):,} & {unique_count(po_arr, mask_jud):,} & & \\\\')
    lines.append(f'    Unique~Buying~Units & {unique_count(pbu_arr, mask_ord):,} & {unique_count(pbu_arr, mask_adm):,} & {unique_count(pbu_arr, mask_jud):,} & & \\\\')

    lines.append(r'    \hline\hline')
    lines.append(r'  \end{tabular}')
    lines.append(r'  \begin{tablenotes}')
    lines.append(r'    \footnotesize')
    lines.append(r'    \item \textit{Notes:} Sample includes all purchases from S\~ao Paulo State Health Department (SES) for Group~65 items (medical, dental, and hospital equipment and supplies), 2009--2019. Continuous variables winsorized at the 1st and 99th percentiles. Standard deviations in parentheses.')
    lines.append(r'    \textit{p}-values of two-sided Welch \textit{t}-tests for equality of means in brackets.')
    lines.append(r'    *** \textit{p}$<$0.01, ** \textit{p}$<$0.05, * \textit{p}$<$0.1.')
    lines.append(r'    Column~(4) reports the difference between Ordinary and Litigated purchases.')
    lines.append(r'    Column~(5) reports the difference between Administrative and Litigated purchases.')
    lines.append(r'  \end{tablenotes}')
    lines.append(r'  \end{threeparttable}')
    lines.append(r'\end{table}')

    tex = '\n'.join(lines) + '\n'
    OUTPUT.write_text(tex)
    print(f"\nTable written to {OUTPUT}")


if __name__ == '__main__':
    main()
