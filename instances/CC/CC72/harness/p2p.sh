#!/usr/bin/env bash
set -euo pipefail
cd /opt/rector-demo
test -x vendor/bin/rector
test -f src/Entity/User.php
grep -Fq '@ORM\Entity' src/Entity/User.php
