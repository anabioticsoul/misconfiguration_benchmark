# Hibernate dialect resolution failure

A Hibernate-based Spring Boot application fails during SessionFactory initialization with:

```text
org.hibernate.HibernateException: Access to DialectResolutionInfo cannot be null when 'hibernate.dialect' not set
```

The application uses PostgreSQL and its Hibernate properties include schema handling and SQL logging, but startup still cannot resolve the SQL dialect. Determine the configuration change needed so Hibernate can initialize successfully without changing application code.
