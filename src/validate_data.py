#!/usr/bin/env python3
"""
validate_data.py: Python companion to sql/checks/data_quality.sql.

Runs a subset of the same integrity rules through SQLAlchemy so the project
demonstrates SQL *and* Python validation. Prints a PASS/FAIL table.

    python src/validate_data.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sqlalchemy import text

from db import get_engine

CHECKS = [
    (
        "PK uniqueness: transactions",
        "ERROR",
        "SELECT count(*) FROM (SELECT transaction_id FROM transactions "
        "GROUP BY transaction_id HAVING count(*) > 1) d",
    ),
    (
        "Orphan sender accounts",
        "ERROR",
        "SELECT count(*) FROM transactions t LEFT JOIN accounts a "
        "ON a.account_id = t.sender_account_id WHERE a.account_id IS NULL",
    ),
    (
        "Sending amount <= 0",
        "ERROR",
        "SELECT count(*) FROM transactions WHERE sending_amount <= 0",
    ),
    (
        "Negative account balances",
        "ERROR",
        "SELECT count(*) FROM accounts WHERE current_balance < 0",
    ),
    (
        "Invalid transaction status",
        "ERROR",
        "SELECT count(*) FROM transactions WHERE status NOT IN "
        "('COMPLETED','FAILED','PENDING','REVERSED')",
    ),
    (
        "Self-transfers",
        "ERROR",
        "SELECT count(*) FROM transactions WHERE recipient_account_id IS NOT NULL "
        "AND recipient_account_id = sender_account_id",
    ),
    (
        "Recipient XOR external_reference",
        "ERROR",
        "SELECT count(*) FROM transactions WHERE NOT ("
        "(recipient_account_id IS NOT NULL AND external_reference IS NULL) OR "
        "(recipient_account_id IS NULL AND external_reference IS NOT NULL))",
    ),
    (
        "Invalid ISO currency on accounts",
        "ERROR",
        "SELECT count(*) FROM accounts WHERE currency_code !~ '^[A-Z]{3}$'",
    ),
    (
        "Duplicate external_reference",
        "WARN",
        "SELECT COALESCE(sum(cnt - 1), 0) FROM ("
        "SELECT external_reference, count(*) AS cnt FROM transactions "
        "WHERE external_reference IS NOT NULL GROUP BY external_reference "
        "HAVING count(*) > 1) d",
    ),
    (
        "Future dates of birth",
        "ERROR",
        "SELECT count(*) FROM customers WHERE date_of_birth > CURRENT_DATE",
    ),
]


def main() -> int:
    engine = get_engine()
    rows = []
    with engine.connect() as conn:
        for name, severity, sql in CHECKS:
            n = conn.execute(text(sql)).scalar_one()
            status = "PASS" if n == 0 else "FAIL"
            rows.append((name, severity, int(n), status))

    print(f"{'check':<42} {'sev':<6} {'n':>6}  status")
    print("-" * 66)
    error_fails = 0
    for name, severity, n, status in rows:
        print(f"{name:<42} {severity:<6} {n:>6}  {status}")
        if status == "FAIL" and severity == "ERROR":
            error_fails += 1

    print()
    if error_fails == 0:
        print("All ERROR-severity Python checks PASSED.")
        return 0
    print(f"{error_fails} ERROR-severity check(s) FAILED.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
