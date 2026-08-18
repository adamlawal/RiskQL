# data/processed/

Generated (synthetic) CSVs land here:

- `customers.csv`
- `accounts.csv`
- `login_events.csv`
- `transactions.csv`

These files are **git-ignored** because they are fully reproducible. Regenerate
them at any time with:

    python src/generate_data.py

They are then loaded into PostgreSQL with:

    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/load_data.sql

The data is synthetic and fictitious — see `data/raw/README.md`.
