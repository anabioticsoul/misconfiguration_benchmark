#!/usr/bin/env bash
set -euo pipefail
cd /opt/cc69
mvn -q -DskipTests dependency:go-offline
