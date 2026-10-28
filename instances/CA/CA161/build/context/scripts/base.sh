#!/usr/bin/env bash
set -euo pipefail
install -d -m 0755 /usr/local/bin /etc/ambari-agent/conf /etc/yum.repos.d
cat > /usr/local/bin/ambari-agent-repo-sync <<'SYNC'
#!/usr/bin/env bash
set -euo pipefail
config=/etc/ambari-agent/conf/ambari-agent.ini
repo=/etc/yum.repos.d/HDP.repo
mode=$(awk -F= '/^[[:space:]]*repo_proxy_mode[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2}' "$config")
if [[ "$mode" == "per_repo_file" ]]; then
  echo "repository proxy must be configured through Ambari cluster version URLs" >&2
  printf '%s\n' '[HDP-2.3.4.7]' 'name=HDP-2.3.4.7' 'baseurl=http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.3.4.7' 'path=/' 'enabled=1' 'gpgcheck=0' > "$repo"
  exit 1
fi
if [[ "$mode" != "ambari_cluster_version" ]]; then
  echo "unsupported repository proxy mode: $mode" >&2
  exit 2
fi
[[ -s "$repo" ]] || { echo "repository file is missing" >&2; exit 3; }
grep -Fq 'baseurl=http://myproxy:8888/HDP/centos7/2.x/updates/2.3.4.7' "$repo" || { echo "configured repository URL is not proxy-backed" >&2; exit 4; }
echo 'repository synchronization completed through configured Ambari repository URLs'
SYNC
chmod 0755 /usr/local/bin/ambari-agent-repo-sync
