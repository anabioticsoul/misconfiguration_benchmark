# Memcached configuration in Spring Boot app

The application uses `io.sixhours:memcached-spring-boot-starter:1.3.1`. It starts with a memcached service, but fails during startup with:

```
BeanCreationException: Error creating bean with name 'cacheAutoConfigurationValidator'
IllegalArgumentException: No cache manager could be auto-configured, check your configuration (caching type is 'GENERIC')
```

Relevant `application.properties`:

```properties
server.port: 9191
spring.cache.type=GENERIC
memcached.cache.servers: memcached:11211
memcached.cache.mode: static
memcached.cache.expirations: 3600, oembed:3600
memcached.cache.prefix: memcached:spring-boot
memcached.cache.namespace: namespace
memcached.cache.protocol: text
```

What is wrong, and how should the application be configured so the memcached starter supplies its cache manager?
