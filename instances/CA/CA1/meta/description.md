MySQL fails to start with an error like:

```
/usr/sbin/mysqld: unknown option '--query_cache_size-128M'
```

The configuration appears to contain ordinary query-cache settings, but the server aborts during startup. Investigate the MySQL configuration and make the smallest configuration change needed to restore startup.
