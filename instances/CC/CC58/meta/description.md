# Apache Camel Spring configuration error

The application fails while loading its Spring XML configuration with:

```
Unable to locate Spring NamespaceHandler for XML schema namespace [http://camel.apache.org/schema/spring]
```

The configuration contains a Camel XML DSL context:

```xml
<camelContext id="camel" xmlns="http://camel.apache.org/schema/spring">
    <package>com.testdomain.testpackage</package>
</camelContext>
```

Please diagnose the missing Camel Spring XML support and make the application load this configuration successfully.

For Camel versions before 3.8, the Spring integration jar is required. For later versions, the Spring XML DSL is provided by the `camel-spring-xml` module as well.
