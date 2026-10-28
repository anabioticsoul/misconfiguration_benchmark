#!/usr/bin/env bash
set -euo pipefail
command -v pg_isready >/dev/null
command -v psql >/dev/null
pg_isready --version >/dev/null
psql --version >/dev/null
