# CA115 build requirements

Use `ubuntu:22.04` as the clean source image. The base layer installs the Ubuntu
PHP CLI package and creates a small real PHP program under `/opt/ca115`.
The package refresh must retain the source image's HTTP mirror configuration,
use repository by-hash retrieval, and use bounded retries. The minimal Ubuntu
source image does not contain CA certificates, so switching its mirror to
HTTPS before installing packages makes the build fail.

The base configuration suppresses `E_DEPRECATED` and `E_NOTICE` while leaving
other errors visible. The fault overlay changes only the PHP program so that it
calls `error_reporting(E_ALL)` at runtime, demonstrating that source-level
configuration overrides the global setting. The program uses the effective
error mask to return failure only when deprecations are enabled, making the
real PHP command’s exit status testable. The repair is therefore limited to
removing that runtime override; the program and PHP installation must remain.

The image must retain `/bin/bash`, `php`, and the application file. It runs a
shell that tails indefinitely so the evaluator can copy the repaired allowed
file into a fresh container and execute the harnesses.
