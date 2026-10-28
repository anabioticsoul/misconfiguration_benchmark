# Nginx is throwing an 403 Forbidden on Static Files

I have a django app, python 2.7 with gunicorn and nginx.

Nginx is throwing a `403 Forbidden Error`, if I try to view anything in my `static` folder at:

```
/home/ubuntu/virtualenv/myapp/myapp/homelaunch/static
```

The Nginx configuration contains:

```
server {
        listen       80;
        server_name     *.myapp.com;
        access_log /home/ubuntu/virtualenv/myapp/error/access.log;
        error_log /home/ubuntu/virtualenv/myapp/error/error.log warn;
        connection_pool_size 2048;

        fastcgi_buffer_size 4K;
        fastcgi_buffers 64 4k;

        root /home/ubuntu/virtualenv/myapp/myapp/homelaunch/;

        location /static/ {
            alias /home/ubuntu/virtualenv/myapp/myapp/homelaunch/static/;
        }

        location / {
            proxy_pass http://127.0.0.1:8001;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            add_header P3P 'CP="ALL DSP COR PSAa PSDa OUR NOR ONL UNI COM NAV"';
        }
    }
```

The error log contains:

```
2013/11/24 23:00:16 [error] 18243#0: *277 open() "/home/ubuntu/virtualenv/myapp/myapp/homelaunch/static/img/templated/home/img.png" failed (13: Permission denied), client: xx.xx.xxx.xxx, server: *.myapp.com, request: "GET /static/img/templated/home/img2.png HTTP/1.1", host: "myapp.com", referrer: "http://myapp.com/"
```

The access log contains:

```
xx.xx.xx.xxx - - [24/Nov/2013:23:02:02 +0000] "GET /static/img/templated/base/animg.png HTTP/1.1" 403 141 "http://myapp.com/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:25.0) Gecko/20100101 Firefox/25.0"
xx.xx.xx.xxx - - [24/Nov/2013:23:02:07 +0000] "-" 400 0 "-" "-"
```

Viewing a `.css` file in `/static/` returns:

```
<html>
<head><title>403 Forbidden</title></head>
<body bgcolor="white">
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx/1.1.19</center>
</body>
</html>
```

## Accepted Answer

It appears the user Nginx is running as (perhaps `nginx`) is missing privileges to read the local file. Check file permissions as well as permissions on the directories in the hierarchy.
