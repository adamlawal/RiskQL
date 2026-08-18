# Development Notes

This file records the audit of the pre-existing repository and every
non-trivial change made while taking the project from "schema draft" to a
complete, reproducible portfolio project. The goal is to preserve the reasoning
behind the design, not just the final code.

## 1. Starting point (audit)

The repository already contained a strong foundation:

- `docs/business_scenario.md` — clear operational-risk framing and business
  questions.
- `docs/erd/RiskQL_ERD.png` — an ERD matching the schema.
- `sql/schema/001…008` — eight `CREATE TABLE` files with a sound conceptual
  model, already using several good practices (`NUMERIC` for money, `TIMESTAMPTZ`
  on most tables, `TEXT` phone numbers, nullable `recipient_account_id` /
  `destination_country_id` for external transactions, positive-amount CHECKs).
- `sql/seeds/countries.sql` — 5 countries.

**Empty placeholders:** `README.MD`, `reports/riskQL.md`, `.env`, `.env.example`,
and empty `data/` and `notebooks/` directories. **No data and no load process.**

The conceptual model was kept as-is. No tables were added or removed; the
central `transactions` entity and all relationships are unchanged.

## 2. Schema changes (Phase 2)

Each change is small, documented in-file, and justified below.

| Change | File | Why |
|---|---|---|
| `customers.created_at` changed `TIMESTAMP` → `TIMESTAMPTZ NOT NULL` | `002_create_customers.sql` | Consistency with every other table; the project rule is TIMESTAMPTZ for global timestamps. |
| Added `CHECK` on `account_type` and `status` domains | `006_create_accounts.sql` | Data quality — reject values outside the agreed set. |
| Added `CHECK` on `login_events.status` | `007_create_login_events.sql` | Same, for `SUCCESS`/`FAILED`. |
| Added `CHECK` on `transactions.status` | `008_create_transactions.sql` | Same, for `COMPLETED`/`FAILED`/`PENDING`/`REVERSED`. |
| Tidied `countries` (formatting + comment) | `001_create_countries.sql` | Readability only; no behaviour change. |
| Added `009_create_indexes.sql` | new | Secondary indexes on FK/filter columns for analytical performance. Optional for correctness. |

**Deliberately *not* changed:**

- `login_events.timestamp` column name. `timestamp` is a reserved-ish word but is
  legal in PostgreSQL and matches the ERD. Renaming would drift from the ERD for
  little benefit; it is simply quoted where needed.
- `accounts.creation_channel` kept as free `TEXT` (not a FK to `channels`). It
  records how an account was opened and may hold values that are not
  transactional channels. The ERD intentionally does not link it.
- No currency→country table, and geography is never inferred from currency —
  both explicit project constraints.

## 3. Data decision (Phase 3)

**Chosen approach: fully synthetic, clearly labelled data via a seeded
generator (`src/generate_data.py`).**

Rationale:

- No single public dataset cleanly provides *all* the dimensions the model needs
  together (cross-border corridors, login-origin vs. recorded geography,
  per-channel/per-type failure statuses, currencies, timestamps). A hybrid
  stitched from several sources would still require large amounts of synthetic
  fill-in.
- A seeded generator makes the whole project **reproducible offline and
  deterministically**, which is exactly what a reviewer needs to re-run it.
- The prompt explicitly permits clearly-labelled synthetic data when a public
  source cannot supply every dimension, and forbids fabricating a Kaggle source.

The generator intentionally injects a few *interpretable* patterns (some
channels/types fail more, a small set of high-frequency and high-value accounts,
a minority of geo-mismatched logins) so the analysis has something real to find.
These are analytical patterns to be *detected*, never labelled "fraud". The
synthetic nature is stated in the generator, `data/raw/README.md`, the notebook,
the README, and the final report.

## 4. Reference vs. generated data

- **Reference/seed** (small, hand-authored, in `sql/seeds/`): `countries` (15),
  `transaction_types` (6), `channels` (6), `branches` (12).
- **Generated** (bulk, synthetic → CSV → `COPY`): `customers` (2,000),
  `accounts` (~3,100), `login_events` (15,000), `transactions` (40,000).

The generated CSVs are git-ignored because they are reproducible; the generator
is committed instead.

## 5. Things a reviewer should know

- Monetary totals mix currencies and are **not** FX-normalised, so cross-currency
  sums are indicative only. This is called out wherever totals appear.
- All "risk" outputs are **indicators** — prompts for investigation/context, not
  determinations of wrongdoing. The composite in
  `06_combined_risk_indicators.sql` is a transparent *count* of documented
  boolean indicators (0–5), with **no weighting** and no opaque score.
- `reports/riskQL.md` (an empty placeholder) was replaced by
  `reports/risk_analysis.md`.
