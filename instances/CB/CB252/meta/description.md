# File Not Found when running PHP with Nginx

# Question

Recently I installed the latest version of Nginx and looks like I'm having hard time running PHP with it.

Here is the configuration file I'm using for the domain:

```
server {
    listen       80;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.php;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    location ~ \.php$ {
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
        include        fastcgi_params;
    }
}
```

Here is the error I'm getting on the error log file:

> FastCGI sent in stderr: "Primary script unknown" while reading response header from upstream



### Question Comments

=== COMMENTS ===
- (1) DRC [Commented Jul 23, 2013 at 11:25]: why fastcgi_pass before the fastcgi settings ?
- (2) unknown: 
- (3) user2298995 [Commented Jul 23, 2013 at 13:05]: I don't know, these are the basic config I got when I first installed Nginx.
- (4) DRC [Commented Jul 23, 2013 at 13:19]: does switching it as last statement changes anything?
- (5) Mohammad AbuShady [Commented Jul 23, 2013 at 16:18]: fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name; why the word /scripts ?
- (6) Kzqai [Commented May 19, 2019 at 16:57]: For me it was the php-fpm.sock file pointing at the old version /run/php5.6/php-fpm.sock instead of /run/php7.1/php-fpm.sock


---


# Accepted Answer

Try another \*fastcgi\_param\* something like

```
fastcgi_param SCRIPT_FILENAME /usr/share/nginx/html$fastcgi_script_name;
```