# RiskQL Data Dictionary

All data is **synthetic** (see `data/raw/README.md`).

Legend: **PK** = primary key, **FK** = foreign key, **NN** = NOT NULL.

---

## Reference tables

### `countries`

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `country_id` | TEXT | PK | Surrogate id (`C001`…). |
| `country_name` | TEXT | NN | e.g. Nigeria. |
| `country_code` | CHAR(2) | UNIQUE, NN, CHECK `^[A-Z]{2}$` | ISO 3166-1 alpha-2. |
| `region` | TEXT | | Coarse analytical grouping, not an official standard. |

### `transaction_types`

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `type_id` | TEXT | PK | e.g. `TT01`. |
| `type_name` | TEXT | UNIQUE, NN | `TRANSFER`, `DEPOSIT`, `WITHDRAWAL`, `BILL_PAYMENT`, `CARD_PAYMENT`, `INTERNATIONAL_REMITTANCE`. |

### `channels`

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `channel_id` | TEXT | PK | e.g. `CH01`. |
| `channel_name` | TEXT | UNIQUE, NN | `MOBILE_APP`, `INTERNET_BANKING`, `ATM`, `BRANCH`, `POS`, `PHONE_BANKING`. |

### `branches`

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `branch_id` | TEXT | PK | e.g. `B001`. |
| `branch_name` | TEXT | NN | |
| `city` | TEXT | NN | |
| `state` | TEXT | | Optional. |
| `country_id` | TEXT | FK → countries, NN | Branch country. |

---

## Core entities

### `customers`

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `customer_id` | TEXT | PK | e.g. `CU000001`. |
| `first_name` | TEXT | NN | |
| `middle_name` | TEXT | | Nullable; not everyone has one. |
| `last_name` | TEXT | NN | |
| `date_of_birth` | DATE | NN, CHECK ≤ current_date | Synthetic; adults in the 2025 window. |
| `email` | TEXT | | May be unknown. |
| `phone` | TEXT | | Stored as TEXT (leading `+`); never numeric. |
| `city` / `state` | TEXT | | May be unknown. |
| `country_id` | TEXT | FK → countries, NN | **Recorded** customer country (KYC). Compared with login origin. |
| `created_at` | TIMESTAMPTZ | NN | Record creation time (UTC). |

### `accounts`

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `account_id` | TEXT | PK | e.g. `AC0000001`. |
| `customer_id` | TEXT | FK → customers, NN | Owner. A customer may hold several accounts. |
| `branch_id` | TEXT | FK → branches, NN | Home branch. |
| `account_type` | TEXT | NN, CHECK ∈ {CURRENT, SAVINGS, CHECKING} | Product type. CURRENT and CHECKING both exist (UK vs US naming). |
| `currency_code` | CHAR(3) | NN, CHECK `^[A-Z]{3}$` | Independent of branch country. Geography is never inferred from currency. |
| `current_balance` | NUMERIC(18,2) | NN, CHECK ≥ 0 | Snapshot balance. NUMERIC, not FLOAT. |
| `created_at` | TIMESTAMPTZ | NN | |
| `creation_channel` | TEXT | | How the account was opened. **Not** a FK to `channels`. |
| `status` | TEXT | NN, CHECK ∈ {ACTIVE, DORMANT, SUSPENDED, CLOSED} | |

### `login_events`

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `login_id` | TEXT | PK | e.g. `LG00000001`. |
| `customer_id` | TEXT | FK → customers, NN | |
| `channel_id` | TEXT | FK → channels, NN | |
| `timestamp` | TIMESTAMPTZ | NN | Quoted identifier; name kept to match the ERD. |
| `ip_address` | TEXT | | Synthetic IPv4. |
| `origin_country_id` | TEXT | FK → countries | **NULL = unknown** geo-IP. Approximate; not proof of physical location. |
| `status` | TEXT | NN, CHECK ∈ {SUCCESS, FAILED} | |

### `transactions` (central analytical table)

| Column | Type | Key / constraints | Description |
|---|---|---|---|
| `transaction_id` | TEXT | PK | e.g. `TX000000001`. |
| `sender_account_id` | TEXT | FK → accounts, NN | Originating account. |
| `recipient_account_id` | TEXT | FK → accounts | **NULL = external recipient** (not held at this bank). |
| `external_reference` | TEXT | | Populated iff the recipient is external. CHECK: exactly one of recipient / external_reference. |
| `transaction_type_id` | TEXT | FK → transaction_types, NN | |
| `channel_id` | TEXT | FK → channels, NN | |
| `sending_amount` | NUMERIC(18,2) | NN, CHECK > 0 | In `sending_currency`. |
| `sending_currency` | CHAR(3) | NN, CHECK ISO-3 | |
| `receiving_amount` | NUMERIC(18,2) | NN, CHECK > 0 | In `receiving_currency`. |
| `receiving_currency` | CHAR(3) | NN, CHECK ISO-3 | |
| `exchange_rate` | NUMERIC(18,8) | CHECK NULL or > 0 | **NULL when sending = receiving currency.** |
| `created_at` | TIMESTAMPTZ | NN | |
| `origin_country_id` | TEXT | FK → countries, NN | Explicit origination geography. |
| `destination_country_id` | TEXT | FK → countries | **NULL = external/unknown destination.** Never inferred from currency. |
| `status` | TEXT | NN, CHECK ∈ {COMPLETED, FAILED, PENDING, REVERSED} | |

CHECK also forbids `sender_account_id = recipient_account_id`.
