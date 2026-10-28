# Remote PostgreSQL connection with pgAdmin

PostgreSQL 9.5 on an Ubuntu server is not accepting remote TCP connections. `psql -h ip_address -d name_of_the_database -U username` reports connection refused, and `netstat -na` does not show port 5432 listening. The PostgreSQL configuration was intended to use `listen_addresses = '*'`, but the setting was left commented out. Configure PostgreSQL to listen on TCP and restart it; the relevant server setting is `listen_addresses` in `postgresql.conf`.

The accepted diagnosis is to remove the comment marker from `listen_addresses = '*'`, restart PostgreSQL, and verify the listening port with `netstat -ntlp`. The source also discusses `pg_hba.conf`, firewall rules, and checking the configured port.
