# MySQL: I cannot login as root after upgrading to 5.5

# Question

I've followed this [tutorial](http://www.ovaistariq.net/490/a-step-by-step-guide-to-upgrading-to-mysql-5-5/) to upgrade to mysql 5.5.

After finishing all the steps I do `$ mysql -u root -pXXXX` and it says:

```
Error 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES).
```

The tutorial worked for me sometime ago, but now I have this problem. I have reinstalled ubuntu+mysql 5.1 and I have no problem doing "mysql -u root -pXXXX", but after upgrading to 5.5 I get again the error above..

This is my /etc/my.cnf:

```
# The following options will be passed to all MySQL clients
[client]
#password    = your_password
port        = 3306
socket        = /var/run/mysqld/mysqld.sock

# Here follows entries for some specific programs

# The MySQL server
[mysqld]
user            = mysql
socket        = /var/run/mysqld/mysqld.sock
port        = 3306
basedir         = /usr/local/mysql
datadir         = /usr/local/mysql/data
tmpdir          = /tmp
log_error       = /var/log/mysql/error.log
skip-external-locking
...
```

Any idea?

**EDIT:** solved, well.. I just should do a backup of the user 'root' since I'm removing the database before upgrading to 5.5.

Regards

Javi


---


# Accepted Answer

It's just saying that you're using the wrong password really...

Maybe you have to reset the root password, though I wouldn't know why (maybe the updater overwrote it?), here's the procedure:

1. make sure there are no mysqld deamons running.
2. get to your mysql/bin directory
3. start a mysql deamon with `mysqld_safe --skip-grant-tables` (note the PID)
4. start command line mysql: `mysql`
5. execute this little script with your edit:

[code]
use `mysql`;
UPDATE `user` SET `Password`=PASSWORD('YOUR\_NEW\_PASSWORD\_HERE') WHERE `User` = 'root';
exit;
[/code]

Now you're only need to kill your `mysqld_safe` (remember the PID?..) and start the deamon normally.