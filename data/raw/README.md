# data/raw/

This directory is reserved for **immutable source data**.

## Important: this project uses synthetic data

RiskQL does **not** use a downloaded third-party dataset. No single public
dataset cleanly provides all the dimensions the conceptual model needs together
(cross-border transaction corridors, login-origin geography vs. recorded
customer geography, per-channel / per-type failure statuses, etc.).

Instead, the "source" of the data is a deterministic generator:

    src/generate_data.py

It is seeded (`SEED = 42`), so it reproduces the **same** data every time. The
generated CSVs are written to `data/processed/` (git-ignored) and loaded with
`sql/load_data.sql`.

### This data is not real

The generated records are **entirely fictitious**. They do not represent any
real person, account, transaction, institution, or country-level activity, and
they are **not** sourced from Kaggle or any other provider. The data exists only
to demonstrate SQL and data-analysis technique for a learning portfolio.

### If a real dataset is added later

Place the untouched original file(s) here and treat them as read-only. Do all
cleaning/transformation in `src/` and write the results to `data/processed/`,
documenting the source name, URL, and license in this README.
