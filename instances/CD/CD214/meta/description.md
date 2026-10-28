# Connection sits idle forever on PostgreSQL with Node.js and pg

# Question

We have the following on [node-postgres](https://node-postgres.com/api/pool) documentation:

> // number of milliseconds to wait before timing out when connecting a new client  
> // by default this is 0 which means no timeout  
> connectionTimeoutMillis?: int,

And then, a little bit later on the same documentation:

> You must call the releaseCallback or client.release (which points to the releaseCallback) when you are finished with a client. If you forget to release the client then your application will quickly exhaust available, idle clients in the pool and all further calls to pool.connect will timeout with an error or **hang indefinitely if you have connectionTimeoutMillis configured to 0**.

So, I was expecting that if I set `connectionTimeoutMillis` to `1000`, then, after 1s idle, it should automatically release the connection, even if I don't call `client.release()`.

But running the code below it sits idle forever on PostgreSQL:

```
// test.js
// PostgreSQL v14.2
// Node.js v16.15.1
// node-postgres (pg) v8.7.3

const { Pool } = require('pg')

const pool = new Pool({
    user: 'postgres',
    password: 'postgres',
    host: `localhost`,
    port: 5432,
    database: 'app_dev',
    max: 10,
    connectionTimeoutMillis: 1000,
    idleTimeoutMillis: 1000
})

;(async function() {
    const client = await pool.connect()
    const {rows} = await client.query('SELECT NOW()')
    console.log(rows[0])
})()
```

Am I missing something?


---


# Accepted Answer

I think this is what you are missing

When your app is calling

```
const client = await pool.connect()
```

This is where the `connectionTimeoutMillis` is valid. i.e. it is the amount of time in milliseconds to wait when trying to get a client (a connection) to your PostgresDB. If you set this to 1000ms it means, *if I haven't created a new client or returned an existing one from the pool within 1000ms - throw an error*. So since you are after obtaining the client - that will not release it or implicitly return your client to the pool as you HAVE the client - therefore there is no waiting on a connection to be established.

The `idleTimeoutMillis` time refers to the amount of time that the client (connection) can sit in the pool without being called by your application code before being destroyed.
For example, say your pool has a size of 1 client. Your app uses the client and then releases it back to the pool. If your app doesn't request another client for more than 1000ms i.e. the client is idle in the pool for a time equal or greater than the `idleTimeoutMillis` - it will be destroyed.



### Answer Comments

=== COMMENTS ===
- (1) Lino [2022-09-22T17:47:05+00:00]: That totally makes sense, thanks for answering, it is clearer now!