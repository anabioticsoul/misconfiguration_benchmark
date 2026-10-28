# CD163 build requirements

Build from `ubuntu:22.04`. The base layer installs the distribution Apache HTTP
server, PHP CLI, and curl, and creates a real PHP-backed HTTP endpoint. The
instance layer enables Apache proxy modules and overlays the faulty
`ProxyErrorOverride On` setting. The runtime entrypoint starts PHP's local
server behind Apache so the benchmark measures real PHP error responses and
Apache's error-body handling.

No benchmark harness, metadata, or reference patch is copied into the image.
