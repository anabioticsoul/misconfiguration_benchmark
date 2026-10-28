# Spring Boot API returns 404/does not work

A Spring Boot application exposes `UserController` with `@RestController` and `@RequestMapping("/vs1")`. The endpoint is tested with:

```text
http://localhost:8080/vs1/users
```

The project uses Spring Boot 2.6.3 and includes `spring-boot-starter-web`, `spring-boot-starter-data-jpa`, and `spring-boot-starter-security` among its dependencies. The unauthenticated request in Postman does not work (the application reports an HTTP error rather than returning the users API response). What is missing or incorrectly configured, and how should it be fixed?

The controller mapping is:

```java
@RestController
@RequestMapping("/vs1")
public class UserController {
    @GetMapping("/users")
    public List<User> getAllUsers() { return userService.getAllUsers(); }
}
```
