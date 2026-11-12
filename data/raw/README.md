# Raw data

RiskQL does **not** ingest a public raw extract.

No single public banking dataset (including Kaggle transaction-fraud corpora)
provides, together, the dimensions this model needs:

- internal sender *and* optional external recipient
- explicit origin and destination country (independent of currency)
- login events with origin geography and success/failure
- channels, transaction types, branches, and account relationships

Stitching several public files would still require large synthetic fill-in, and
would risk implying that the data is a real bank extract.

**Chosen approach:** a seeded synthetic generator (`src/generate_data.py`)
writes the working files under `data/processed/`. Those CSVs are derived data,
not an upstream raw dump.

This folder is reserved so that, if a licensed public extract is added later,
the original files can sit here **immutable**, with transformations documented
separately.
