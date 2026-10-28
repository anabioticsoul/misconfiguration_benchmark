# Authentication error when connection to local postgres db

# Question

I am currently struggling to connect to a locally created postgres db. The postgres server is defined inside a `docker-compose.yml` like this:

```
version: '3.9'
services:
    postgres:
        image: bitnami/postgresql:13.4.0
        container_name: mopla-postgres
        restart: always
        environment:
            - POSTGRES_USER=mopla
            - POSTGRES_PASSWORD=develop
            - POSTGRESQL_DATABASE=mopla
        volumes:
            - mopla-postgres:/bitnami/postgresql
            - ./database_dumps:/docker-entrypoint-initdb.d
        ports:
            - 5432:5432
...
```

The container seems to start:

```
postgresql 09:02:41.34 
postgresql 09:02:41.34 Welcome to the Bitnami postgresql container
postgresql 09:02:41.34 Subscribe to project updates by watching https://github.com/bitnami/bitnami-docker-postgresql
postgresql 09:02:41.34 Submit issues and feature requests at https://github.com/bitnami/bitnami-docker-postgresql/issues
postgresql 09:02:41.35 
postgresql 09:02:41.36 INFO  ==> ** Starting PostgreSQL setup **
postgresql 09:02:41.39 INFO  ==> Validating settings in POSTGRESQL_* env vars..
postgresql 09:02:41.39 INFO  ==> Loading custom pre-init scripts...
postgresql 09:02:41.40 INFO  ==> Initializing PostgreSQL database...
postgresql 09:02:41.42 INFO  ==> pg_hba.conf file not detected. Generating it...
postgresql 09:02:41.42 INFO  ==> Generating local authentication configuration
postgresql 09:02:41.43 INFO  ==> Deploying PostgreSQL with persisted data...
postgresql 09:02:41.43 INFO  ==> Configuring replication parameters
postgresql 09:02:41.46 INFO  ==> Configuring fsync
postgresql 09:02:41.49 INFO  ==> Loading custom scripts...
postgresql 09:02:41.50 INFO  ==> Enabling remote connections
postgresql 09:02:41.51 INFO  ==> ** PostgreSQL setup finished! **
postgresql 09:02:41.55 INFO  ==> ** Starting PostgreSQL **
2022-11-28 09:02:41.571 GMT [1] LOG:  pgaudit extension initialized
2022-11-28 09:02:41.576 GMT [1] LOG:  starting PostgreSQL 13.4 on x86_64-pc-linux-gnu, compiled by gcc (Debian 8.3.0-6) 8.3.0, 64-bit
2022-11-28 09:02:41.576 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2022-11-28 09:02:41.576 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2022-11-28 09:02:41.580 GMT [1] LOG:  listening on Unix socket "/tmp/.s.PGSQL.5432"
2022-11-28 09:02:41.586 GMT [85] LOG:  database system was shut down at 2022-11-28 09:02:36 GMT
2022-11-28 09:02:41.590 GMT [1] LOG:  database system is ready to accept connections
```

Now, when I try to connect to this database with pgadmin with the password "develop", I get an authentication error:

[![enter image description here](https://i.sstatic.net/ThWDm.png)](https://i.sstatic.net/ThWDm.png)

Here is the configuration:

[![enter image description here](https://i.sstatic.net/5h5A3.png)](https://i.sstatic.net/5h5A3.png)

Is there anything obvious I am doing wrong? Anything I can do to debug this issue further?



### Question Comments

=== COMMENTS ===
- (1) jjanes [2022-11-28T12:56:05+00:00]: What new lines get added to that log when the authentication fails?
- (2) Florian Baierl [2022-11-28T13:44:09+00:00]: No logs were added - but I already figured out the issue. See my answer below.


---


# Accepted Answer

Alright, I figured it out.

There was a windows-service running that was also opening a postgres db on the same port (5432), so I was trying to connect to the wrong db.

[TCPView](https://learn.microsoft.com/en-us/sysinternals/downloads/tcpview) helped me figuring out the issue.



### Answer Comments

=== COMMENTS ===
- (1) jjanes [2022-11-28T15:25:31+00:00]: That makes sense on one hand, but is weird on another. For me on Linux, the port line causes the docker-compose up to fail when the port on the host is already in use.  I would have expected Windows to behave the same way.
- (2) Florian Baierl [2022-11-29T13:35:18+00:00]: As you have guessed, I am using windows - where it did not fail.