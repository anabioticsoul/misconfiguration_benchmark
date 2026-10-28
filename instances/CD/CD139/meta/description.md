# Deal with Postgresql Error -canceling statement due to conflict with recovery- in psycopg2

# Question

I'm creating a reporting engine that makes a couple of long queries over a standby server and process the result with pandas. Everything works fine but sometimes I have some issues with the execution of those queries using a psycopg2 cursor: the query is cancelled with the following message:

```
ERROR: cancelling statement due to conflict with recovery
Detail: User query might have needed to see row versions that must be removed
```

I was investigating this issue

[PostgreSQL ERROR: canceling statement due to conflict with recovery](https://stackoverflow.com/questions/14592436/postgresql-error-canceling-statement-due-to-conflict-with-recovery)

<https://www.postgresql.org/docs/9.0/static/hot-standby.html#HOT-STANDBY-CONFLICT>

but all solutions suggest fixing the issue making modifications to the server's configuration. I can't make those modifications (We won the last football game against IT guys :) ) so I want to know how can I deal with this situation from the perspective of a developer. Can I resolve this issue using python code? My temporary solution is simple: catch the exception and retry all the failed queries. Maybe could be done better (I hope so).

Thanks in advance


---


# Accepted Answer

There is nothing you can do to avoid that error without changing the PostgreSQL configuration (from PostgreSQL 9.1 on, you could e.g. set [`hot_standby_feedback`](https://www.postgresql.org/docs/current/static/runtime-config-replication.html#GUC-HOT-STANDBY-FEEDBACK) to `on`).

You are dealing with the error in the correct fashion – simply retry the failed transaction.