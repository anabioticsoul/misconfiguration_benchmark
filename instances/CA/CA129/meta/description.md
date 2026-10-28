# Apache2 - SSL is not working

## Question

I am currently trying to install an SSL certificate issued through Namecheap by Comodo. I am however currently having issues. In the error log, I have this error:

```
[Sun Apr 10 17:59:06.567045 2016] [mpm_prefork:notice] [pid 613] AH00169: caught SIGTERM, shutting down
[Sun Apr 10 17:59:07.662580 2016] [ssl:emerg] [pid 28664] AH02572: Failed to configure at least one certificate and key for my-domain.com:443
[Sun Apr 10 17:59:07.662679 2016] [ssl:emerg] [pid 28664] SSL Library Error: error:140A80B1:SSL routines:SSL_CTX_check_private_key:no certificate assigned
[Sun Apr 10 17:59:07.662690 2016] [ssl:emerg] [pid 28664] AH02311: Fatal error initialising mod_ssl, exiting. See /var/log/apache2/error.log for more information
AH00016: Configuration Failed
```

The files I got from Namecheap are as follows:

* my-domain_com.crt
* my-domain_com.p7k
* my-domain_com.ca-bundle

I generated a server.key file as well as a server.csr file.

My apache configuration is as follows:

```
<IfModule mod_ssl.c>
  <VirtualHost *:443>
    ServerAdmin webmaster@localhost

    ServerName my-domain.com

    DocumentRoot /var/www/html

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    SSLEngine on

    #   Server Certificate Chain:
    #   Point SSLCertificateChainFile at a file containing the
    #   concatenation of PEM encoded CA certificates which form the
    #   certificate chain for the server certificate. Alternatively
    #   the referenced file can be the same as SSLCertificateFile
    #   when the CA certificates are directly appended to the server
    #   certificate for convinience.
    SSLCertificateChainFile /etc/apache2/ssl.crt/minecraft-multiplayer_com.crt
    SSLCertificateKeyFile /etc/apache2/ssl.crt/server.key
    SSLCACertificateFile /etc/apache2/ssl.crt/minecraft-multiplayer_com.ca-bundle

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>

    BrowserMatch "MSIE [2-6]" \
        nokeepalive ssl-unclean-shutdown \
        downgrade-1.0 force-response-1.0
    # MSIE 7 and newer should be able to use keepalive
    BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

  </VirtualHost>
</IfModule>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
```

I have set up SSL on apache with `a2enmod ssl`. I'm not too familiar with setting up certificates with apache, so any help you could provide is appreciated.

### Question Comments

=== COMMENTS ===
- (1) Castaglia [Commented Apr 11, 2016 at 3:54]: Per the Apache SSLCertificateFile docs, I think you want to use SSLCertificateFile /etc/apache2/ssl.crt/minecraft-multiplayer_com.crt, since SSLCertificateFile obsoletes SSLCertificateChainFile.

## Accepted Answer

You are missing the server certificate and on the other hand duplicating some files. I would use the ones below assuming minecraft-multiplayer_com.ca-bundle contains the certificate chain from the server certificate to the Root CA

```
SSLCertificateFile    /etc/apache2/ssl.crt/minecraft-multiplayer_com.crt
SSLCertificateKeyFile /etc/apache2/ssl.crt/server.key
SSLCertificateChainFile /etc/apache2/ssl.crt/minecraft-multiplayer_com.ca-bundle
```
