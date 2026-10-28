# file size exceeded the maximum size permitted phpmyadmin

# Question

I am getting following error while uploading file to phpmyadmin:

> No data was received to import. Either no file name was submitted, or
> the file size exceeded the maximum size permitted by your PHP
> configuration. See

[![enter image description here](images/CA79/GHmz7.png)](https://i.sstatic.net/GHmz7.png)

**I am using `nginx` as web server.**

I have added following config in the nginx config file:

**in /etc/nginx/nginx.conf**

```
http {

  #default configs
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  #default configs


  #i have added following
  client_max_body_size 100M;
}
```

Here is my site config file

```
server {

  listen 80;
  listen [::]:80;
  
  index index.html index.php;

  server_name phpmy.xyz.com;

  root /usr/share/phpmyadmin;

  # i have added following
  client_max_body_size 500M;
  
  location / {
    try_files $uri $uri/ =404;
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;

    fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
  }

  location ~ /\.ht {
    deny all;
  }

}
```

here is my php ini config **/etc/php/7.4/cli/php.ini**:

```
max_execution_time = 3000
max_input_time = 600
max_input_vars = 100000
memory_limit = 100M


file_uploads = On
upload_max_filesize = 200M
max_file_uploads = 20

post_max_size = 200M
```

**PHP version: 7.4.3**

can anyone know what am i missing?


---


# Accepted Answer

PHP also has a `post_max_size` which can override `upload_max_filesize` as per the [documentation](https://www.php.net/manual/en/ini.core.php#ini.post-max-size). Set this value to be slightly higher than your upload value to cover other fields in that POST request.

> post\_max\_size int
>
> Sets max size of post data allowed. This setting also affects file upload. To upload large files, this value must be larger than upload\_max\_filesize. Generally speaking, memory\_limit should be larger than post\_max\_size. When an int is used, the value is measured in bytes. Shorthand notation, as described in this FAQ, may also be used. If the size of post data is greater than post\_max\_size, the $\_POST and $\_FILES superglobals are empty. This can be tracked in various ways, e.g. by passing the $\_GET variable to the script processing the data, i.e. , and then checking if $\_GET['processed'] is set.



### Answer Comments

=== COMMENTS ===
- (1) Sariful [Commented Apr 15, 2021 at 11:51]: I did that but still not working
- (2) djdomi [Commented Apr 15, 2021 at 17:40]: why not import from command line, there is no limit usually
- (3) Sariful [Commented Apr 16, 2021 at 10:13]: @djdomi I can do that for sure. But it would make things more easier if I give access to drag and drop the databases for migrating from one server to another server
- (4) djdomi [Commented Apr 19, 2021 at 4:59]: 1) PhpMyAdmin is an Admin-Panel which is in fact  IMHO out of scope for Server-Fault. 2) if you already have an SQL file mysql -u username database < file.sql is SUCH a problem for you? Please don't use Serverfault as this is for Business Users only. However, jokes beside - set client_max_body_size 10G; and also set the upload size for PHP to 1G - remind to restart, not only reload PHP-FPM AND NGINX - because the changes sometimes need a restart not only to reload - this has irritated me in the past