# CB267 build requirements

- Start from the clean official `ubuntu:22.04` image.
- Install the Ubuntu PHP 8.1 CLI and cURL extension packages.
- Preserve the real PHP cURL extension, but relocate its `libcurl.so.4` runtime library into `/opt/php/lib` so it is unavailable until the runtime library search path is configured.
- The fault overlay must provide `/etc/environment` without `LD_LIBRARY_PATH`; the repair is adding `LD_LIBRARY_PATH=/opt/php/lib` there.
- Do not copy benchmark metadata, prompts, or harnesses into the image.
