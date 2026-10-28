# MySQL Client Authentication Failure

A MySQL service is running in the environment.

The expected behavior is that the standard client invocation can connect
successfully:

```bash
mysql
```

Currently it fails with an authentication error:

```text
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)
```

Explicit credentials are known to work, so the database service itself is
running.

Diagnose the problem and repair the environment so the default client
connection succeeds without weakening authentication.

Do not modify benchmark harness files, replace the client invocation, or
weaken authentication.
