#!/usr/bin/env bash
set -euo pipefail
config=/opt/ca21/src/main/resources/applicationContext.xml
test -f /opt/ca21/app.jar
grep -F 'jdbc:h2:mem:ca21;DB_CLOSE_DELAY=-1' "$config" >/dev/null
grep -F 'hibernate.hbm2ddl.auto' "$config" >/dev/null
test ! -e /opt/ca21/src/main/resources/META-INF/persistence.xml
