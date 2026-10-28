# ERR_CONTENT_LENGTH_MISMATCH on nginx and proxy on Chrome when loading large files

# Question

I'm getting the following error on my chrome console:

```
GET http://localhost/grunt/vendor/angular/angular.js net::ERR_CONTENT_LENGTH_MISMATCH
```

This only happens when a simultaneous requests are shot towards nginx e.g. when the browsers cache is empty and the whole app loads. Loading the resource above as a single requests succeeds.

Here are the headers to this requests, copied from Chrome:

```
Remote Address:127.0.0.1:80
Request URL:http://localhost/grunt/vendor/angular/angular.js
Request Method:GET
Status Code:200 OK
Request Headersview source
Accept:*/*
Accept-Encoding:gzip,deflate,sdch
Accept-Language:en-US,en;q=0.8,de;q=0.6,pl;q=0.4,es;q=0.2,he;q=0.2,gl;q=0.2
Cache-Control:no-cache
Connection:keep-alive
Cookie:gs_u_GSN-265185-D=1783247335:2567:5000:1377697930719
Host:localhost
Pragma:no-cache
Referer:http://localhost/grunt/
User-Agent:Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.122 Safari/537.36
Response Headersview source
Accept-Ranges:bytes
Cache-Control:public, max-age=0
Connection:keep-alive
Content-Length:873444
Content-Type:application/javascript
Date:Tue, 23 Sep 2014 11:08:19 GMT
ETag:"873444-1411465226000"
Last-Modified:Tue, 23 Sep 2014 09:40:26 GMT
Server:nginx/1.6.0
```

the real size of the file:

```
$ ll vendor/angular/angular.js
-rw-rw-r--  1 xxxx  staff  873444 Aug 30 07:21 vendor/angular/angular.js
```

As you can see `Content-Length` and the real size of the file are the same, so that's weird

And the nginx configuration to this proxy:

```
location /grunt/ {
    proxy_pass  http://localhost:9000/;
}
```

Any ideas?

Thanks

EDIT: found more info on the error log:

```
2014/09/23 13:08:19 [crit] 15435#0: *8 open() "/usr/local/var/run/nginx/proxy_temp/1/00/0000000001" failed (13: Permission denied) while reading upstream, client: 127.0.0.1, server: localhost, request: "GET /grunt/vendor/angular/angular.js HTTP/1.1", upstream: "http://127.0.0.1:9000/vendor/angular/angular.js", host: "localhost", referrer: "http://localhost/grunt/"
```



### Question Comments

=== COMMENTS ===
- (1) saber tabatabaee yazdi [Commented May 29, 2020 at 15:07]: in my case in laravel i just restart and refresh the page.


---


# Accepted Answer

It seems that under pressure, nginx tried to pull `angular.js` from its cache and couldn't due to permission issues. Here's what solved this issue:

```
root@amac-2:/usr/local/var/run/nginx $ chown -R _www:admin proxy_temp
```

`_www:admin` might be different in your case, depending which user owns the nginx process. See more information on ServerFault:

<https://serverfault.com/questions/534497/why-do-nginx-process-run-with-user-nobody>