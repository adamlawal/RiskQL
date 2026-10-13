# RiskQL

RiskQL is an early-stage data-model design for exploring banking transaction
and login risk. The repository currently contains an entity relationship
diagram, not a running service or published analysis.

![RiskQL entity relationship diagram](docs/erd/RiskQL_ERD.png)

The model connects customers, accounts, transactions, login events, branches,
channels, transaction types, and countries. Transaction records include sender
and recipient accounts, amounts, currencies, exchange rate, channel, status,
and origin and destination countries. Login events include channel, time,
IP address, origin country, and status.

## Status

This is a schema proposal. Database migrations, sample data, risk queries,
tests, and a reproducible local setup have not been implemented yet.
