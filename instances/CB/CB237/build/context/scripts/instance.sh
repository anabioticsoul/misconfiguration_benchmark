#!/usr/bin/env bash
set -euo pipefail

chown -R postgres:postgres /opt/cb237/data /opt/cb237
chmod 600 /opt/cb237/pg_service.conf
