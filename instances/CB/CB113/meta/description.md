# JAVA_HOME points to the wrong Java installation

A Java application launched from a shell cannot start even though Java is installed. The shell configuration sets `JAVA_HOME`, which Java-oriented shell scripts use to locate the runtime. The configured path must identify the active Java installation rather than a stale or nonexistent path.

Investigate the environment and correct the configuration so applications that use `JAVA_HOME` can run. Do not replace the Java installation or modify the application.
