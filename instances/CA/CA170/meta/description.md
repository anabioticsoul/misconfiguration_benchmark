# psql: weird error output encoding on Windows 10

Whenever I make a syntax error in psql, no matter what the problem is, psql shows only:

```
ERROR:  character with byte sequence 0xd0 0x9e in encoding "UTF8" has no equivalent in encoding "WIN1252"
```

without specifying the issue. I am doing it on localhost. I have tried changing the codepage to utf8 (`chcp 65001`) and using `SET CLIENT_ENCODING TO 'utf8'` in psql itself. After that, errors are shown, but in strange encoding. I need it to show errors in English.

The intended fix is to configure PostgreSQL to emit English server messages rather than Russian messages that cannot be converted to WIN1252: set `lc_messages = C` in `postgresql.conf` and reload PostgreSQL.
