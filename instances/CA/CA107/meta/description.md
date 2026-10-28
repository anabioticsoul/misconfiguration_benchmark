# Nginx rate limiting reuse

Our company wants to use nginx rate limit based on HTTP headers. We have this configuration:

```nginx
limit_req_zone $http_CLIENT_KEY zone=newzone:10m rate=1r/m;

server {
    listen 80;
    location / {
        limit_req zone=newzone burst=9 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:8080;
    }
}
```

We want to give permission to every `CLIENT-KEY` header only 10 requests per minute and block them for one minute. This config works, but after one minute we can send only one request every minute rather than ten. What should be changed?
