# Access denied for user 'homestead'@'localhost' (using password: YES)

A Laravel 5.0 application running locally fails when `php artisan migrate` is executed. Its database configuration uses MySQL with `DB_HOST=localhost`, database `homestead`, user `homestead`, password `secret`, and the following socket:

```php
'unix_socket' => '/tmp/mysql.sock',
```

MySQL is running, but its `socket` variable reports `/var/run/mysqld/mysqld.sock`. How should the configuration be corrected so migrations can connect?
