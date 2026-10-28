# Cannot load configuration class in Spring Boot JPA

A Spring Boot 2.0.5 CRUD application fails during startup on JDK 18 with `Cannot load configuration class: net.guides.springboot2.crud.Application`. The nested cause is `InaccessibleObjectException`: Java cannot open `java.lang.ClassLoader.defineClass` to the unnamed module while Spring's older CGLIB code enhances the configuration class.

The example was written for Java 8 (`<java.version>1.8</java.version>`), but it is being run with JDK 18. Make the smallest configuration change needed so the application can start under the installed JDK while preserving the application and dependency versions.
