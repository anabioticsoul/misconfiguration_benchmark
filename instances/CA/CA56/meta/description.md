# duplicate MIME type "text/html"?

I have this in Nginx configuration files:

```nginx
gzip_types text/plain text/html text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
```

but Nginx gives an error when starting up:

```text
[warn]: duplicate MIME type "text/html" in /etc/nginx/nginx.conf:25
```

What is actually duplicate to `text/html`? Is it `text/plain`?
