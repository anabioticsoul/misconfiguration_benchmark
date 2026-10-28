import java.nio.file.*;
import java.util.*;

public class App {
  public static void main(String[] args) throws Exception {
    Properties p = new Properties();
    try (var in = Files.newInputStream(Path.of("/opt/ted-search/application.properties"))) { p.load(in); }
    if ("GENERIC".equalsIgnoreCase(p.getProperty("spring.cache.type", ""))) {
      System.err.println("org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'cacheAutoConfigurationValidator'");
      System.err.println("java.lang.IllegalArgumentException: No cache manager could be auto-configured, check your configuration (caching type is 'GENERIC')");
      System.exit(1);
    }
    if (!p.containsKey("memcached.cache.servers")) { System.err.println("memcached cache server configuration missing"); System.exit(2); }
    System.out.println("Started application with MemcachedCacheManager");
  }
}
