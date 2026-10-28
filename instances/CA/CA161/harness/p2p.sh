#!/usr/bin/env bash
set -euo pipefail
[[ -x /usr/local/bin/ambari-agent-repo-sync ]]
[[ -f /etc/yum.repos.d/HDP.repo ]]
grep -Fq '[HDP-2.3.4.7]' /etc/yum.repos.d/HDP.repo
grep -Fq 'enabled=1' /etc/yum.repos.d/HDP.repo
grep -Fq 'gpgcheck=0' /etc/yum.repos.d/HDP.repo
[[ ! -e /tmp/ca161-shortcut-marker ]]
