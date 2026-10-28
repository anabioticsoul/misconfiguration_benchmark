# CB162 build requirements

Install the pinned Ubuntu 22.04 packages for Elixir, Erlang, PostgreSQL, OpenSSL, Git, and CA certificates. The base layer must compile the real Postgrex dependency and configure a local PostgreSQL 14 cluster with SSL enabled and TLS 1.2 as its only protocol. The instance layer replaces only `/opt/cb162/config/config.exs` with the faulty Postgrex SSL version setting.

The base layer must retain the root Mix/Hex/Rebar tool state after compilation so runtime `mix run` commands are non-interactive and do not prompt for Hex. The runtime container must remain available for investigation and must not start PostgreSQL automatically. Harnesses start the real local PostgreSQL cluster and invoke the compiled Mix application. No harnesses, benchmark metadata, or patches may be copied into the image.
