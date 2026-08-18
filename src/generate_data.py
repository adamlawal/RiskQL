#!/usr/bin/env python3
"""
generate_data.py — Synthetic data generator for the RiskQL project.

WHAT THIS IS
------------
This script generates CLEARLY SYNTHETIC, fictitious banking-style data for the
RiskQL portfolio project. The data is produced by this program using Python's
`random` module with a fixed seed. It is NOT real banking data, it does not come
from Kaggle or any other external source, and it does not represent any real
person, account, transaction, or institution.

WHY SYNTHETIC
-------------
The RiskQL conceptual model requires several dimensions that no single public
dataset provides cleanly together (cross-border transaction corridors,
login-origin geography vs. recorded customer geography, per-channel/per-type
failure statuses, etc.). A seeded generator lets the whole project be
reproduced offline and deterministically, which is exactly what a portfolio
reviewer needs.

The generator deliberately injects a few *interpretable* risk patterns (some
channels/types fail more often, a small set of high-frequency and high-value
accounts, a minority of logins from a country other than the customer's
recorded country). These are analytical patterns to be *detected* by the SQL /
Python analysis — they are not labelled "fraud".

OUTPUT
------
CSV files (with headers) written to data/processed/:
    customers.csv, accounts.csv, login_events.csv, transactions.csv

Reference tables (countries, transaction_types, channels, branches) are NOT
generated here — they live in sql/seeds/ and this generator uses the SAME ids.

Run:
    python src/generate_data.py
"""

from __future__ import annotations

import csv
import os
import random
from datetime import datetime, timedelta, timezone

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
SEED = 42                      # fixed seed => deterministic, reproducible output
N_CUSTOMERS = 2000
N_LOGIN_EVENTS = 15000
N_TRANSACTIONS = 40000

# Time window for generated activity (UTC).
ACTIVITY_START = datetime(2025, 1, 1, tzinfo=timezone.utc)
ACTIVITY_END = datetime(2025, 12, 31, 23, 59, 59, tzinfo=timezone.utc)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "processed")

# --------------------------------------------------------------------------- #
# Reference sets — MUST match sql/seeds/*.sql exactly.
# --------------------------------------------------------------------------- #
COUNTRIES = [f"C{n:03d}" for n in range(1, 16)]           # C001..C015
BRANCHES = [f"B{n:03d}" for n in range(1, 13)]            # B001..B012
# Branch -> country (matches sql/seeds/branches.sql).
BRANCH_COUNTRY = {
    "B001": "C001", "B002": "C001", "B003": "C001", "B004": "C002",
    "B005": "C003", "B006": "C004", "B007": "C005", "B008": "C006",
    "B009": "C007", "B010": "C008", "B011": "C010", "B012": "C011",
}
TXN_TYPES = ["TT01", "TT02", "TT03", "TT04", "TT05", "TT06"]
CHANNELS = ["CH01", "CH02", "CH03", "CH04", "CH05", "CH06"]

ACCOUNT_TYPES = ["CURRENT", "SAVINGS", "CHECKING"]
ACCOUNT_STATUSES = ["ACTIVE", "DORMANT", "SUSPENDED", "CLOSED"]

# Primary currency per country. The bank still lets an account hold any
# currency, so account currency is chosen independently below — we never infer a
# country's geography from a currency (or vice versa).
COUNTRY_CURRENCY = {
    "C001": "NGN", "C002": "GHS", "C003": "USD", "C004": "GBP", "C005": "KES",
    "C006": "ZAR", "C007": "CAD", "C008": "EUR", "C009": "EUR", "C010": "AED",
    "C011": "INR", "C012": "CNY", "C013": "EGP", "C014": "BRL", "C015": "AUD",
}
# Approximate value of 1 currency unit in USD (illustrative constants only).
CURRENCY_USD = {
    "NGN": 0.00065, "GHS": 0.083, "USD": 1.0, "GBP": 1.27, "KES": 0.0077,
    "ZAR": 0.055, "CAD": 0.73, "EUR": 1.08, "AED": 0.27, "INR": 0.012,
    "CNY": 0.14, "EGP": 0.021, "BRL": 0.20, "AUD": 0.66,
}
ALL_CURRENCIES = list(CURRENCY_USD.keys())

# Per-channel baseline transaction failure probability (interpretable pattern:
# self-service/remote channels fail a little more; staffed branch fails least).
CHANNEL_FAIL_P = {
    "CH01": 0.06,  # MOBILE_APP
    "CH02": 0.09,  # INTERNET_BANKING
    "CH03": 0.07,  # ATM
    "CH04": 0.02,  # BRANCH
    "CH05": 0.11,  # POS
    "CH06": 0.05,  # PHONE_BANKING
}
# Additional failure probability by transaction type (remittances fail more).
TYPE_FAIL_BONUS = {
    "TT01": 0.00, "TT02": 0.00, "TT03": 0.01,
    "TT04": 0.02, "TT05": 0.02, "TT06": 0.06,   # TT06 = INTERNATIONAL_REMITTANCE
}

