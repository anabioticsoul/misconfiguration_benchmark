# mysql: Bind on unix socket: Permission denied

Can't start a second MySQL instance with:

```text
sudo /usr/bin/mysqld_safe --datadir=/srv/mysql/myDB --log-error=/srv/mysql/logs/mysqld-myDB.log --pid-file=/srv/mysql/pids/mysqld-myDB.pid --user=mysql --socket=/srv/mysql/sockets/mysql-myDB.sock --port=3700
```

The error log reports:

```text
[ERROR] Can't start server : Bind on unix socket: Permission denied
[ERROR] Do you already have another mysqld server running on socket: /srv/mysql/sockets/mysql-myDB.sock ?
[ERROR] Aborting
```

One mysqld is already running on the default socket and port. The custom socket directory exists, is empty, and is writable by `mysql`. AppArmor is enabled for `/usr/sbin/mysqld`; its profile permits `/var/run/mysqld/mysqld.sock` but does not explicitly permit the custom socket and PID paths under `/srv/mysql`.

What should be changed so the instance can start using `/srv/mysql/sockets/mysql-myDB.sock`?

## Accepted answer

The AppArmor profile is the culprit. Add rules for the custom paths, for example:

```text
/srv/mysql/pids/mysqld-myDB.pid w,
/srv/mysql/sockets/mysql-myDB.sock w,
```
