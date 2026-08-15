# CA35 Private Build Requirements

Construct a MySQL 8.0.27 client-authentication misconfiguration instance.

The source image is a reusable, pre-initialized clean MySQL service image.
Install `build/context/base-overlay/` to form the case-specific clean base, then
install `build/context/fault-overlay/` to form the faulty instance.

The intended fault is limited to the `[client]` password value in
`/etc/mysql/my.cnf`:

- The database root password contains a literal backslash.
- The clean base configuration must preserve that literal backslash when the
  MySQL option-file parser reads it.
- The faulty configuration must contain one backslash, which the parser treats
  as an escape and therefore supplies the wrong password.

Required behavior:

- In the clean base image, `mysql -N -B -e 'SELECT 1;'` succeeds.
- In the final instance image, the default `mysql` invocation fails with
  `ERROR 1045`.
- In the final instance image, explicit correct credentials still work.
- Invalid credentials remain rejected.
- MySQL must remain the image's normal foreground service.

Do not change database users, database passwords, authentication plugins,
entrypoint, command, harness scripts, or files unrelated to the client option.
