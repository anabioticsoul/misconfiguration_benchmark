# My log4j2 log file always have double output of each line. How can I stop the duplication please?

My log4j2 log file always has double output of each line. How can I stop the duplication please?

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <properties>
        <property name="name">CernerPharmacyWebApp</property>
        <property name="pattern">%d %-5p %C{2} (%F:%L) - %m%n</property>
    </properties>
    <Appenders>
        <RollingFile name="ROLLING_FILE" fileName="..\\logs\\${name}.log" filePattern="..\\logs\\${name}-%d{yyyy-MM-dd}-%i.log">
            <PatternLayout><pattern>${pattern}</pattern></PatternLayout>
            <Policies><TimeBasedTriggeringPolicy/><SizeBasedTriggeringPolicy size="50 MB"/></Policies>
        </RollingFile>
    </Appenders>
    <Loggers>
        <Root level="error"><AppenderRef ref="ROLLING_FILE"/></Root>
        <Logger name="com.jarmel.pharmacy.controls.BarCodeOrderServlet" level="trace">
            <AppenderRef ref="ROLLING_FILE"/>
        </Logger>
    </Loggers>
</Configuration>
```

How can I stop the duplication?
