I've installed nginx with php5-fpm and mysql. My nginx configuration has `root /var/www;`, PHP as the index, and `fastcgi_pass unix:/var/run/php5-fpm.sock;`. It initially downloaded PHP files instead of executing them. Now nginx will not start, and the terminal reports:

```
user directive makes sense only if the master process runs with super-user privileges
nginx: [emerg] "fastcgi_pass" directive is not allowed here in /etc/nginx/sites-enabled/default~:68
```

Please help fix the problem.
