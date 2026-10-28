# Can't connect to local MySQL server through socket `/var/mysql/mysql.sock` (38)

A local MySQL client cannot connect and reports:

```
Can't connect to local MySQL server through socket '/var/mysql/mysql.sock' (38)
```

The MySQL configuration uses this socket for both the client and server:

```ini
[client]
port=3306
socket=/var/mysql/mysql.sock

[mysqld]
port=3306
socket=/var/mysql/mysql.sock
key_buffer_size=16M
max_allowed_packet=8M
```

The server is not running. `mysql_config --sockets` reports `/tmp/mysql.sock`. The goal is to restore local MySQL connectivity without changing application code.
