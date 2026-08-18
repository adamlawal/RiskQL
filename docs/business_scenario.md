# RiskQL: Banking Risk Analytics

## 1. Overview

Financial institutions process millions of transactions and customer interactions across accounts, payment channels, branches, countries, and digital platforms.

As the volume and complexity of banking activity increases, risk management teams need reliable ways to identify unusual patterns, monitor risk indicators, and understand where operational or transactional risks may be concentrated.

This project models a simplified global banking environment and uses a relational database and SQL-based analytics to investigate risk indicators across customer, account, transaction, geographic, and digital activity data.


> **Important:** This is a conceptual banking model created for learning purposes. It does not represent the actual internal systems, policies, risk models, or processes of any specific financial institution.

---

## 2. Business Problem

A global banking institution wants to improve its ability to identify and monitor potentially elevated-risk activity across its operations.

The institution has data relating to:

- Customers
- Bank accounts
- Transactions
- Transaction types
- Banking channels
- Branches
- Countries
- Customer login activity

However, raw operational data does not automatically provide useful risk insight.

The risk management function needs analytical indicators that can help answer questions such as:

- Where are transaction failures concentrated?
- Are certain transaction patterns unusual?
- Are there geographic patterns associated with elevated activity?
- Are some channels associated with higher failure rates?
- Are customers exhibiting unusual transaction behaviour?
- Are there unusual login patterns that may warrant investigation?
- Can transaction and digital activity be combined to provide better risk context?
---

## 3. Risk Management Scope

### Primary Risk Area: Operational Risk

Operational risk is the primary focus of this project.

The project investigates indicators associated with failures, disruptions, unusual operational patterns, and activity across banking processes and channels.

Examples include:

- Failed transactions
- Failed login attempts
- Transaction activity by channel
- Transaction volume and concentration
- Account creation activity
- Geographic concentration of activity
- Unusual transaction patterns

### Supporting Risk Areas

The project also considers transactional, geographic, and digital activity as supporting dimensions of the risk analysis.

These are treated as **risk indicators**, rather than definitive evidence that a customer, transaction, or country is risky.

For example:

> A transaction occurring between two countries does not automatically indicate risk.

Instead, cross-border activity can be examined alongside transaction size, frequency, channel, customer behaviour, and other contextual information to identify patterns that may warrant further investigation.

---

## 4. Key Business Questions

The analysis will focus on questions such as:

### Transaction Risk

1. What types of transactions occur most frequently?
2. What proportion of transactions fail?
3. Are failed transactions concentrated in particular transaction types or channels?
4. Are there unusually large transactions relative to normal transaction activity?
5. Are there customers or accounts with unusually high transaction frequency?
6. Are there unusual patterns in sending and receiving currencies?

### Geographic Risk

7. Which countries are most frequently involved in transactions?
8. What proportion of transactions are cross-border?
9. Are failed transactions concentrated in particular geographic routes?
10. Are there transaction corridors with unusually high activity or failure rates?

### Operational Risk

11. Which banking channels have the highest transaction failure rates?
12. Are particular branches associated with unusual account creation or transaction activity?
13. Are operational failures concentrated around particular periods or channels?
14. Are there differences in operational outcomes across transaction types?

### Digital Activity

15. What proportion of login attempts fail?
16. Are failed login attempts concentrated among particular customers or channels?
17. Are customers logging in from countries that differ from their recorded customer location?
18. Are unusual login patterns followed by unusual transaction activity?

### Customer Behaviour

19. What does normal transaction behaviour look like across customers?
20. Which customers exhibit significant deviations from their usual activity?
21. Can transaction behaviour and digital activity be combined to create stronger risk indicators?

---
