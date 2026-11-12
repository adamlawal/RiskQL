# Processed data

CSV files in this directory are **generated** by:

```bash
python src/generate_data.py
```

They are git-ignored. Re-run the generator (seed `42`) to reproduce them
exactly, then load with `sql/load_data.sql`.

| File | Loaded into |
|---|---|
| `customers.csv` | `customers` |
| `accounts.csv` | `accounts` |
| `login_events.csv` | `login_events` |
| `transactions.csv` | `transactions` |

Reference tables (`countries`, `transaction_types`, `channels`, `branches`)
are loaded from `sql/seeds/`, not from CSV.
