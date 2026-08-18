# Learning Notes

Project-specific notes on the main implementation decisions in RiskQL. These are
not a generic SQL tutorial — each note explains a decision *made in this project*,
the concept behind it, alternatives considered, and one takeaway for a beginner.

---

## 1. Primary keys and surrogate ids

**What:** every table has a `TEXT` surrogate primary key (`customer_id`,
`account_id`, `transaction_id`, …) rather than relying on a natural key.

**Concept:** a primary key uniquely identifies each row and is the anchor other
tables point at.

**Alternatives considered:** natural keys (e.g. email as a customer key) or
auto-incrementing integers. Natural keys change and can be missing (email is
nullable here). Integers are fine but opaque; readable prefixed ids (`TX…`,
`AC…`) make the synthetic data and query output easy to eyeball.

**Beginner takeaway:** pick a key that is stable and always present. Don't key a
table on something a user might change.

## 2. Foreign keys and referential integrity

**What:** `accounts.customer_id REFERENCES customers`, `transactions.sender_account_id
REFERENCES accounts`, and so on. The load order (customers → accounts →
transactions) exists *because* of these constraints.

**Concept:** a foreign key guarantees that a child row points at a real parent
row. The database refuses to insert a transaction for an account that doesn't
exist.

**Why it matters here:** the whole point of the project is trustworthy analysis.
FKs mean an "orphaned transaction" is impossible by construction — the data
quality check for it should always pass.

**Beginner takeaway:** referential integrity is enforced by the database, not by
hoping the application is careful.

## 3. Nullable foreign keys model real business facts

**What:** `transactions.recipient_account_id` and `destination_country_id` are
nullable; `login_events.origin_country_id` is nullable.

**Concept:** NULL means "not applicable / unknown", and that is a real state
here: an **external** recipient isn't an account at this bank, and a login's
country may be unknown.

**Alternative rejected:** inventing a fake "external" account or "unknown"
country row. That would pollute joins and counts.

**Beginner takeaway:** don't force every relationship to be mandatory. Model
"external/unknown" honestly with NULL, and handle it explicitly (we use
`LEFT JOIN` and separate the NULL bucket in cross-border analysis).

## 4. NUMERIC vs FLOAT for money

**What:** `sending_amount`, `receiving_amount`, `current_balance` are
`NUMERIC(18,2)`; `exchange_rate` is `NUMERIC(18,8)`.

**Concept:** `FLOAT`/`DOUBLE` are binary approximations — `0.1 + 0.2` is not
exactly `0.3`. `NUMERIC` stores exact decimal values.

**Why it matters here:** money must sum and compare exactly. Rounding drift is
unacceptable in a financial model even a synthetic one.

**Beginner takeaway:** never store money as FLOAT. Use `NUMERIC`/`DECIMAL`.

## 5. TIMESTAMPTZ for global timestamps

**What:** all event times are `TIMESTAMPTZ`; the generator writes ISO-8601 UTC.

**Concept:** `TIMESTAMPTZ` stores an absolute instant and normalises to UTC.
Plain `TIMESTAMP` is "wall-clock with no timezone" and is ambiguous across
regions.

**Why it matters here:** the model is a *global* bank spanning many countries.
Comparing a Lagos login to a New York transaction requires a common time basis.
This is exactly why `customers.created_at` was changed from `TIMESTAMP` to
`TIMESTAMPTZ` during the audit — for consistency with every other table.

**Beginner takeaway:** for anything spanning time zones, use `TIMESTAMPTZ` and
store UTC.

## 6. TEXT for phone numbers

**What:** `customers.phone` is `TEXT`.

**Concept:** phone "numbers" aren't numbers — they have leading `+`, country
codes, and leading zeros that a numeric type would destroy. You never do
arithmetic on them.

**Beginner takeaway:** store identifiers-that-look-like-numbers (phones, ZIP
codes, account numbers) as text.

## 7. CHECK constraints as business rules

**What:** amounts must be `> 0`, balances `>= 0`, and `status`/`account_type`
columns are restricted to a fixed set with `CHECK (... IN (...))`.

**Concept:** a `CHECK` constraint refuses rows that violate a rule at write time.

