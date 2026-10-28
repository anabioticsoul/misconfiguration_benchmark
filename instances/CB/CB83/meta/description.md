# Changing the default apache port doesn't work

# Question

I am trying to run apache and nginx together. I want that apache should listen to port 8080 and nginx should listen to 80. For that, I have modified the ports.conf to Listen to 8080 and also modified the virtual host configuration. After restart, the server starts without any error but I am unable to access the url.

/etc/apache2/sites-avaialbled/mysite

```
<VirtualHost *:8080>
  ServerName myproject
  ServerAdmin [email protected]

  DocumentRoot /var/www
  <Directory />
    Options FollowSymLinks
    AllowOverride None
  </Directory>
  <Directory /trac>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    allow from all
  </Directory>

  ErrorLog /var/log/apache2/error.log
  LogLevel warn
  CustomLog /var/log/apache2/access.log combined
  ServerSignature On

<Location /svn>
   DAV svn
   SVNParentPath /svn

   AuthType Basic
   AuthName "Subversion Repository"
   AuthUserFile /etc/svnauth
   Require valid-user
   AuthzSVNAccessFile /etc/svnaccess
</Location>

<Location /trac>
   SetHandler mod_python
   PythonHandler trac.web.modpython_frontend
   PythonOption TracEnvParentDir /trac
   PythonOption TracUriRoot /trac

   AuthType Basic
   AuthName "Trac"
   AuthUserFile /etc/svnauth
   Require valid-user
</Location>

</VirtualHost>
```

/etc/apache2/ports.conf

```
NameVirtualHost *:8080
Listen 8080

<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/apache2/sites-available/default-ssl
    # to <VirtualHost *:443>
    # Server Name Indication for SSL named virtual hosts is currently not
    # supported by MSIE on Windows XP.
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
```

Do I need to change something else here?

### Question Comments

=== COMMENTS ===
- (1) djdomi [Commented Aug 11, 2019 at 19:58]: Possible duplicate of How to choose which IP apache2 uses globally
- (2) Jenny D [Commented Aug 13, 2019 at 6:50]: What is the error message you are getting?

---

# Accepted Answer

Verify that there are no other Listen directives anywhere: `grep -ri listen /etc/apache/*`

Also show what netstat says apache IS listening on: `netstat -plnt | grep http`

Replace **httpd** with the name of the apache binary on your system


### Answer Comments

=== COMMENTS ===
- (1) gentrobot [Commented Oct 20, 2012 at 11:11]: Replacing httpd did work
