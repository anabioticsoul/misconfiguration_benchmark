# PHP FPM gives permission denied?

Nginx reports this while handling a PHP request:

```
open() "/var/lib/nginx/tmp/fastcgi/2/00/0000000002" failed (13: Permission denied) while reading upstream
```

The Nginx worker, PHP-FPM workers, the socket, and `/var/lib/nginx/tmp` were checked and appeared to use `ec2-user`; even broad permissions on the `tmp` directory did not help. The relevant configuration uses a Unix PHP-FPM socket and a PHP location with `fastcgi_pass` and `try_files`.

What is causing the permission denied, and what should be changed?

The accepted answer found that `/var/lib/nginx/tmp` had been changed, but its parent `/var/lib/nginx` had not. The parent directory also had to be owned by the service user (the answer used `ec2-user:ec2-user`); after correcting the parent ownership, the errors stopped.
