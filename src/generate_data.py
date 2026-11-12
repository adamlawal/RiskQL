#!/usr/bin/env python3
"""
generate_data.py: Synthetic data generator for RiskQL.

WHAT THIS IS
------------
This script generates CLEARLY SYNTHETIC, fictitious banking-style data. It uses
Python's `random` module with a fixed seed. It is NOT real banking data, it
does not come from Kaggle or any other external source, and it does not
represent any real person, account, transaction, or institution.

WHY SYNTHETIC
-------------
The RiskQL model needs several dimensions together that no single public
dataset provides cleanly: cross-border corridors, login-origin vs recorded
customer geography, per-channel/per-type failure statuses, currencies, and
timestamps. A seeded generator makes the project reproducible offline.

Injected (labelled as synthetic patterns, never as "fraud"):
  * Channel/type-dependent transaction failure rates.
  * A small set of high-frequency sender accounts.
  * A minority of logins from a country other than the customer's recorded country.
  * A small "watchlist" of customers with clustered failed logins followed
    shortly by unusually large transactions, so combined-indicator queries
    have a detectable, explainable signal.

OUTPUT
------
CSV files (with headers) in data/processed/:
    customers.csv, accounts.csv, login_events.csv, transactions.csv

Reference tables (countries, transaction_types, channels, branches) are NOT
generated here; they live in sql/seeds/ and this generator uses the same ids.

Run from the repository root:
    python src/generate_data.py
"""

from __future__ import annotations

import csv
import os
import random
from datetime import datetime, timedelta, timezone

SEED = 42
N_CUSTOMERS = 2000
N_LOGIN_EVENTS = 15000
N_TRANSACTIONS = 40000
N_WATCHLIST = 20  # customers with injected login-then-transaction sequences

ACTIVITY_START = datetime(2025, 1, 1, tzinfo=timezone.utc)
ACTIVITY_END = datetime(2025, 12, 31, 23, 59, 59, tzinfo=timezone.utc)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "processed")

COUNTRIES = [f"C{n:03d}" for n in range(1, 16)]
BRANCHES = [f"B{n:03d}" for n in range(1, 13)]
BRANCH_COUNTRY = {
    "B001": "C001",
    "B002": "C001",
    "B003": "C001",
    "B004": "C002",
    "B005": "C003",
    "B006": "C004",
    "B007": "C005",
    "B008": "C006",
    "B009": "C007",
    "B010": "C008",
    "B011": "C010",
    "B012": "C011",
}
TXN_TYPES = ["TT01", "TT02", "TT03", "TT04", "TT05", "TT06"]
CHANNELS = ["CH01", "CH02", "CH03", "CH04", "CH05", "CH06"]
DIGITAL_CHANNELS = ["CH01", "CH02", "CH06"]  # mobile, internet, phone

ACCOUNT_TYPES = ["CURRENT", "SAVINGS", "CHECKING"]
ACCOUNT_STATUSES = ["ACTIVE", "DORMANT", "SUSPENDED", "CLOSED"]

COUNTRY_CURRENCY = {
    "C001": "NGN",
    "C002": "GHS",
    "C003": "USD",
    "C004": "GBP",
    "C005": "KES",
    "C006": "ZAR",
    "C007": "CAD",
    "C008": "EUR",
    "C009": "EUR",
    "C010": "AED",
    "C011": "INR",
    "C012": "CNY",
    "C013": "EGP",
    "C014": "BRL",
    "C015": "AUD",
}
# Illustrative FX constants only (units of currency per 1 USD inverted below).
CURRENCY_USD = {
    "NGN": 0.00065,
    "GHS": 0.083,
    "USD": 1.0,
    "GBP": 1.27,
    "KES": 0.0077,
    "ZAR": 0.055,
    "CAD": 0.73,
    "EUR": 1.08,
    "AED": 0.27,
    "INR": 0.012,
    "CNY": 0.14,
    "EGP": 0.021,
    "BRL": 0.20,
    "AUD": 0.66,
}
ALL_CURRENCIES = list(CURRENCY_USD.keys())

