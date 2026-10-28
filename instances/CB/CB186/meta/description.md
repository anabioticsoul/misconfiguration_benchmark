# Docker-Compose NGINX and PHP - Can server html files but php gives bad gateway

# Question

I am trying to run nginx and php in docker-compose. I am able to build the containers and when I browse to an html file in my browser nginx serves it. But when I try to browse a php file I just get 502 Bad Gateway.

I'm aware that it may be something to do with the server name in my nginx configuration file, since the tutorial I got it from mentions this needs to be correct. But I've tried changing it to 'localhost' and 'ip-of-my-dockerhost' with same result.

I'm also aware I should look at the log files. However I am a bit of a linux novice. When I open Portainer, go to the container called Web and execute a shell, if I go:

```
cd /var/log/nginx ; ls
```

I see two files called access.log and error.log

however if I type

```
cat error.log
```

nothing happens! I get a new blank line with a blinking cursor that never outputs anything. The shell is then 'frozen' until I press CTRL-C to kill the task.

Contents of docker-compose.yml

```
version: "3.7"

#############################
#
# NETWORKS
#
#############################
networks:
  main:
    external:
      name: main
  default:
    driver: bridge

########################### 
#
#  SERVICES
#
###########################
services:
# All services / apps go below this line

  portainer:
    container_name: Portainer
    image: portainer/portainer:latest
    restart: unless-stopped
    command: -H unix:///var/run/docker.sock
    networks:
      - main
    ports:
      - "$PORTAINER_PORT:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $DATADIR/portainer:/data # Change to local directory if you want to save/transfer config locally
    environment:
      - TZ=$TZ

<<snip as don't believe relevant - a bunch of other containers here such as influxdb, radarr etc>>

  web:
    container_name: Web
    image: nginx:latest
    networks:
      - main    
    ports:
      - 81:80
    environment:
      - PUID=$PUID
      - PGID=$PGID 
    volumes:
      - $CONFIGDIR/nginx/site.conf:/etc/nginx/conf.d/default.conf
      - $DATADIR/nginx/code:/code
      
  php:
    container_name: php
    image: php:7-fpm
    networks:
      - main    
    ports:
      - 9090:9000
    environment:
      - PUID=$PUID
      - PGID=$PGID
    volumes:
      - $CONFIGDIR/nginx/site.conf:/etc/nginx/conf.d/default.conf
      - $DATADIR/nginx/code:/code
```

contents of $CONFIGDIR/nginx/site.conf

```
server {
    index index.php index.html;
    server_name 192.168.1.7;  ## This is the IP address of my docker host but I've also tried 'localhost' and 'php-docker.local'
    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;
    root /code;

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9090;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
```


---


# Accepted Answer

9090 is an exposed port. That means you can reach localhost:9090 for the PHP container but not for internal container communication.

Change your site.conf:

fastcgi\_pass php:9090; => fastcgi\_pass php:9000;



### Answer Comments

=== COMMENTS ===
- (1) Matthew Winter [2022-05-11T16:50:01+00:00]: Oh my goodness thank you soooo much. This has been driving me crazy for about 24 hours now you are my hero <3