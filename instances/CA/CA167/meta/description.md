# Apache and phpMyAdmin port conflict

A CodeIgniter program is run at `localhost:8080`. phpMyAdmin is then opened through `localhost`, but the connection is refused while the CodeIgniter program is running. The Apache configuration contains:

```apache
Listen 8080
ServerName localhost:8080
```

The MySQL settings use port `3306`, and phpMyAdmin is configured to connect to MySQL on that port. Diagnose the web-server configuration so the web application and phpMyAdmin can be used as intended without changing the MySQL port.
