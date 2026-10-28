# How do I configure a virtual server in nginx to listen only on IPv6

For my website I need effectively 3 domains:

* example.domain: accessible via both IPv4 & IPv6
* ipv4.example.domain: accessible via IPv4 only
* ipv6.example.domain: accessible via IPv6 only

I tried to solve this using the following nginx config:

```nginx
server {
    listen [::]:80 ipv6only=off default_server;
    listen 80 default_server;
    server_name example.domain;
}

# IPv4 only endpoint
server {
    listen 80;
    server_name ipv4.example.domain;
}

# IPv6 only endpoint
server {
    listen [::]:80 ipv6only=on;
    server_name ipv6.example.domain;
}
```

But this throws the error: `nginx: [emerg] duplicate listen options for [::]:80` for the IPv6 server block.

How can I achieve the desired result? Would I be required to use 2 separate IPv6 addresses to host these websites on?

## Accepted Answer

The `ipv6only` parameter is turned on by default and can only be set once on start. You cannot use both `ipv6only=off` and `ipv6only=on`. The first server block should use `ipv6only=on`, since it already has separate IPv4 and IPv6 listen directives.
