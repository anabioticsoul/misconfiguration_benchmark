# correct configuration for nginx to localhost?

# Question

I just installed nginx and php fastcgi about an hour ago, and after reading examples of a quick starting configuration, and the nginx documentation etc, I just cant get it to work.

No matter what I change or try, I always only get the "Welcome to Nginx!" screen on "localhost/..." - I cant even call a simple index.html

My config:

(the stuff in the comments is what I tried out)

```
// default nginx stuff (unchanged)

server {
    #listen 80 default_server;
    #listen 80 default;
    listen 80;

    #server_name localhost;
    #server_name _;

    #access_log /var/log/nginx/board.access_log;
    #error_log /var/log/nginx/board.error_log;

    #root /var/www/board;
    #root /var/www/board/public/;
    root /var/www/board/public;

    #index index.html;
    index index.html index.htm index.php;
}
```

If I understand it right, this should be the easiest setup, right? just define `listen 80;` and `index index.html;` but I just cant get it to work

The file /var/www/board/public/index.html exists and has content

Before I waste 2 more hours trying out something, can someone of you give it a quick watch and tell me what I'm doing wrong? Thanks.


---


# Accepted Answer

Fundamentally you hadn't declare location which is what nginx uses to bind URL with resources.

```
 server {
            listen       80;
            server_name  localhost;

            access_log  logs/localhost.access.log  main;

            location / {
                root /var/www/board/public;
                index index.html index.htm index.php;
            }
       }
```