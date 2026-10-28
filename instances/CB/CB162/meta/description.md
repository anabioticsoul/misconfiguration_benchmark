# How to connect to PostgreSQL from Phoenix Web App via SSL?

When trying to run an Elixir (Phoenix) web application using a PostgreSQL database hosted by a third-party Database-as-a-Service provider such as Azure Database for PostgreSQL, starting the app produces an error like:

```text
[info] Running Pxblog.Endpoint with Cowboy using http://localhost:4000
[error] GenServer terminating
** (FunctionClauseError) no function clause matching in Postgrex.Messages.decode_fields/1
    (postgrex) lib/postgrex/messages.ex:339: Postgrex.Messages.decode_fields("")
    (postgrex) lib/postgrex/messages.ex:344: Postgrex.Messages.decode_fields/1
    (postgrex) lib/postgrex/messages.ex:131: Postgrex.Messages.parse/3
    (postgrex) lib/postgrex/protocol.ex:1842: Postgrex.Protocol.msg_decode/1
    (postgrex) lib/postgrex/protocol.ex:560: Postgrex.Protocol.auth_recv/3
    (postgrex) lib/postgrex/protocol.ex:475: Postgrex.Protocol.handshake/2
```

The database service has **Enforce SSL Connection** enabled by default. Disabling that setting makes the application connect, but SSL is preferred. Adding `ssl: true` to the Ecto repository configuration alone still results in an SSL connection failure, even though `psql ...?sslmode=require` works from the same machine.

How should Phoenix/Ecto/Postgrex connect to PostgreSQL over SSL? Does the application server need its own certificate or OpenSSL configuration?

## Accepted answer

The failure occurs during Erlang's `ssl.connect/3`. The PostgreSQL service negotiates TLS 1.2, while the Postgrex client needs its TLS version to be selected explicitly. Configure the repository with `ssl: true` and an `ssl_opts` list containing the TLS 1.2 version:

```elixir
config :myapp, Myapp.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "myapp@dev-db",
  password: "...",
  database: "myapp_dev",
  port: 5432,
  hostname: "dev-db.postgres.database.azure.com",
  pool_size: 10,
  ssl: true,
  ssl_opts: [
    versions: [:"tlsv1.2"]
  ]
```

This makes the Postgrex SSL connection succeed; disabling SSL is only a temporary workaround.
