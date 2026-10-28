# Prevent Ambari agent overwriting repo files

I am installing HDP components behind a corporate firewall. Hortonworks repositories need an internet proxy, while some dependencies are available in a private cloud. I need to set a proxy specific to the Hortonworks repositories inside `*.repo` files, but installation through the Ambari agent overwrites the repository files. Is there a configuration in `ambari-agent.ini` to stop the agent from overwriting repo files?

The agent logs include:

```text
2017-01-08 12:22:14,039 - Writing File['/etc/yum.repos.d/HDP.repo'] because contents don't match
2017-01-08 12:22:14,040 - Repository['HDP-UTILS-1.1.0.21'] {'base_url': 'http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.21/repos/centos7', 'action': ['create'], 'components': [u'HDP-UTILS', 'main'], 'repo_template': '[{{repo_id}}]\nname={{repo_id}}\n{% if mirror_list %}mirrorlist={{mirror_list}}{% else %}baseurl={{base_url}}{% endif %}\n\npath=/\nenabled=1\ngpgcheck=0', 'repo_file_name': 'HDP-UTILS', 'mirror_list': None}
2017-01-08 12:22:14,043 - File['/etc/yum.repos.d/HDP-UTILS.repo'] {'content': '[HDP-UTILS-1.1.0.21]\nname=HDP-UTILS-1.1.0.21\nbaseurl=http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.21/repos/centos7\n\npath=/\nenabled=1\ngpgcheck=0'}
```

## Accepted Answer

Do not configure a per-repository proxy in `ambari-agent.ini`. Instead, proxy the Hortonworks repository through nginx and update the Ambari cluster version repository URLs.

For example, if nginx is reachable on the local Hadoop network at `http://myproxy:8888`, add this block to `nginx.conf` and restart nginx:

```nginx
location ~* /(ambari|HDP) {
    proxy_pass http://public-repo-1.hortonworks.com;
}
```

In the Ambari web console, go to `admin/Manage Ambari/`, then under `Clusters` click `Versions`. Open the installed HDP version and change the HDP and HDP-UTILS URLs for the OS to use the proxy, for example change:

```text
http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.3.4.7
```

to:

```text
http://myproxy:8888/HDP/centos7/2.x/updates/2.3.4.7
```

Do not skip base URL validation when saving. Ambari will validate the repository through the proxy. Check the proxy configuration and logs if validation reports an error.
