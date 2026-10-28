# CD218 build requirements

Use `ubuntu:22.04` as the clean source. Install the Ubuntu PHP CLI package and
its packaged Xdebug extension. The base layer must contain a working Xdebug 3
CLI configuration with `xdebug.mode=debug`. The instance layer overwrites that
file with the legacy options `xdebug_remote_enable=1` and
`xdebug_autostart=1`, leaving debugger mode disabled as described by the source.

The final image must remain alive with the configured runtime command. The
harnesses invoke PHP directly and must not copy benchmark metadata or harness
files into the image.
