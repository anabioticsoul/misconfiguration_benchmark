# Why does Jenkins complain that my reverse proxy setup is broken?

After updating Jenkins to version 1.591, a previously working reverse proxy reports that the setup is broken. The proxy is configured for `/jenkins`, with a prefixed backend and preserved host headers. The same setup was documented in the Jenkins wiki, and `--prefix=/jenkins` is configured for Jenkins.

Determine why requests through the `/jenkins` reverse-proxy endpoint fail and make the smallest configuration-only correction. Do not replace the service or bypass the proxy.
