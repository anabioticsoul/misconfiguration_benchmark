#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends openjdk-11-jdk maven curl ca-certificates python3
rm -rf /var/lib/apt/lists/*
mkdir -p /opt/app/src/main/java/ritu/login
cat > /opt/app/pom.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>2.6.3</version><relativePath/></parent>
  <groupId>ritu.login</groupId><artifactId>login-register</artifactId><version>0.0.1-SNAPSHOT</version>
  <properties><java.version>11</java.version></properties>
  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
  </dependencies>
  <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
EOF
cat > /opt/app/src/main/java/ritu/login/Application.java <<'EOF'
package ritu.login;

import java.util.Collections;
import java.util.List;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
public class Application {
  public static void main(String[] args) { SpringApplication.run(Application.class, args); }
}

@RestController
@RequestMapping("/vs1")
class UserController {
  @GetMapping("/users")
  public List<User> getAllUsers() { return Collections.emptyList(); }
}

class User {
  public long getId() { return 0L; }
  public String getName() { return ""; }
}
EOF
cd /opt/app
mvn -q -DskipTests package