CHANNEL_FAIL_P = {
    "CH01": 0.06,  # MOBILE_APP
    "CH02": 0.09,  # INTERNET_BANKING
    "CH03": 0.07,  # ATM
    "CH04": 0.02,  # BRANCH
    "CH05": 0.11,  # POS
    "CH06": 0.05,  # PHONE_BANKING
}
TYPE_FAIL_BONUS = {
    "TT01": 0.00,
    "TT02": 0.00,
    "TT03": 0.01,
    "TT04": 0.02,
    "TT05": 0.02,
    "TT06": 0.06,  # INTERNATIONAL_REMITTANCE
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
CITIES = {
    "C001": [("Lagos", "Lagos"), ("Abuja", "FCT"), ("Ibadan", "Oyo")],
    "C002": [("Accra", "Greater Accra"), ("Kumasi", "Ashanti")],
    "C003": [("New York", "New York"), ("Houston", "Texas"), ("Chicago", "Illinois")],
    "C004": [("London", "England"), ("Manchester", "England")],
    "C005": [("Nairobi", "Nairobi County"), ("Mombasa", "Mombasa")],
    "C006": [("Johannesburg", "Gauteng"), ("Cape Town", "Western Cape")],
    "C007": [("Toronto", "Ontario"), ("Vancouver", "British Columbia")],
    "C008": [("Frankfurt", "Hesse"), ("Berlin", "Berlin")],
    "C009": [("Paris", "Île-de-France"), ("Lyon", "Auvergne-Rhône-Alpes")],
    "C010": [("Dubai", "Dubai"), ("Abu Dhabi", "Abu Dhabi")],
    "C011": [("Mumbai", "Maharashtra"), ("Bengaluru", "Karnataka")],
    "C012": [("Shanghai", "Shanghai"), ("Beijing", "Beijing")],
    "C013": [("Cairo", "Cairo"), ("Alexandria", "Alexandria")],
    "C014": [("São Paulo", "São Paulo"), ("Rio de Janeiro", "Rio de Janeiro")],
    "C015": [("Sydney", "New South Wales"), ("Melbourne", "Victoria")],
}


def rand_dt(rng: random.Random, start: datetime, end: datetime) -> datetime:
    delta = int((end - start).total_seconds())
    return start + timedelta(seconds=rng.randint(0, max(delta, 0)))


def iso(dt: datetime) -> str:
    return dt.isoformat()


def weighted_country(rng: random.Random) -> str:
    branch_countries = set(BRANCH_COUNTRY.values())
    weights = [5.0 if c in branch_countries else 1.0 for c in COUNTRIES]
    return rng.choices(COUNTRIES, weights=weights, k=1)[0]


def random_ip(rng: random.Random) -> str:
    return (
        f"{rng.randint(11, 223)}.{rng.randint(0, 255)}."
        f"{rng.randint(0, 255)}.{rng.randint(1, 254)}"
    )


def write_csv(name: str, rows: list[dict], fieldnames: list[str]) -> None:
    path = os.path.join(OUT_DIR, name)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"  wrote {len(rows):>6} rows -> data/processed/{name}")


def fx_receive(send_amount: float, send_ccy: str, recv_ccy: str) -> tuple[str, float]:
    if recv_ccy == send_ccy:
        return "", send_amount
    rate = CURRENCY_USD[send_ccy] / CURRENCY_USD[recv_ccy]
    recv_amount = round(send_amount * rate, 2)
    if recv_amount <= 0:
        recv_amount = 0.01
    return f"{rate:.8f}", recv_amount


