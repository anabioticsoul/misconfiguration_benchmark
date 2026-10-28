package bench;

import java.io.FileInputStream;
import java.util.Properties;
import org.hibernate.SessionFactory;
import org.hibernate.cfg.Configuration;

public final class App {
  public static void main(String[] args) throws Exception {
    Properties properties = new Properties();
    try (FileInputStream input = new FileInputStream("/opt/cd107/application.properties")) {
      properties.load(input);
    }
    Configuration configuration = new Configuration();
    configuration.setProperties(properties);
    SessionFactory factory = configuration.buildSessionFactory();
    factory.close();
    System.out.println("Hibernate SessionFactory initialized");
  }
}
