"""
db.py — small helper for connecting to the RiskQL PostgreSQL database.

Credentials are read from the environment (a git-ignored `.env` file), never
hard-coded. See `.env.example` for the expected variables.

Resolution order for the connection string:
    1. DATABASE_URL, if set.
    2. Otherwise build one from PGHOST / PGPORT / PGDATABASE / PGUSER / PGPASSWORD.
    3. Otherwise a safe local default (postgresql://localhost:5432/riskql).
"""

from __future__ import annotations

import os
from urllib.parse import quote_plus

try:
    from dotenv import load_dotenv
    load_dotenv()  # load variables from a local .env if present
except ImportError:  # dotenv is optional; env vars may be set another way
    pass


def get_database_url() -> str:
    """Return a SQLAlchemy/psycopg2-compatible connection URL from the env."""
    url = os.environ.get("DATABASE_URL")
    if url:
        return url

    host = os.environ.get("PGHOST", "localhost")
    port = os.environ.get("PGPORT", "5432")
    dbname = os.environ.get("PGDATABASE", "riskql")
    user = os.environ.get("PGUSER")
    password = os.environ.get("PGPASSWORD")

    if user and password:
        return f"postgresql://{user}:{quote_plus(password)}@{host}:{port}/{dbname}"
    if user:
        return f"postgresql://{user}@{host}:{port}/{dbname}"
    return f"postgresql://{host}:{port}/{dbname}"


def get_engine():
    """Return a SQLAlchemy engine for pandas.read_sql()."""
    from sqlalchemy import create_engine
    return create_engine(get_database_url())


if __name__ == "__main__":
    # Quick connectivity smoke test (prints server version, no secrets).
    from sqlalchemy import text
    with get_engine().connect() as conn:
        version = conn.execute(text("SELECT version()")).scalar_one()
    print("Connected OK:", version.split(" on ")[0])
