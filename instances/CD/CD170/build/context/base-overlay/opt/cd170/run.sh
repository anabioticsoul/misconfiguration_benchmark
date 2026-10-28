#!/usr/bin/env bash
set -euo pipefail

cd /opt/cd170
if grep -Eq '^psycopg2==' requirements.txt; then
    export PYTHONPATH=/opt/cd170/vendor${PYTHONPATH:+:$PYTHONPATH}
else
    unset PYTHONPATH
fi
exec python3 ./manage.py check --verbosity 0
