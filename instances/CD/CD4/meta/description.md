# MySQL server has gone away when importing a large dump file

I am trying to import a MySQL dump file. The file was created on a Linux server and I am trying to import it on Windows. From the MySQL command line, `SOURCE c:/dump.sql` produces character-set problems, particularly with smart quotes and other non-standard punctuation.

It was suggested that I run:

```text
mysql -u username -d dbase < c:\\dump.sql
```

That produces:

```text
ERROR 2006 (HY000) at line 149351: MySQL server has gone away
```

The suggested direction is to locate the server configuration file, set `max_allowed_packet` in the `[mysqld]` section to a sufficiently large value such as `32M` or `64M`, and restart the server. Alternatively, the dump generator can limit individual query sizes. The client command-line setting alone does not change the server setting.
