# When i try to open swagger on a spring project, show a message Whitelabel Error Page. What is the problem?

# Question

This is the message:

Whitelabel Error Page
This application has no explicit mapping for /error, so you are seeing this as a fallback.

[enter image description here](https://i.sstatic.net/UVfqL.png)

The URLs that i tried:

* :8080/swagger-ui.html
* :8080/swagger-ui/
* :8080/swagger-ui/index.html
* :8080/swagger-ui
* :8080/v2/api-docs

My POM file:

```
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.1.3</version>
        <relativePath/> <!-- lookup parent from repository -->
    </parent>
    <groupId>br.com.boucher</groupId>
    <artifactId>boucher-core</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>io.springfox</groupId>
            <artifactId>springfox-boot-starter</artifactId>
            <version>3.0.0</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <version>8.1.0</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
            <version>1.5.5.Final</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>1.18.30</version>
                        </path>
                        <path>
                            <groupId>org.mapstruct</groupId>
                            <artifactId>mapstruct-processor</artifactId>
                            <version>1.5.5.Final</version>
                        </path>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok-mapstruct-binding</artifactId>
                            <version>0.2.0</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>

</project>
```

The SwaggerConfig file:

```
@Configuration
public class SwaggerConfig {
    @Bean
    public Docket api() {
        return new Docket(DocumentationType.SWAGGER_2)
                .select()
                .apis(RequestHandlerSelectors.any())
                .paths(PathSelectors.any())
                .build();
    }
}
```

The Spring Application:

```
@SpringBootApplication
public class BoucherCoreApplication {

    public static void main(String[] args) {

        SpringApplication.run(BoucherCoreApplication.class, args);
    }

}
```

One of the controllers:

```
@RestController
@RequestMapping("boucher/v1/estabelecimento")
@RequiredArgsConstructor
public class EstabelecimentoController {

    private final EstabelecimentoServicePort estabelecimentoServicePort;

    @PostMapping
    public ResponseEntity<?> save(@RequestBody @Valid EstabelecimentoSaveRequest request){

        Estabelecimento estabelecimento = estabelecimentoServicePort.save(EstabelecimentoMapper.INSTANCE.mapFrom(request));
        return new ResponseEntity<>(estabelecimento,HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<?> getAll(@RequestParam("latitude") Double latitude,
                                    @RequestParam("longitude") Double longitude,
                                    @RequestParam("raio") Double raio,
                                    @RequestParam(name = "page", required = false, defaultValue = "0") int page,
                                    @RequestParam(name = "size", required = false, defaultValue = "10") int size){

        Paginacao paginacao = new Paginacao(page,size);
        var estabelecimentos = estabelecimentoServicePort.getAllByRadius(latitude,longitude,raio,paginacao);
        return new ResponseEntity<>(estabelecimentos,HttpStatus.OK);
    }
    @GetMapping("/{id}")
    public ResponseEntity<?> get(@PathVariable Long id){
        return new ResponseEntity<>(estabelecimentoServicePort.getById(id),HttpStatus.OK);
    }
}
```

I've tried many things:

* change the version of swagger to 2.9;
* add the @EnableSwagger2 on SwaggerConfig class and the App class;
* change the dependency on pom file.

But nothing! What am i doing wrong?


---


# Accepted Answer

These are a few built-in dependencies, you can add them & let's spring do the rest unless you want to customize anything.

```
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-common</artifactId>
    <version>2.2.0</version>
</dependency>
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-api</artifactId>
    <version>2.2.0</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.2.0</version>
</dependency>
```

UPDATED:

Using the built-in dependencies, you can replace

```
<dependency>
    <groupId>io.springfox</groupId>
    <artifactId>springfox-boot-starter</artifactId>
</dependency>
```

by this

```
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.2.0</version>
</dependency>
```

Also remove your your config file `SwaggerConfig`

Then open `http://localhost:8080/swagger-ui/index.html` to test.