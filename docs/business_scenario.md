# RiskQL: Banking Risk Analytics

## 1. Overview

Financial institutions process large volumes of transactions and customer
interactions across accounts, payment channels, branches, countries, and
digital platforms. Raw operational data does not by itself tell a risk team
where failures concentrate, which corridors are noisy, or which customers
show unusual combinations of authentication and payment activity.

This project models a **simplified global banking environment** and uses a
relational database plus SQL and Python analytics to investigate operational
risk indicators.

> **Important.** This is a conceptual model built for learning and portfolio
> demonstration. It does **not** represent the internal systems, policies,
> data, or risk models of Bank of America or any other financial institution.
> All data is synthetic.

## 2. Business problem

A global bank wants to improve how it **identifies and monitors potentially
elevated-risk operational activity**. It has data on customers, accounts,
transactions, transaction types, channels, branches, countries, and login
events, but needs analytical indicators that help answer:

- Where are transaction failures concentrated?
- Which channels exhibit elevated failure rates?
- Are there unusual customer or account transaction patterns?
- Are certain geographic corridors associated with higher failure rates?
- What share of activity is cross-border?
- Are there unusual login patterns that warrant investigation?
- Can login activity provide useful context for transaction activity?
- What operational indicators should a Global Risk Management team monitor?

## 3. Risk scope

### Primary: Operational risk

Operational risk here means indicators of **failures, disruptions, and
unusual operational patterns** across processes and channels: failed
payments, failed logins, channel concentration, time clustering, and
processing exceptions (pending / reversed).

### Supporting dimensions

Transactional, geographic, and digital-activity views are **supporting
indicators**. They provide context; they are not by themselves evidence that
a customer, corridor, or country is "risky".

### Explicitly out of scope

- **Credit risk:** no PD/LGD, no delinquency labels, no facility data.
- **Confirmed financial crime:** no SAR labels, no fraud tags. Unusual
  activity is treated as a pattern to investigate, never as a confirmed
  incident of fraud or money laundering.

## 4. Key business questions

See the SQL files under `sql/analysis/` for the queries that address these
questions, and `reports/risk_analysis.md` for interpreted results.
