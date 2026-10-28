Build an Ubuntu-based Spring Boot 2.0 OAuth2 password-grant application. The faulty client secret must be plain `secret`, while the repaired value is `{noop}secret`. The application must expose `/oauth/token`, use Spring Security 5 delegating password encoding for users, and remain runnable for investigation.

Use a single application entrypoint: `com.misconfigbench.ca11.Application`.
Java 11 requires explicit JAXB API and runtime dependencies for this legacy
OAuth2 implementation. Do not mistake missing runtime classes for the intended
client-secret configuration failure. Run harness requests inside the container;
no published host port is required.
