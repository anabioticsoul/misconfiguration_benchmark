#!/usr/bin/env bash
set -euo pipefail
python3 -c 'import xml.etree.ElementTree as E; r=E.parse("/opt/cc54/web.config").getroot(); assert r.tag == "configuration"; assert len(r.findall("./system.web/compilation/assemblies/add")) >= 3'
grep -F 'System.Web.Mvc, Version=3.0.0.0' /opt/cc54/web.config >/dev/null
grep -F 'System.Web.Routing, Version=4.0.0.0' /opt/cc54/web.config >/dev/null
