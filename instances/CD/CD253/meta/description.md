# Unable to execute php as shell user for a ownership problem with socket

I am running Apache + PHP as [FPM](https://en.wikipedia.org/wiki/PHP#Installation_and_configuration) on a [Debian 11 (Bullseye)](https://en.wikipedia.org/wiki/Debian_version_history#Debian_11_(Bullseye)). *I need and cannot change these!*

My PHP www pool contains

```
user = shell_user
group = shell_user
```

Also, Apache is running configured in the same way.

When I restarted the PHP service (as root) I got this problem:

```
cd /run/php
systemctl start php7.4-fpm.service
ls -la /run/php/
```

Output:

```
total 4
drwxr-xr-x  2 www-data www-data 100 Jun  5 11:07 .
drwxr-xr-x 23 root     root     700 Jun  5 10:53 ..
-rw-r--r--  1 root     root       5 Jun  5 11:07 php7.4-fpm.pid
srw-rw----  1 www-data www-data   0 Jun  5 11:07 php7.4-fpm.sock
lrwxrwxrwx  1 root     root      30 Jun  5 09:50 php-fpm.sock -> /etc/alternatives/php-fpm.sock
```

As you can see, the *.sock* file is created anyway as owned by *www-data:www-data*.

So, when I load a PHP file from web browser, I got a 503 error into the browser and this in the error log file of Apache:

```
[Mon Jun 05 11:03:25.599836 2023] [proxy:error] [pid 19819:tid 139705513932544] (13)Permission denied: AH02454: FCGI: attempt to connect to Unix domain socket /run/php/php7.4-fpm.sock (*:80) failed
```

If I change the sock ownership manually as *www-data:shell_user*, it works.

But I must ensure that all should work as expected even after a reboot or a service restart.

## Accepted Answer

Solved.

In the PHP www pool config file I need also to set

```
listen.owner = shell_user
listen.group = shell_user
```

Do not reuse assumptions or private oracle details from another instance.
