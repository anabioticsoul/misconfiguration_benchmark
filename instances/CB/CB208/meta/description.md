# Why mysql phpmyadmin is not picking it's own port but instead it is picking apache port, Can't run codeigniter program while open phpmyadmin

# Question

So I have codeigniter program run in `localhost:8080` and when I want to open phpmyadmin throught `localhost` it's refuse to connect, then I access `localhost:8080`and i close my codeigniter program then phpmyadmin can be connected, but then I can't open two program at the same time.

This is my setting for my localhost

config.inc.php

```
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['port'] = '3306';
```

httpd.conf

```
Listen 8080
ServerName localhost:8080
```

php.ini

```
mysqli.default_port=3306
mysql.default_port=3306
```

my.ini

```
port=3306
```

Idk what's wrong with it.


---


# Accepted Answer

You have each part working separately, which is good start!

* mysql server is set to listen on port 3306, according to `my.ini`.
* apache is set to listen on port 8080, according to `httpd.conf`.
* phpMyAdmin's config file, `config.inc.php`, has the details of where it can connect to the mysql server. (You have included `config.inc.php` twice in your question by the way.)

If your CodeIgniter application is supposed to use the *same instance of Apache* as phpMyAdmin, then try reviewing a tutorial on how to set it up as `localhost:8080/phpmyadmin` and `localhost:8080/phpmyadmin`.

If your CodeIgniter application is supposed to use a *different instance of Apache* as phpMyAdmin, then there will be 2 httpd.conf files in different directories, and you should configure one to listen on port 8080, and the other on 8081.

If your CodeIgniter application is supposed to use a web server other than Apache, such as [PHP's built-in web server](https://www.php.net/manual/en/features.commandline.webserver.php) then you can tell that to listen on port 8081 instead.

Your question is tagged `xampp`, so you could try reviewing it's setup or [frequently asked questions](https://www.apachefriends.org/faq_windows.html%5D).