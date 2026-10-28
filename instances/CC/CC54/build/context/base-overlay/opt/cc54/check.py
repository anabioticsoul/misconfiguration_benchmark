#!/usr/bin/env python3
import os
import sys
import xml.etree.ElementTree as ET

CONFIG = "/opt/cc54/web.config"
MISSING = "System.Web.Helpers, Version=1.0.0.0, Culture=neutral, PublicKeyToken=31BF3856AD364E35"

try:
    root = ET.parse(CONFIG).getroot()
except (OSError, ET.ParseError) as exc:
    print("Configuration Error: " + str(exc), file=sys.stderr)
    sys.exit(2)

for node in root.findall("./system.web/compilation/assemblies/add"):
    assembly = node.attrib.get("assembly", "")
    if assembly.startswith("System.Web.Helpers, Version=1.0.0.0") and not os.path.exists("/opt/cc54/bin/System.Web.Helpers.dll"):
        print("Parser Error Message: Could not load file or assembly '" + MISSING + "' or one of its dependencies. The system cannot find the file specified.", file=sys.stderr)
        sys.exit(1)

print("Configuration loaded successfully")
