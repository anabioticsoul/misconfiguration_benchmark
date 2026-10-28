# Error using mod_jk in httpd: undefined symbol: ap_get_server_version

# Question

We just recently installed a new RHEL7 server. Inside of this server, we have a bunch of vhosts, and inside the vhosts there is a couple of lines that looks like this -

```
JkMount /rules_engine/rulesApi/rules/* rulesEngine
JkMount /api/* rulesEngine
JkMount /rules_editor/* rulesEngine
```

So in order to handle this, we use mod\_jk inside of our apache configuration. However, when I try to start apache, I get the following error -

```
Syntax error on line 1 of /etc/httpd/conf.d/mod_jk.conf: Cannot load /etc/httpd/modules/mod_jk.so into server: /etc/httpd/modules/mod_jk.so: undefined symbol: ap_get_server_version
```

The mod\_jk.conf file is inside of /etc/httpd/conf.d, and it looks like this -

```
LoadModule jk_module /etc/httpd/modules/mod_jk.so
JkWorkersFile /etc/httpd/conf.d/workers.properties
JkLogFile /var/log/httpd/mod_jk.log
Change to WARN or ERROR for Prod
JkLogLevel info
JkShmFile /var/log/httpd/mod_jk.shm
JkMount /rulesApi/rules/* rulesEngine
JkMount /api/* rulesEngine
JkMount /* rulesEditor
JkMount /rules_editor/* rulesEditor
```

Any ideas as to what that error means, and how I can get httpd to start?

Thanks.



### Question Comments

=== COMMENTS ===
- (1) Daniel Ferradal [Commented Aug 31, 2016 at 8:18]: Seems like the mod_jk you got, wherever from that is, is not compiled for the version of httpd you are using. Where did you get it?


---


# Accepted Answer

It seems like mod\_jk.so file not present in /etc/httpd/modules directory Or mod\_jk.so which you have added its not compatible with your apache version.
which apache you have used 2.2/2.4?
for apache 2.4 download mod\_jk-1.2.37 and than try it works for me.

May this link help you:
<http://www.linuxquestions.org/questions/linux-server-73/apache-2-4-2-and-tomcat-connector-1-2-37-error-help-4175421221/>