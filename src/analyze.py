#!/usr/bin/env python3
"""
analyze.py: pull RiskQL tables, compute descriptive stats, export charts.

Figures land in reports/figures/. A compact metrics JSON is written to
reports/_metrics.json for the written report (numbers come from the database,
not from invented values).

    python src/analyze.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db import get_engine

ROOT = Path(__file__).resolve().parents[1]
FIG_DIR = ROOT / "reports" / "figures"
METRICS_PATH = ROOT / "reports" / "_metrics.json"


def load_tables(engine):
    tables = {}
    for name in (
        "countries",
        "customers",
        "branches",
        "accounts",
        "transaction_types",
        "channels",
        "login_events",
        "transactions",
    ):
        tables[name] = pd.read_sql(text(f"SELECT * FROM {name}"), engine)
    return tables


def main() -> None:
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    sns.set_theme(style="whitegrid", context="talk")

    engine = get_engine()
    t = load_tables(engine)
    txn = t["transactions"]
    ch = t["channels"]
    tt = t["transaction_types"]
    co = t["countries"]
    acc = t["accounts"]
    logins = t["login_events"]
    cust = t["customers"]

    txn = txn.merge(ch, on="channel_id", how="left")
    txn = txn.merge(tt, left_on="transaction_type_id", right_on="type_id", how="left")
    txn["is_failed"] = txn["status"].eq("FAILED")
    txn["is_xborder"] = (
        txn["destination_country_id"].notna()
        & (txn["destination_country_id"] != txn["origin_country_id"])
    )
    sending = pd.to_numeric(txn["sending_amount"], errors="coerce")

    fail_rate = float(txn["is_failed"].mean())
    xborder_rate = float(txn["is_xborder"].mean())
    login_fail = float(logins["status"].eq("FAILED").mean())

    by_ch = (
        txn.groupby("channel_name")
        .agg(n=("transaction_id", "count"), fail=("is_failed", "mean"))
        .reset_index()
        .sort_values("fail", ascending=False)
    )
    by_type = (
        txn.groupby("type_name")
        .agg(n=("transaction_id", "count"), fail=("is_failed", "mean"))
        .reset_index()
        .sort_values("fail", ascending=False)
    )
    origin = (
        txn.merge(co, left_on="origin_country_id", right_on="country_id", how="left")
        .groupby("country_name")
        .size()
        .sort_values(ascending=False)
    )
    geo = pd.Series(
        {
            "domestic": int(
                (
                    txn["destination_country_id"].notna()
                    & (txn["destination_country_id"] == txn["origin_country_id"])
                ).sum()
            ),
            "cross-border": int(txn["is_xborder"].sum()),
            "unknown dest": int(txn["destination_country_id"].isna().sum()),
        }
    )

    # 01 channel volume + failure
    fig, ax1 = plt.subplots(figsize=(10, 5.5))
    ax2 = ax1.twinx()
    order = by_ch["channel_name"]
    sns.barplot(data=by_ch, x="channel_name", y="n", ax=ax1, color="#4C78A8", order=order)
    ax2.plot(range(len(by_ch)), by_ch["fail"] * 100, color="#E45756", marker="o")
    ax1.set_ylabel("Transaction count")
    ax2.set_ylabel("Failure rate (%)")
    ax1.set_xlabel("")
    ax1.set_title("Transaction volume and failure rate by channel")
    plt.xticks(rotation=25, ha="right")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "01_channel_volume_failure.png", dpi=140)
    plt.close()

    # 02 type failure
    fig, ax = plt.subplots(figsize=(9, 5))
    sns.barplot(data=by_type, x="type_name", y="fail", ax=ax, color="#F58518")
    ax.set_ylabel("Failure rate")
    ax.set_xlabel("")
    ax.set_title("Transaction failure rate by type")
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, _: f"{v:.0%}"))
    plt.xticks(rotation=25, ha="right")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "02_type_failure.png", dpi=140)
    plt.close()

    # 03 origin country
    fig, ax = plt.subplots(figsize=(9, 6))
    origin.head(12).iloc[::-1].plot(kind="barh", ax=ax, color="#54A24B")
    ax.set_xlabel("Transactions originated")
    ax.set_ylabel("")
    ax.set_title("Transaction volume by origin country")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "03_country_activity.png", dpi=140)
    plt.close()

    # 04 cross-border split
    fig, ax = plt.subplots(figsize=(7, 7))
    ax.pie(geo.values, labels=geo.index, autopct="%1.1f%%", startangle=90)
    ax.set_title("Domestic vs cross-border vs unknown destination")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "04_cross_border_split.png", dpi=140)
    plt.close()

    # 05 value distribution (log)
    fig, ax = plt.subplots(figsize=(9, 5))
    sns.histplot(sending[sending > 0], bins=60, log_scale=True, ax=ax, color="#4C78A8")
    ax.axvline(sending.median(), color="#E45756", linestyle="--", label="median")
    ax.axvline(sending.mean(), color="#F58518", linestyle=":", label="mean")
    ax.set_xlabel("Sending amount (mixed currencies, log scale)")
    ax.set_title("Transaction value distribution is right-skewed")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIG_DIR / "05_value_distribution.png", dpi=140)
    plt.close()

    # 06 account frequency
    freq = txn.groupby("sender_account_id").size()
    fig, ax = plt.subplots(figsize=(9, 5))
    sns.histplot(freq, bins=40, ax=ax, color="#72B7B2")
    ax.set_xlabel("Transactions per sender account")
    ax.set_title("Most accounts are low-frequency; a long tail is high-frequency")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "06_account_frequency.png", dpi=140)
    plt.close()

    # 07 login failure by channel
    login_ch = logins.merge(ch, on="channel_id", how="left")
    login_fail_ch = (
        login_ch.groupby("channel_name")["status"]
        .apply(lambda s: s.eq("FAILED").mean())
        .sort_values(ascending=False)
    )
    fig, ax = plt.subplots(figsize=(9, 5))
    login_fail_ch.plot(kind="bar", ax=ax, color="#E45756")
    ax.set_ylabel("Login failure rate")
    ax.set_xlabel("")
    ax.set_title("Login failure rate by channel")
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda v, _: f"{v:.0%}"))
    plt.xticks(rotation=25, ha="right")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "07_login_failure.png", dpi=140)
    plt.close()

    # 08 monthly volume
    ts = pd.to_datetime(txn["created_at"], utc=True)
    txn["month"] = ts.dt.strftime("%Y-%m")
    monthly = (
        txn.groupby("month")
        .agg(n=("transaction_id", "count"), fail=("is_failed", "mean"))
        .reset_index()
    )
    fig, ax1 = plt.subplots(figsize=(10, 5))
    ax2 = ax1.twinx()
    ax1.plot(monthly["month"], monthly["n"], color="#4C78A8", marker="o", label="volume")
    ax2.plot(monthly["month"], monthly["fail"] * 100, color="#E45756", marker="s", label="fail %")
    ax1.tick_params(axis="x", rotation=45)
    ax1.set_ylabel("Transactions")
    ax2.set_ylabel("Failure rate (%)")
    ax1.set_title("Monthly volume and failure rate")
    fig.tight_layout()
    fig.savefig(FIG_DIR / "08_monthly_trend.png", dpi=140)
    plt.close()

    p99 = float(sending.quantile(0.99))
    metrics = {
        "n_countries": int(len(t["countries"])),
        "n_customers": int(len(cust)),
        "n_accounts": int(len(acc)),
        "n_branches": int(len(t["branches"])),
        "n_channels": int(len(ch)),
        "n_types": int(len(tt)),
        "n_logins": int(len(logins)),
        "n_transactions": int(len(txn)),
        "txn_failure_rate": round(fail_rate, 4),
        "cross_border_rate": round(xborder_rate, 4),
        "login_failure_rate": round(login_fail, 4),
        "sending_mean": round(float(sending.mean()), 2),
        "sending_median": round(float(sending.median()), 2),
        "sending_p99": round(p99, 2),
        "channel_failure": {
            row.channel_name: round(float(row.fail), 4) for row in by_ch.itertuples()
        },
        "type_failure": {row.type_name: round(float(row.fail), 4) for row in by_type.itertuples()},
        "top_origin_countries": {str(k): int(v) for k, v in origin.head(5).items()},
        "geo_split": {k: int(v) for k, v in geo.items()},
    }
    METRICS_PATH.write_text(json.dumps(metrics, indent=2, default=str))
    print(f"Wrote figures to {FIG_DIR}")
    print(f"Wrote {METRICS_PATH}")
    print(json.dumps({k: metrics[k] for k in (
        "n_customers", "n_accounts", "n_logins", "n_transactions",
        "txn_failure_rate", "cross_border_rate", "login_failure_rate",
        "sending_mean", "sending_median", "sending_p99",
    )}, indent=2))


if __name__ == "__main__":
    main()
