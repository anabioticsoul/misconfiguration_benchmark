# Apache HTTPS load balancer backend failure

An Apache 2.4 load balancer proxies `/test` to two Apache backends over HTTPS. Direct HTTPS access to the backends works, and HTTP proxying works, but requests through the load balancer fail with `502` and `Error during SSL Handshake with remote server`. The backends currently use self-signed certificates. Diagnose the load balancer configuration and restore the HTTPS proxy request without changing the backend services to HTTP.
