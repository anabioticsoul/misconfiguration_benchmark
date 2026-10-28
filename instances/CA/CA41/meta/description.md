After upgrading NGINX to `v1.15.2`, the following warning appears:

```text
nginx: [warn] the "ssl" directive is deprecated, use the "listen ... ssl" directive instead
```

The `ssl on;` directive is on line 8 of the server configuration. How can this be solved?
