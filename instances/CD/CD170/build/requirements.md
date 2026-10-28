# Build requirements

The base layer uses `ubuntu:22.04` and installs Python 3 plus a pinned Django
runtime with the distribution package manager and pip. The application fixture
preserves the source case’s Django 1.4.2-era dependency file and PostgreSQL
adapter spelling. A tiny local adapter package is included only to make the
repair deterministic and offline: the faulty layer activates no adapter, while
adding `psycopg2==2.4.4` activates the vendored adapter during the real Django
management command.
