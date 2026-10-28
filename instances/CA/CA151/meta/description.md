# MySQL remote TCP connection fails

A MySQL client connecting to a remote Ubuntu server reports:

```
ERROR 2003 (HY000): Can't connect to MySQL server on 'xxx.xxx.xxx.xxx' (111)
```

The client can connect locally on the server, and SSH access works. The operator edited `/etc/mysql/my.cnf` on the local machine and commented out `bind-address = 127.0.0.1`, then restarted MySQL, but remote TCP access still fails. Configure the remote MySQL installation so that the requested TCP connection works, while retaining local database access.
