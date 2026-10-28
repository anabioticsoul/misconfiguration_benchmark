# CA14 Private Build Requirements

Build a MySQL option-file instance that reproduces
`mysql: unknown variable 'time_zone=Brazil/East'`.

The clean base must configure the server option
`default_time_zone=Brazil/East` in the `[mysqld]` section and contain populated
time-zone tables. The faulty layer must remove that server option and place the
unsupported `time_zone=Brazil/East` option in the `[client]` section.

The MySQL service and synthetic CA35 credentials inherited from the reusable
clean source image must remain unchanged.
