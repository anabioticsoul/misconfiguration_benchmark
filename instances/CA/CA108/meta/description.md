# Nginx forward proxy without redirecting

Configure the existing nginx server as a forward proxy. A request such as `http://proxy.example.com/google.com` should fetch content through the proxy rather than redirecting the client. The current location extracts the destination from the path and uses a variable `proxy_pass`, but requests to HTTPS destinations fail or result in redirect-like behavior. Make the proxy correctly forward HTTPS upstream requests, including the necessary TLS behavior.
