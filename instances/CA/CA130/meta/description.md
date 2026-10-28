# Start Apache despite error in Virtual Host's SSL certificate file

Apache is configured with name-based SSL virtual hosting. Virtual users can upload their own certificates, but Apache refuses to start when one certificate file is missing or has the wrong name.

How can Apache start with the other virtual hosts while skipping only the virtual host whose certificate is invalid? Conditional `<If>` blocks around `VirtualHost` or `SSLEngine` do not work because those directives are not permitted in that context.

The desired behavior is for Apache to start reliably and for certificate problems to be detected before a restart rather than taking down the server.
