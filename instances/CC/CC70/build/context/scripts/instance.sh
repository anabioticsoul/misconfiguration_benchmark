#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
p = Path('/opt/app/pom.xml')
s = p.read_text()
needle = '    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>'
replacement = needle + '\n    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>'
if needle not in s:
    raise SystemExit('web dependency not found')
ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
security = [d for d in ET.fromstring(s).findall('m:dependencies/m:dependency', ns)
            if d.findtext('m:artifactId', namespaces=ns) == 'spring-boot-starter-security']
if not security:
    p.write_text(s.replace(needle, replacement))
elif len(security) != 1:
    raise SystemExit('duplicate spring-boot-starter-security dependency')
PY
cd /opt/app
mvn -q clean -DskipTests package
