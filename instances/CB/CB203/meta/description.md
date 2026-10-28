# Nginx HTTP request returns 400 on the HTTP port

An application is exposed at `http://app1.internal.example.com:8080` and HTTPS at `https://app1.internal.example.com:8443`. Nginx should redirect HTTP requests to HTTPS, but an HTTP request returns:

```text
400 The plain HTTP request was sent to HTTPS port
```

The relevant configuration is:

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name app1.internal.example.com;

    return 301 https://app1.internal.example.com:8443$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name app1.internal.example.com;

    location ^~ / {
        proxy_pass http://localhost:5000;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_redirect off;
    }
}
```

How can the HTTP request be made to redirect correctly instead of returning this error?
