# How to configure Spring without persistence.xml?

I'm trying to set up spring xml configuration without having to create a further `persistence.xml`. But I'm constantly getting the following exception, even though I included the database properties in the `spring.xml`:

```
No persistence units parsed from {classpath*:META-INF/persistence.xml}
```

The relevant bean is:

```xml
<bean id="dataSource" class="org.springframework.jdbc.datasource.DriverManagerDataSource">
  <property name="driverClassName" value="org.h2.Driver" />
  <property name="url" value="jdbc:h2:mem:ca21;DB_CLOSE_DELAY=-1" />
  <property name="username" value="sa" />
  <property name="password" value="" />
</bean>

<bean id="entityManagerFactory" class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
  <property name="dataSource" ref="dataSource" />
  <property name="jpaProperties">
    <props>
      <prop key="hibernate.dialect">org.hibernate.dialect.H2Dialect</prop>
      <prop key="hibernate.hbm2ddl.auto">create-drop</prop>
    </props>
  </property>
</bean>
```

What am I missing here?

The configuration uses Spring Framework 5.3.32. The expected solution is to configure the entity package scan and persistence unit directly in the bean, without adding `persistence.xml`.
