import Config

config :cb162, :repo,
  hostname: "127.0.0.1",
  username: "cb162",
  password: "",
  database: "cb162",
  port: 5432,
  ssl: true,
  ssl_opts: [
    versions: [:"tlsv1.2"]
  ]
