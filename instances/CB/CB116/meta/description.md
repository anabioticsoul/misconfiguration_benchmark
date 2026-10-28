# mysqld: Job failed to start

MySQL occasionally fails to start on an Ubuntu laptop. Init reports that the mysql main process exits with status 1 and eventually stops respawning. The MySQL error logs are empty.

Running the daemon manually shows:

```
[ERROR] Can't start server: Bind on TCP/IP port: Cannot assign requested address
[ERROR] Do you already have another mysqld server running on port: 3306 ?
[ERROR] Aborting
```

The laptop currently has address `192.168.1.2`, while the server reports that it is trying to bind to `192.168.1.3`. The laptop uses a DHCP Wi-Fi network. Diagnose and correct the configuration so MySQL starts reliably.
