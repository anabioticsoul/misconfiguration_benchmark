# Spring ORM 5.3.x with Hibernate 6.x

A Java application using Spring Framework 5.3.19 and Hibernate ORM 6.0.1.Final fails while loading `org.springframework.orm.hibernate5.SpringSessionContext`:

```
Unable to load class [org.springframework.orm.hibernate5.SpringSessionContext]
Caused by: java.lang.NoClassDefFoundError: javax/transaction/SystemException
Caused by: java.lang.ClassNotFoundException: javax.transaction.SystemException
```

The project includes Spring Core, Spring Context, Spring ORM, Hibernate Core, MySQL Connector/J, and a JPA API dependency, but does not explicitly include the Javax Transaction API. The application is run as a Java application on a modern JDK. Please troubleshoot the dependency/configuration issue while preserving the existing Spring and Hibernate versions.
