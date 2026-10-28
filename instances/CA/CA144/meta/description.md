# Traefik2 as reverse proxy for Nginx in Django production Docker Compose

Traefik is configured to route `blog.project.com` to the Nginx container on port 8080, while Nginx is configured to deliver Django static files and proxy application requests. Requests through Traefik return **Bad Gateway**.

The relevant Nginx server configuration is:

```nginx
server {
    listen 80;

    location / {
        return 200 "nginx-ok\n";
    }
}
```

Traefik's service label is equivalent to:

```text
traefik.http.services.blogngsec.loadbalancer.server.port=8080
```

Diagnose and correct the configuration so that the reverse proxy can reach Nginx on the configured backend port, without removing Nginx or bypassing the proxy architecture.