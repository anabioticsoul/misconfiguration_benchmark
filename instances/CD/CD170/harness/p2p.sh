#!/usr/bin/env bash
set -euo pipefail

[ -f /opt/cd170/manage.py ]
[ -f /opt/cd170/settings.py ]
[ -f /opt/cd170/dj_database_url.py ]
grep -Fqx 'Django==1.4.2' /opt/cd170/requirements.txt
grep -Fqx 'wsgiref==0.1.2' /opt/cd170/requirements.txt
grep -Fqx 'dj-database-url==0.2.1' /opt/cd170/requirements.txt
grep -Fq "django.db.backends.postgresql_psycopg2" /opt/cd170/dj_database_url.py