**Alternative considered:** a separate lookup table for every status. For a small,
stable enum that would be over-normalisation; a `CHECK` is simpler and just as
safe. (By contrast `channels`/`transaction_types` *are* lookup tables, because
they carry ids used as foreign keys elsewhere.)

**Beginner takeaway:** encode simple invariants in the schema so bad data can't
get in. Choose lookup-table vs `CHECK` based on whether other tables need to
reference the value.

## 8. Normalisation — and knowing when to stop

**What:** `countries`, `transaction_types`, `channels`, `branches` are separate
reference tables; but `region`, `account_type`, and status enums are plain
columns.

**Concept:** normalisation removes duplication so a value is stored once. But
every extra table adds a join.

**Decision here:** the project brief explicitly warns against creating tables
"merely for theoretical normalization". We stopped at the point where a table
earns its keep (it has an id referenced elsewhere, or a meaningful attribute).

**Beginner takeaway:** normalise to remove real, update-prone duplication — not
to hit a textbook "normal form" for its own sake.

## 9. JOIN vs LEFT JOIN — the choice is analytical

**What:** the corridor query uses inner `JOIN countries` on the destination
(which *drops* NULL/external destinations, correctly, because a corridor needs
two known endpoints). The branch-activity query uses `LEFT JOIN` (so a branch
with zero transactions still appears as 0, not missing).

**Concept:** an inner join keeps only matching rows; a left join keeps all
left-side rows and fills the right with NULL.

**Beginner takeaway:** ask "do I want rows with no match to disappear, or to show
as zero?" That answer picks the join.

## 10. Aggregation with `COUNT(*) FILTER (WHERE …)`

**What:** failure rates are computed as
`count(*) FILTER (WHERE status='FAILED') / count(*)`.

**Concept:** `FILTER` counts only rows meeting a condition, in the same pass as
the total — cleaner than `SUM(CASE WHEN … THEN 1 ELSE 0 END)` and than a
self-join.

**Beginner takeaway:** `FILTER` (PostgreSQL) lets you compute "part of the group"
and "all of the group" side by side in one `GROUP BY`.

## 11. CTEs for readable multi-step logic

**What:** the risk-indicator query builds `baseline`, `cust_txn`, `cust_login`,
`indicators` as chained `WITH` clauses.

**Concept:** a CTE names an intermediate result so a complex query reads top-to-
bottom instead of as nested subqueries.

**Beginner takeaway:** when a query needs several steps, name each step with a
CTE. Future-you will thank present-you.

## 12. Window functions for "compare a row to its group"

**What:** high-frequency/high-value detection uses
`AVG(...) OVER (PARTITION BY sender_account_id)` and
`SUM(...) OVER (ORDER BY ...)` for cumulative share.

**Concept:** a window function computes an aggregate *without collapsing rows*, so
each transaction can be compared to its own account's mean, or each country's
share can accumulate.

**Why it matters here:** "unusually large *for this account*" is a per-account
baseline — impossible with a plain `GROUP BY`, natural with a window.

**Beginner takeaway:** use a window function when you need an aggregate **and** to
keep the individual rows.

## 13. Data quality checks as first-class code

**What:** `sql/checks/data_quality.sql` implements 20+ explicit checks
(PK uniqueness, orphan FKs, invalid amounts/statuses/currencies, impossible
self-transfers, duplicate references) and prints PASS/FAIL.

**Concept:** even with constraints, you validate the *loaded result*, especially
when data comes from an external/staging source.

**Beginner takeaway:** treat data validation as runnable code with clear output,
not as a comment saying "we should check this".

## 14. Risk indicators must be interpretable

**What:** `06_combined_risk_indicators.sql` produces a **count** of five
documented boolean indicators (0–5), not a weighted score.

**Concept:** an interpretable indicator can be explained to a risk officer:
"this customer trips indicators I2 and I5, here are the thresholds". A black-box
score with invented weights cannot, and would be indefensible.

**Why deliberately no weights:** any weighting here would be arbitrary — there is
no labelled outcome to learn from. A transparent count is honest about that.

**Beginner takeaway:** prefer explainable rules with stated thresholds over
opaque scores, especially when you can't validate the score against real
outcomes. And always frame outputs as *indicators warranting context*, never as
proof.