FIRST_NAMES = [
    "Ada", "Ben", "Chidi", "Dara", "Emeka", "Fatima", "Grace", "Hassan",
    "Ifeoma", "James", "Kwame", "Lola", "Musa", "Ngozi", "Omar", "Priya",
    "Quinn", "Ravi", "Sara", "Tunde", "Uche", "Victor", "Wei", "Yara", "Zara",
]
LAST_NAMES = [
    "Okafor", "Mensah", "Smith", "Jones", "Otieno", "Naidoo", "Brown",
    "Mueller", "Dubois", "Al-Farsi", "Sharma", "Chen", "Hassan", "Silva",
    "Nguyen", "Adeyemi", "Owusu", "Ibrahim", "Kimani", "Patel",
]

CALLING_CODE = {
    "C001": "+234", "C002": "+233", "C003": "+1", "C004": "+44", "C005": "+254",
    "C006": "+27", "C007": "+1", "C008": "+49", "C009": "+33", "C010": "+971",
    "C011": "+91", "C012": "+86", "C013": "+20", "C014": "+55", "C015": "+61",
}


def rand_dt(start: datetime, end: datetime) -> datetime:
    """Uniform random datetime in [start, end]."""
    delta = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, delta))


def iso(dt: datetime) -> str:
    """ISO 8601 with UTC offset, suitable for COPY into TIMESTAMPTZ."""
    return dt.isoformat()


def weighted_country(rng: random.Random) -> str:
    """Country picker skewed toward the branch countries (more activity there)."""
    # Countries with branches get higher weight; others are still possible.
    weights = []
    branch_countries = set(BRANCH_COUNTRY.values())
    for c in COUNTRIES:
        weights.append(5.0 if c in branch_countries else 1.0)
    return rng.choices(COUNTRIES, weights=weights, k=1)[0]


