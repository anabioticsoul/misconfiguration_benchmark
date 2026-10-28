# Azure postgres flexible server and pgbouncer max connections

# Question

I have an Azure postgresql flexible server running a `General Purpose, D2s_v3, 2 vCores, 8 GiB RAM, 32 GiB storage instance` and using pg\_bouncer for connection pooling.

At all time there are 100 active connections and when I try to connection (not using the pgbouncer) I get the error `Remaining connection slots are reserved`. I can also see that there are sporadic errors on connecting that looks to be from pgbouncer as there are not failed connections on the postgresql server.

The server is configured with:

`max_connections` = 100   
`pgbouncer.default_pool_size` = 50   
`pgbouncer.max_client_conn` = 5000   
`pgbouncer.min_pool_size` = 0   
`pgbouncer.pool_mode` = TRANSACTION

Should the max connections be increased or is there some other configuration that should be adjusted such that pgbouncer don't allocate all connections?



### Question Comments

=== COMMENTS ===
- (1) Frank Heikens [2023-02-08T14:20:41+00:00]: Set pgbouncer.max_db_connections to something like 90. At least a value below your max_connections.
- (2) aweis [2023-02-08T14:25:48+00:00]: @FrankHeikens I can't access that parameter in Azure Postgresql - they are only allowing a subset of the parameters learn.microsoft.com/en-us/azure/postgresql/flexible-server/…
- (3) Frank Heikens [2023-02-08T14:32:43+00:00]: Then change pgBouncer.max_client_conn
- (4) aweis [2023-02-08T14:34:30+00:00]: Is there a best practice to calculate what it should be, based on databases/users and max_connections in general i would expect that pg_bouncer should help decrease the number of connections
- (5) Frank Heikens [2023-02-08T14:39:24+00:00]: Depends on your usage pattern. But a connection pool should never be able to create more database connections than your database allows. Your current setting has no upper limit, with up to 5000 clients pgbouncer could try to open 5000 database connections in case all clients try to start a transaction at the same time.
- (6) Aaron Glover [2023-02-13T13:16:32+00:00]: Can anyone help me regarding why pgbouncer doesn't seem to be available on my Postgresql Flexible Server in Azure. I've following instructions to look for server parameter but there are no pgbouncer params :(  nevermind I think I worked out that because my server is using 'burstable' compute SKU, it is not available
- (7) Naveen Sharma [2023-02-16T10:10:12+00:00]: @aweis check if Link helps


---


# Accepted Answer

So in general the only solution was to limit the `pgbouncer.default_pool_size` to a number that was low enough to not take up all connections. For example if:

`max_connections` = 400
`default_pool_size` = 50

With a total of 7 databases and one user connecting to them the max number of connections created by pgbouncer would be `7 * 1 * 50` = 350 which is less than the max\_connections.

Unfortunately the few pgbouncer parameters exposed in Azure don't allow for a better configuration other than setting the same configuration for all databases on the server.