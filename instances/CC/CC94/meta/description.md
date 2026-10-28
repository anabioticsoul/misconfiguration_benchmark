# Deploy Spring Boot with MySQL db to Heroku fails during gradle build

When deploying an almost-ready Spring Boot application to Heroku, the Gradle build fails. The same `./gradlew build -x check` command works locally. Heroku reports that it is installing OpenJDK 1.8, then cannot resolve `org.springframework.boot:spring-boot-gradle-plugin:3.1.0` because the plugin is compatible with Java 17 while the consumer is using Java 8.

The project applies Spring Boot Gradle plugin `3.1.0`, uses Gradle `7.6.1`, and declares `sourceCompatibility = '17'`. The relevant build command is:

```text
./gradlew build -x check
```

The deployment build log ends with a variant selection error stating that the Spring Boot Gradle plugin declares compatibility with Java 17 but the consumer requires Java 8. Locally, Java 17 is used and the build succeeds. How should the deployment environment be configured so the build uses the required Java version?
