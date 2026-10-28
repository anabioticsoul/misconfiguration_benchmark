# Why is WordPress loading blank pages on Nginx and PHP-FPM?

Nginx serves a PHP application through PHP-FPM, but requests for the PHP front controller fail with an empty or error response. Nginx includes `fastcgi_params` in its PHP location. Diagnose the configuration and make PHP requests execute normally without breaking static content.

The service is available on port 8080 inside the container. The relevant application is `/var/www/html/index.php` and the Nginx configuration is under `/etc/nginx/conf.d/`.
