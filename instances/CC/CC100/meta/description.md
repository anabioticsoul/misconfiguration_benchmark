# Spring-Boot MVC Template Not Loading (404 Not Found)

A simple Spring Boot MVC application maps `/` to a controller method that returns `"index"`, and `src/main/resources/templates/index.html` exists. The controller is invoked, but requesting the page produces a 404 / Whitelabel Error Page instead of rendering the template.

The application uses `spring-boot-starter-web`, with the controller and template under the standard source directories. Diagnose the configuration/dependency issue so the root page renders, without bypassing MVC template resolution.
