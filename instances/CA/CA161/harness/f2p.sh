#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca161-f2p.log
set +e
/usr/local/bin/ambari-agent-repo-sync >"$log" 2>&1
status=$?
set -e
cat "$log"
if [[ "$status" -ne 0 ]]; then
  echo 'repository synchronization did not complete' >&2
  exit 1
fi
grep -Fq 'baseurl=http://myproxy:8888/HDP/centos7/2.x/updates/2.3.4.7' /etc/yum.repos.d/HDP.repo
