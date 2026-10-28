#!/usr/bin/env bash
set -euo pipefail
chmod 0755 /usr/local/bin/ambari-agent-repo-sync
chmod 0644 /etc/ambari-agent/conf/ambari-agent.ini /etc/yum.repos.d/HDP.repo