def main() -> None:
    rng = random.Random(SEED)
    os.makedirs(OUT_DIR, exist_ok=True)

    customers: list[dict] = []
    for i in range(1, N_CUSTOMERS + 1):
        cust_id = f"CU{i:06d}"
        country = weighted_country(rng)
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        middle = rng.choice(FIRST_NAMES) if rng.random() < 0.4 else ""
        dob = datetime(1985, 1, 1) + timedelta(days=rng.randint(-8000, 6000))
        email = f"{first.lower()}.{last.lower()}{i}@example.com" if rng.random() < 0.9 else ""
        phone = (
            f"{CALLING_CODE[country]}{rng.randint(1000000, 9999999):07d}"
            if rng.random() < 0.95
            else ""
        )
        if rng.random() < 0.72 and country in CITIES:
            city, state = rng.choice(CITIES[country])
        else:
            city, state = "", ""
        created = rand_dt(
            rng,
            datetime(2020, 1, 1, tzinfo=timezone.utc),
            datetime(2024, 12, 31, tzinfo=timezone.utc),
        )
        customers.append(
            {
                "customer_id": cust_id,
                "first_name": first,
                "middle_name": middle,
                "last_name": last,
                "date_of_birth": dob.strftime("%Y-%m-%d"),
                "email": email,
                "phone": phone,
                "city": city,
                "state": state,
                "country_id": country,
                "created_at": iso(created),
            }
        )

    accounts: list[dict] = []
    account_country: dict[str, str] = {}
    account_currency: dict[str, str] = {}
    accounts_by_customer: dict[str, list[str]] = {}
    acct_seq = 0
    for cust in customers:
        n_acc = rng.choices([1, 2, 3], weights=[0.55, 0.33, 0.12], k=1)[0]
        home_branches = [b for b in BRANCHES if BRANCH_COUNTRY[b] == cust["country_id"]]
        for _ in range(n_acc):
            acct_seq += 1
            acct_id = f"AC{acct_seq:07d}"
            branch = (
                rng.choice(home_branches)
                if home_branches and rng.random() < 0.8
                else rng.choice(BRANCHES)
            )
            branch_country = BRANCH_COUNTRY[branch]
            if rng.random() < 0.85:
                currency = COUNTRY_CURRENCY[branch_country]
            else:
                currency = rng.choice(ALL_CURRENCIES)
            status = rng.choices(ACCOUNT_STATUSES, weights=[0.80, 0.12, 0.03, 0.05], k=1)[0]
            balance = round(rng.lognormvariate(8.5, 1.3), 2)
            created = rand_dt(
                rng,
                datetime(2020, 6, 1, tzinfo=timezone.utc),
                datetime(2024, 12, 31, tzinfo=timezone.utc),
            )
            accounts.append(
                {
                    "account_id": acct_id,
                    "customer_id": cust["customer_id"],
                    "branch_id": branch,
                    "account_type": rng.choice(ACCOUNT_TYPES),
                    "currency_code": currency,
                    "current_balance": f"{balance:.2f}",
                    "created_at": iso(created),
                    "creation_channel": rng.choice(
                        ["MOBILE_APP", "BRANCH", "INTERNET_BANKING", ""]
                    ),
                    "status": status,
                }
            )
            account_country[acct_id] = branch_country
            account_currency[acct_id] = currency
            accounts_by_customer.setdefault(cust["customer_id"], []).append(acct_id)

    active_accounts = [a["account_id"] for a in accounts if a["status"] == "ACTIVE"]
    n_hf = max(1, int(0.015 * len(active_accounts)))
    high_freq_accounts = set(rng.sample(active_accounts, n_hf))

    cust_country = {c["customer_id"]: c["country_id"] for c in customers}
    accounts_by_country: dict[str, list[str]] = {}
    for acct in accounts:
        if acct["status"] == "ACTIVE":
            accounts_by_country.setdefault(account_country[acct["account_id"]], []).append(
                acct["account_id"]
            )

    logins: list[dict] = []
    customer_ids = [c["customer_id"] for c in customers]
    high_fail_customers = set(rng.sample(customer_ids, int(0.05 * len(customer_ids))))
    for i in range(1, N_LOGIN_EVENTS + 1):
        cust = rng.choice(customer_ids)
        recorded_country = cust_country[cust]
        if rng.random() < 0.08:
            origin = rng.choice([c for c in COUNTRIES if c != recorded_country])
        else:
            origin = recorded_country
        origin_val = "" if rng.random() < 0.03 else origin
        fail_p = 0.28 if cust in high_fail_customers else 0.07
        status = "FAILED" if rng.random() < fail_p else "SUCCESS"
        logins.append(
            {
                "login_id": f"LG{i:08d}",
                "customer_id": cust,
                "channel_id": rng.choices(
                    CHANNELS, weights=[0.45, 0.30, 0.05, 0.05, 0.05, 0.10], k=1
                )[0],
                "timestamp": iso(rand_dt(rng, ACTIVITY_START, ACTIVITY_END)),
                "ip_address": random_ip(rng),
                "origin_country_id": origin_val,
                "status": status,
            }
        )

    transactions: list[dict] = []
    if not active_accounts:
        raise RuntimeError("No active accounts generated; cannot create transactions.")

    sender_pool = list(active_accounts)
    sender_weights = [12.0 if a in high_freq_accounts else 1.0 for a in sender_pool]

    for i in range(1, N_TRANSACTIONS + 1):
        sender = rng.choices(sender_pool, weights=sender_weights, k=1)[0]
        send_currency = account_currency[sender]
        origin_country = account_country[sender]
        if rng.random() < 0.05:
            origin_country = rng.choice(COUNTRIES)

        txn_type = rng.choices(TXN_TYPES, weights=[0.30, 0.15, 0.15, 0.15, 0.15, 0.10], k=1)[0]
        channel = rng.choices(CHANNELS, weights=[0.40, 0.20, 0.12, 0.10, 0.13, 0.05], k=1)[0]
        cross_border = rng.random() < 0.18
        same_country_pool = [a for a in accounts_by_country.get(origin_country, []) if a != sender]

        internal = rng.random() < 0.55
        if internal:
            if not cross_border and same_country_pool:
                recipient = rng.choice(same_country_pool)
            else:
                recipient = rng.choice(active_accounts)
                guard = 0
                while (
                    recipient == sender
                    or (cross_border and account_country[recipient] == origin_country)
                ) and guard < 20:
                    recipient = rng.choice(active_accounts)
                    guard += 1
                if recipient == sender:
                    # Fall back to an external payment rather than a self-transfer.
                    internal = False
            if internal:
                recipient_val = recipient
                dest_country = account_country[recipient]
                recv_currency = account_currency[recipient]
                external_ref = ""
        if not internal:
            recipient_val = ""
            external_ref = f"EXT-{i:09d}"
            if not cross_border:
                dest_country = origin_country
            elif rng.random() < 0.80:
                dest_country = rng.choice([c for c in COUNTRIES if c != origin_country])
            else:
                dest_country = ""
            recv_currency = (
                rng.choice(ALL_CURRENCIES)
                if dest_country == ""
                else COUNTRY_CURRENCY.get(dest_country, "USD")
            )

        send_amount = round(rng.lognormvariate(6.2, 1.15), 2)
        if send_amount <= 0:
            send_amount = 1.00
        exchange_rate, recv_amount = fx_receive(send_amount, send_currency, recv_currency)

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

        transactions.append(
            {
                "transaction_id": f"TX{i:09d}",
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
                "created_at": iso(rand_dt(rng, ACTIVITY_START, ACTIVITY_END)),
                "origin_country_id": origin_country,
                "destination_country_id": dest_country,
                "status": status,
            }
        )

    # ------------------------------------------------------------------ #
    # Watchlist: clustered failed logins, then large transactions.
    # These extra rows are appended so the combined-indicator queries have
    # a known, reproducible signal without rewriting the bulk population.
    # ------------------------------------------------------------------ #
    watch_candidates = [
        cid
        for cid in customer_ids
        if any(a in active_accounts for a in accounts_by_customer.get(cid, []))
    ]
    watchlist = rng.sample(watch_candidates, N_WATCHLIST)
    login_seq = N_LOGIN_EVENTS
    txn_seq = N_TRANSACTIONS

    for cust_id in watchlist:
        sender = next(
            a for a in accounts_by_customer[cust_id] if a in set(active_accounts)
        )
        recorded = cust_country[cust_id]
        foreign = rng.choice([c for c in COUNTRIES if c != recorded])
        # Keep the burst inside the activity window.
        burst_end = rand_dt(
            rng,
            ACTIVITY_START + timedelta(days=30),
            ACTIVITY_END - timedelta(days=7),
        )
        n_fails = rng.randint(5, 8)
        for k in range(n_fails):
            login_seq += 1
            ts = burst_end - timedelta(minutes=15 * (n_fails - k) + rng.randint(0, 8))
            logins.append(
                {
                    "login_id": f"LG{login_seq:08d}",
                    "customer_id": cust_id,
                    "channel_id": rng.choice(DIGITAL_CHANNELS),
                    "timestamp": iso(ts),
                    "ip_address": random_ip(rng),
                    "origin_country_id": foreign,
                    "status": "FAILED",
                }
            )
        login_seq += 1
        logins.append(
            {
                "login_id": f"LG{login_seq:08d}",
                "customer_id": cust_id,
                "channel_id": "CH01",
                "timestamp": iso(burst_end - timedelta(minutes=12)),
                "ip_address": random_ip(rng),
                "origin_country_id": foreign,
                "status": "SUCCESS",
            }
        )
        send_currency = account_currency[sender]
        for k in range(rng.randint(2, 4)):
            txn_seq += 1
            send_amount = round(rng.lognormvariate(9.8, 0.35), 2)
            if send_amount < 5000:
                send_amount = round(5000 + rng.random() * 20000, 2)
            dest_country = foreign
            recv_currency = COUNTRY_CURRENCY[dest_country]
            exchange_rate, recv_amount = fx_receive(send_amount, send_currency, recv_currency)
            created = burst_end + timedelta(minutes=20 + 35 * k + rng.randint(0, 10))
            transactions.append(
                {
                    "transaction_id": f"TX{txn_seq:09d}",
                    "sender_account_id": sender,
                    "recipient_account_id": "",
                    "external_reference": f"EXT-{txn_seq:09d}",
                    "transaction_type_id": "TT06",
                    "channel_id": "CH01",
                    "sending_amount": f"{send_amount:.2f}",
                    "sending_currency": send_currency,
                    "receiving_amount": f"{recv_amount:.2f}",
                    "receiving_currency": recv_currency,
                    "exchange_rate": exchange_rate,
                    "created_at": iso(created),
                    "origin_country_id": foreign,
                    "destination_country_id": dest_country,
                    "status": "COMPLETED",
                }
            )

    print(f"Generating synthetic RiskQL data (seed={SEED})...")
    write_csv("customers.csv", customers, list(customers[0].keys()))
    write_csv("accounts.csv", accounts, list(accounts[0].keys()))
    write_csv("login_events.csv", logins, list(logins[0].keys()))
    write_csv("transactions.csv", transactions, list(transactions[0].keys()))

    n_fail = sum(1 for t in transactions if t["status"] == "FAILED")
    n_xborder = sum(
        1
        for t in transactions
        if t["destination_country_id"] not in ("", t["origin_country_id"])
    )
    print("Summary:")
    print(
        f"  customers={len(customers)} accounts={len(accounts)} "
        f"logins={len(logins)} transactions={len(transactions)}"
    )
    print(f"  high-frequency accounts flagged: {len(high_freq_accounts)}")
    print(f"  watchlist customers (injected sequences): {len(watchlist)}")
    print(f"  transaction failure rate: {n_fail / len(transactions):.1%}")
    print(f"  cross-border transactions: {n_xborder / len(transactions):.1%}")
    print("Done. This data is SYNTHETIC and for portfolio/learning use only.")


if __name__ == "__main__":
    main()
