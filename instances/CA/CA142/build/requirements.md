# CA142 build requirements

Build from `ubuntu:22.04`. The base layer installs Java 11 and the pinned
AWS SDK bundle version shown in the source stack trace, then compiles the
checkpoint probe. The probe uses the real AWS SDK S3 `putObject` operation
against a delayed local object endpoint and reads the effective timeout from a
clean Flink 1.14-style configuration using the Presto S3 option names.

The instance layer replaces only `/etc/flink/flink-conf.yaml` with the public
case's faulty dotted timeout names. The real SDK operation must fail before
repair and complete after both names are corrected. The checkpoint backend and
`s3p` paths must remain intact.
