#!/usr/bin/env bash
set -euo pipefail
log=/tmp/ca161-repro.log
set +e
/usr/local/bin/ambari-agent-repo-sync >"$log" 2>&1
status=$?
set -e
cat "$log"
[[ "$status" -ne 0 ]]
grep -Fq 'repository proxy must be configured through Ambari cluster version URLs' "$log"
grep -Fq 'baseurl=http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.3.4.7' /etc/yum.repos.d/HDP.repo
