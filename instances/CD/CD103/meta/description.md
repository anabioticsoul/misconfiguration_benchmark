# No Input file specified error with Nginx and FastCGI

Nginx serves a Drupal site through FastCGI. The site works normally, and nonexistent HTML URLs are handled by Drupal's 404 page. However, requesting a nonexistent PHP URL such as `/this-file-doesnt-exist.php` produces a white page containing `No input file specified.` instead of Drupal's 404 page.

The relevant configuration includes a regex PHP location that sends every `.php` request directly to PHP-FPM:

```nginx
server {
    listen 80 default_server;
    server_name example.test;
    root /var/www/example.com;
    index index.php;
    error_page 404 /index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

How should the configuration be changed so nonexistent PHP requests are handled by Drupal's normal 404 route rather than passed to FastCGI?
