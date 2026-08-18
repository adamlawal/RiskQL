# RiskQL Data Dictionary

All data is **synthetic** (see `data/raw/README.md`). This dictionary documents
the tables, columns, types, and business meaning of the RiskQL model.

Legend: **PK** = primary key, **FK** = foreign key, **NN** = NOT NULL,
**NULL?** = may be NULL and what that means.

---

## Reference tables

### `countries`
The set of countries used for customers, branches, and transaction geography.

| Column | Type | Key | Notes |
|---|---|---|---|
| `country_id` | TEXT | PK | Surrogate id, e.g. `C001`. |
| `country_name` | TEXT | NN | e.g. `Nigeria`. |
| `country_code` | CHAR(2) | UNIQUE, NN | ISO 3166-1 alpha-2, e.g. `NG`. |
| `region` | TEXT | | Coarse analytical grouping (not an official standard). |

### `transaction_types`
Categories of transaction.

| Column | Type | Key | Notes |
|---|---|---|---|
| `type_id` | TEXT | PK | e.g. `TT01`. |
| `type_name` | TEXT | UNIQUE, NN | `TRANSFER`, `DEPOSIT`, `WITHDRAWAL`, `BILL_PAYMENT`, `CARD_PAYMENT`, `INTERNATIONAL_REMITTANCE`. |

### `channels`
Banking channels through which transactions and logins occur.

| Column | Type | Key | Notes |
|---|---|---|---|
| `channel_id` | TEXT | PK | e.g. `CH01`. |
| `channel_name` | TEXT | UNIQUE, NN | `MOBILE_APP`, `INTERNET_BANKING`, `ATM`, `BRANCH`, `POS`, `PHONE_BANKING`. |

### `branches`
Physical bank branches. Treated as slowly-changing reference data.

| Column | Type | Key | Notes |
|---|---|---|---|
| `branch_id` | TEXT | PK | e.g. `B001`. |
| `branch_name` | TEXT | NN | |
| `city` | TEXT | NN | |
| `state` | TEXT | NULL? | Optional. |
| `country_id` | TEXT | FK → countries | NN. |

---

## Core entities

### `customers`
A banking customer (a person).

| Column | Type | Key | Notes |
|---|---|---|---|
| `customer_id` | TEXT | PK | e.g. `CU000001`. |
| `first_name` | TEXT | NN | |
| `middle_name` | TEXT | NULL? | Not everyone has one. |
| `last_name` | TEXT | NN | |
| `date_of_birth` | DATE | NN | Synthetic; all adults. |
| `email` | TEXT | NULL? | May be unknown. |
| `phone` | TEXT | NULL? | Stored as TEXT (leading `+`, country code); never numeric. |
| `city` | TEXT | NULL? | |
| `state` | TEXT | NULL? | |
| `country_id` | TEXT | FK → countries, NN | The customer's **recorded** country. Compared against login origin for the geo-mismatch indicator. |
| `created_at` | TIMESTAMPTZ | NN | Record creation time. |

### `accounts`
A bank account. A customer may hold several.

| Column | Type | Key | Notes |
|---|---|---|---|
| `account_id` | TEXT | PK | e.g. `AC0000001`. |
| `customer_id` | TEXT | FK → customers, NN | Owner. |
| `branch_id` | TEXT | FK → branches, NN | Home branch. |
| `account_type` | TEXT | NN | CHECK ∈ {`CURRENT`,`SAVINGS`,`CHECKING`}. |
| `currency_code` | CHAR(3) | NN | Account currency (e.g. `NGN`). Independent of the account's country — geography is never inferred from currency. |
| `current_balance` | NUMERIC(18,2) | NN | CHECK ≥ 0. NUMERIC (not FLOAT) for exact money. |
| `created_at` | TIMESTAMPTZ | NN | |
| `creation_channel` | TEXT | NULL? | How the account was opened; free text, **not** a FK. |
| `status` | TEXT | NN | CHECK ∈ {`ACTIVE`,`DORMANT`,`SUSPENDED`,`CLOSED`}. |

### `login_events`
A customer login attempt (digital-activity signal).

| Column | Type | Key | Notes |
|---|---|---|---|
| `login_id` | TEXT | PK | e.g. `LG00000001`. |
| `customer_id` | TEXT | FK → customers, NN | |
| `channel_id` | TEXT | FK → channels, NN | |
| `timestamp` | TIMESTAMPTZ | NN | Reserved-ish name kept to match the ERD; quoted when needed. |
| `ip_address` | TEXT | NULL? | |
| `origin_country_id` | TEXT | FK → countries, NULL? | Login origin country. **NULL = unknown origin** (e.g. missing geo-IP). |
| `status` | TEXT | NN | CHECK ∈ {`SUCCESS`,`FAILED`}. |

### `transactions` — central analytical table
A single transaction between a sender account and a recipient (internal account
or external party).

| Column | Type | Key | Notes |
|---|---|---|---|
| `transaction_id` | TEXT | PK | e.g. `TX000000001`. |
| `sender_account_id` | TEXT | FK → accounts, NN | The originating account. |
| `recipient_account_id` | TEXT | FK → accounts, NULL? | **NULL = external recipient** (not held at this bank). |
| `external_reference` | TEXT | NULL? | Populated for external transfers; unique per external txn. |
| `transaction_type_id` | TEXT | FK → transaction_types, NN | |
| `channel_id` | TEXT | FK → channels, NN | |
| `sending_amount` | NUMERIC(18,2) | NN | CHECK > 0. In `sending_currency`. |
| `sending_currency` | CHAR(3) | NN | |
| `receiving_amount` | NUMERIC(18,2) | NN | CHECK > 0. In `receiving_currency`. |
| `receiving_currency` | CHAR(3) | NN | |
| `exchange_rate` | NUMERIC(18,8) | NULL? | CHECK (NULL OR > 0). **NULL when sending = receiving currency.** |
| `created_at` | TIMESTAMPTZ | NN | |
| `origin_country_id` | TEXT | FK → countries, NN | Where the transaction originated. Always explicit. |
| `destination_country_id` | TEXT | FK → countries, NULL? | **NULL = external/unknown destination.** Never inferred from currency. |
| `status` | TEXT | NN | CHECK ∈ {`COMPLETED`,`FAILED`,`PENDING`,`REVERSED`}. |

**Cross-border definition (used throughout):** a transaction is *cross-border*
when `destination_country_id` is NOT NULL **and** differs from
`origin_country_id`. A NULL destination is reported as *external/unknown*, never
folded into "domestic".

---

## Relationships (summary)

```
countries ──< customers ──< accounts ──< transactions (sender / recipient)
countries ──< branches  ──< accounts
countries ──< transactions (origin / destination)
countries ──< login_events (origin)
customers ──< login_events
transaction_types ──< transactions
channels ──< transactions
channels ──< login_events
```