def main() -> None:
    rng = random.Random(SEED)
    os.makedirs(OUT_DIR, exist_ok=True)

    # ----------------------------------------------------------------- #
    # Customers
    # ----------------------------------------------------------------- #
    customers = []
    for i in range(1, N_CUSTOMERS + 1):
        cust_id = f"CU{i:06d}"
        country = weighted_country(rng)
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        has_middle = rng.random() < 0.4
        middle = rng.choice(FIRST_NAMES) if has_middle else ""
        # Adults only: DOB roughly 1963-2001 => aged ~24-62 during the 2025 window.
        dob = datetime(1985, 1, 1) + timedelta(days=rng.randint(-8000, 6000))
        email = f"{first.lower()}.{last.lower()}{i}@example.com" if rng.random() < 0.9 else ""
        phone = f"{CALLING_CODE[country]}{rng.randint(1000000, 9999999):07d}" if rng.random() < 0.95 else ""
        created = rand_dt(datetime(2020, 1, 1, tzinfo=timezone.utc), datetime(2024, 12, 31, tzinfo=timezone.utc))
        customers.append({
            "customer_id": cust_id,
            "first_name": first,
            "middle_name": middle,
            "last_name": last,
            "date_of_birth": dob.strftime("%Y-%m-%d"),
            "email": email,
            "phone": phone,
            "city": "",             # left blank (unknown) for a share of records
            "state": "",
            "country_id": country,
            "created_at": iso(created),
        })

    # ----------------------------------------------------------------- #
    # Accounts (1-3 per customer). A small subset are flagged high-frequency.
    # ----------------------------------------------------------------- #
    accounts = []
    account_country = {}     # account_id -> home country (from branch)
    account_currency = {}
    acct_seq = 0
    high_freq_accounts = set()
    for cust in customers:
        n_acc = rng.choices([1, 2, 3], weights=[0.55, 0.33, 0.12], k=1)[0]
        # Prefer a branch in the customer's own country when one exists.
        home_branches = [b for b in BRANCHES if BRANCH_COUNTRY[b] == cust["country_id"]]
        for _ in range(n_acc):
            acct_seq += 1
            acct_id = f"AC{acct_seq:07d}"
            branch = rng.choice(home_branches) if home_branches and rng.random() < 0.8 else rng.choice(BRANCHES)
            branch_country = BRANCH_COUNTRY[branch]
            # Account currency: usually the branch-country primary currency,
            # sometimes a foreign currency (multi-currency accounts exist).
            if rng.random() < 0.85:
                currency = COUNTRY_CURRENCY[branch_country]
            else:
                currency = rng.choice(ALL_CURRENCIES)
            status = rng.choices(ACCOUNT_STATUSES, weights=[0.80, 0.12, 0.03, 0.05], k=1)[0]
            balance = round(rng.lognormvariate(8.5, 1.3), 2)   # skewed, positive
            created = rand_dt(datetime(2020, 6, 1, tzinfo=timezone.utc), datetime(2024, 12, 31, tzinfo=timezone.utc))
            accounts.append({
                "account_id": acct_id,
                "customer_id": cust["customer_id"],
                "branch_id": branch,
                "account_type": rng.choice(ACCOUNT_TYPES),
                "currency_code": currency,
                "current_balance": f"{balance:.2f}",
                "created_at": iso(created),
                "creation_channel": rng.choice(["MOBILE_APP", "BRANCH", "INTERNET_BANKING", ""]),
                "status": status,
            })
            account_country[acct_id] = branch_country
            account_currency[acct_id] = currency

    # Flag ~1.5% of active accounts as high-frequency senders.
    active_accounts = [a["account_id"] for a in accounts if a["status"] == "ACTIVE"]
    n_hf = max(1, int(0.015 * len(active_accounts)))
    high_freq_accounts = set(rng.sample(active_accounts, n_hf))

    cust_country = {c["customer_id"]: c["country_id"] for c in customers}
    # Active accounts grouped by home (branch) country, for same-country routing.
    accounts_by_country: dict[str, list[str]] = {}
    for a in accounts:
        if a["status"] == "ACTIVE":
            accounts_by_country.setdefault(account_country[a["account_id"]], []).append(a["account_id"])

    # ----------------------------------------------------------------- #
    # Login events. ~10% fail overall; a minority originate from a country
    # different from the customer's recorded country (geo mismatch indicator).
    # ----------------------------------------------------------------- #
    logins = []
    customer_ids = [c["customer_id"] for c in customers]
    # A subset of customers have elevated login-failure behaviour.
    high_fail_customers = set(rng.sample(customer_ids, int(0.05 * len(customer_ids))))
    for i in range(1, N_LOGIN_EVENTS + 1):
        login_id = f"LG{i:08d}"
        cust = rng.choice(customer_ids)
        recorded_country = cust_country[cust]
        # Geo: mostly the recorded country; ~8% from elsewhere.
        if rng.random() < 0.08:
            origin = rng.choice([c for c in COUNTRIES if c != recorded_country])
        else:
            origin = recorded_country
        # ~3% have unknown origin country (missing geo-IP).
        origin_val = "" if rng.random() < 0.03 else origin
        fail_p = 0.28 if cust in high_fail_customers else 0.07
        status = "FAILED" if rng.random() < fail_p else "SUCCESS"
        ip = f"{rng.randint(11, 223)}.{rng.randint(0,255)}.{rng.randint(0,255)}.{rng.randint(1,254)}"
        logins.append({
            "login_id": login_id,
            "customer_id": cust,
            "channel_id": rng.choices(CHANNELS, weights=[0.45, 0.30, 0.05, 0.05, 0.05, 0.10], k=1)[0],
            "timestamp": iso(rand_dt(ACTIVITY_START, ACTIVITY_END)),
            "ip_address": ip,
            "origin_country_id": origin_val,
            "status": status,
        })

    # ----------------------------------------------------------------- #
    # Transactions. High-frequency accounts get an outsized share of the
    # transaction volume. ~20% are cross-border. Failure probability depends on
    # channel and type.
    # ----------------------------------------------------------------- #
    transactions = []
    if not active_accounts:
        raise RuntimeError("No active accounts generated; cannot create transactions.")

    # Build a weighted sender pool: high-frequency accounts weighted much higher.
    sender_pool = list(active_accounts)
    sender_weights = [12.0 if a in high_freq_accounts else 1.0 for a in sender_pool]

    for i in range(1, N_TRANSACTIONS + 1):
        txn_id = f"TX{i:09d}"
        sender = rng.choices(sender_pool, weights=sender_weights, k=1)[0]
        send_currency = account_currency[sender]
        origin_country = account_country[sender]
        # Occasionally the transaction originates from a different country
        # (e.g. customer travelling) -> still explicit, never inferred.
        if rng.random() < 0.05:
            origin_country = rng.choice(COUNTRIES)

        txn_type = rng.choices(TXN_TYPES, weights=[0.30, 0.15, 0.15, 0.15, 0.15, 0.10], k=1)[0]
        channel = rng.choices(CHANNELS, weights=[0.40, 0.20, 0.12, 0.10, 0.13, 0.05], k=1)[0]

        # Decide cross-border up front (~18% target). Cross-border means the
        # destination country differs from the origin country. Geography stays
        # explicit and is never inferred from currency.
        cross_border = rng.random() < 0.18
        same_country_pool = [a for a in accounts_by_country.get(origin_country, []) if a != sender]

        # Recipient: ~55% internal (another account), else external.
        internal = rng.random() < 0.55
        if internal:
            if not cross_border and same_country_pool:
                recipient = rng.choice(same_country_pool)
            else:
                # Cross-border (or no same-country account): recipient elsewhere.
                recipient = rng.choice(active_accounts)
                guard = 0
                while (recipient == sender or
                       (cross_border and account_country[recipient] == origin_country)) and guard < 20:
                    recipient = rng.choice(active_accounts)
                    guard += 1
            recipient_val = recipient
            dest_country = account_country[recipient]
            recv_currency = account_currency[recipient]
            external_ref = ""
        else:
            recipient_val = ""      # external recipient -> NULL
            # Unique external reference (embeds the txn sequence to avoid collisions).
            external_ref = f"EXT-{i:09d}"
            if not cross_border:
                dest_country = origin_country            # domestic external payment
            elif rng.random() < 0.80:
                dest_country = rng.choice([c for c in COUNTRIES if c != origin_country])
            else:
                dest_country = ""    # unknown external destination -> NULL
            recv_currency = rng.choice(ALL_CURRENCIES) if dest_country == "" \
                else COUNTRY_CURRENCY.get(dest_country, "USD")

        # Amount: lognormal (skewed, occasional very large values).
        send_amount = round(rng.lognormvariate(6.2, 1.15), 2)
        if send_amount <= 0:
            send_amount = 1.00

        # Exchange rate + receiving amount.
        if recv_currency == send_currency:
            exchange_rate = ""      # NULL when same currency
            recv_amount = send_amount
        else:
            rate = CURRENCY_USD[send_currency] / CURRENCY_USD[recv_currency]
            exchange_rate = f"{rate:.8f}"
            recv_amount = round(send_amount * rate, 2)
            if recv_amount <= 0:
                recv_amount = 0.01

        # Status: base failure by channel + type bonus.
        fail_p = CHANNEL_FAIL_P[channel] + TYPE_FAIL_BONUS[txn_type]
        r = rng.random()
        if r < fail_p:
            status = "FAILED"
        elif r < fail_p + 0.02:
            status = "PENDING"
        elif r < fail_p + 0.03:
            status = "REVERSED"
        else:
            status = "COMPLETED"

        transactions.append({
            "transaction_id": txn_id,
            "sender_account_id": sender,
            "recipient_account_id": recipient_val,
            "external_reference": external_ref,
            "transaction_type_id": txn_type,
            "channel_id": channel,
            "sending_amount": f"{send_amount:.2f}",
            "sending_currency": send_currency,
            "receiving_amount": f"{recv_amount:.2f}",
            "receiving_currency": recv_currency,
            "exchange_rate": exchange_rate,
            "created_at": iso(rand_dt(ACTIVITY_START, ACTIVITY_END)),
            "origin_country_id": origin_country,
            "destination_country_id": dest_country,
            "status": status,
        })

    # ----------------------------------------------------------------- #
    # Write CSVs
    # ----------------------------------------------------------------- #
    def write_csv(name, rows, fieldnames):
        path = os.path.join(OUT_DIR, name)
        with open(path, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=fieldnames)
            w.writeheader()
            w.writerows(rows)
        print(f"  wrote {len(rows):>6} rows -> data/processed/{name}")

    print("Generating synthetic RiskQL data (seed=%d)..." % SEED)
    write_csv("customers.csv", customers, list(customers[0].keys()))
    write_csv("accounts.csv", accounts, list(accounts[0].keys()))
    write_csv("login_events.csv", logins, list(logins[0].keys()))
    write_csv("transactions.csv", transactions, list(transactions[0].keys()))

    # Small summary for sanity.
    n_fail = sum(1 for t in transactions if t["status"] == "FAILED")
    n_xborder = sum(1 for t in transactions
                    if t["destination_country_id"] not in ("", t["origin_country_id"]))
    print("Summary:")
    print(f"  customers={len(customers)} accounts={len(accounts)} "
          f"logins={len(logins)} transactions={len(transactions)}")
    print(f"  high-frequency accounts flagged: {len(high_freq_accounts)}")
    print(f"  transaction failure rate: {n_fail/len(transactions):.1%}")
    print(f"  cross-border transactions: {n_xborder/len(transactions):.1%}")
    print("Done. This data is SYNTHETIC and for portfolio/learning use only.")


if __name__ == "__main__":
    main()
