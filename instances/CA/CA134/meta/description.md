# MySQL SQL mode is not persistent

The database server starts with a strict SQL mode, so an application update using a zero date fails after restart. Temporarily setting `sql_mode` to `NO_ENGINE_SUBSTITUTION` in a session makes the operation work, but the setting is lost whenever the server restarts.

Make the SQL mode permanent in the server configuration. Do not rely on session commands or changing application SQL.

The server is MariaDB-compatible and its configuration is under `/etc/mysql/mariadb.conf.d/`. Verify the repaired setting by restarting the server and repeating the failing update.
