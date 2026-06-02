# MySQL Client Authentication Failure

A MySQL service is running in the environment.

The expected behavior is that the following standard client invocation can
connect and run a simple health-check query successfully:

```bash
mysql -N -B -e 'SELECT 1;'
```

Currently it fails with an authentication error:

```text
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)
```

Explicit credentials are known to work, so the database service itself is
running.

Diagnose the problem and repair the environment so the same client invocation
exits successfully and prints `1`.

Do not modify benchmark harness files, replace the health-check command, or
weaken authentication.
