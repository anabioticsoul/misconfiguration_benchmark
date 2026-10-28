# MySQL: setting time_zone in my.cnf options file

# Question

In MySQL you can set a session variable called **time\_zone** to change the timezone. This is useful e.g. when looking at timestamps from another country. Here is an example:

```
mysql> select now();
+---------------------+
| now()               |
+---------------------+
| 2010-12-30 18:59:18 |
+---------------------+
1 row in set (0.00 sec)

mysql> set time_zone='Brazil/East';
Query OK, 0 rows affected (0.00 sec)

mysql> select now();
+---------------------+
| now()               |
+---------------------+
| 2010-12-30 09:59:29 |
+---------------------+
1 row in set (0.00 sec)
```

Is it possible to put that in an option file e.g. .my.cnf ?

When I try, it doesn't work. All I get is:

> ```
> mysql: unknown variable 'time_zone=Brazil/East'
> ```



### Question Comments

=== COMMENTS ===
- (1) Leniel Maccaferri [Commented Dec 30, 2010 at 12:22]: What's your operating system?
- (2) dolmen [Commented Jun 27, 2018 at 14:29]: So far the answers work by changing settings the server side. I'm interested in an anwser that allows to change the time_zone for a mysql CLI session by setting something in ~/.my.cnf .


---


# Accepted Answer

it should be

```
default_time_zone=Brazil/East
```

details : <http://dev.mysql.com/doc/refman/5.5/en/server-system-variables.html#sysvar_time_zone>

> Option-File Format = default\_time\_zone