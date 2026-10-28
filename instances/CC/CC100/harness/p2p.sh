#!/usr/bin/env bash
set -euo pipefail
[ -f /opt/cc100/src/main/java/com/example/WebController.java ]
[ -f /opt/cc100/src/main/resources/templates/index.html ]
case "$(grep -c '@RequestMapping("/"' /opt/cc100/src/main/java/com/example/WebController.java)" in
  1) ;;
  *) exit 1 ;;
esac
