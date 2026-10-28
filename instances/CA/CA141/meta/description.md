# Error "AH02572: Failed to configure at least one certificate and key" - Contabo VPS and GoDaddy SSL certificate + domain

# Question

I've bought a Contabo VPS and domain + SSL certificate from GoDaddy.
I generated the CSR from my VPS using this guide: <https://uk.godaddy.com/help/apache-generate-csr-certificate-signing-request-5269>

I wanted to install the SSL certificate on the VPS.

```
openssl req -new -newkey rsa:2048 -nodes -keyout yourdomain.key -out yourdomain.csr
```

This command above is the one I used for generating CSR an private key to issue the certificate. The VPS has installed Rocky Linux 9. After receiving the certificate and installing it:

```
<VirtualHost *:443>
        ServerName mydomain.info
        ServerAlias mydomain.info
        DocumentRoot /var/www/mydomain.info/html
        RewriteEngine on
        RewriteCond %{HTTP_USER_AGENT} "Go-http-client/1.1" [NC]
        RewriteRule .* - [F,L]

        SSLEngine on
        SSLCertificateFile /etc/ssl/private/mydomain.crt
        SSLCertificateKeyFile /etc/ssl/private/privatekey.key
        SSLCertificateChainFile /etc/ssl/private/intermediate.crt

        ErrorLog /var/www/mydomain.info/log/error.log
        CustomLog /var/www/mydomain.info/log/requests.log combined
</VirtualHost>
```

Restarting the httpd service I've encountered this error (ssl\_error.log):

```
[Tue Apr 18 14:07:04.789184 2023] [ssl:emerg] [pid 1109:tid 1109] AH02572: Failed to configure at least one certificate and key for vmi1276647.contaboserver.net:443
[Tue Apr 18 14:07:04.789461 2023] [ssl:emerg] [pid 1109:tid 1109] SSL Library Error: error:0480006C:PEM routines::no start line (Expecting: DH PARAMETERS) -- Bad file contents or format - or even just a forgotten SSLCertificateKeyFile?
[Tue Apr 18 14:07:04.789473 2023] [ssl:emerg] [pid 1109:tid 1109] SSL Library Error: error:0480006C:PEM routines::no start line (Expecting: EC PARAMETERS) -- Bad file contents or format - or even just a forgotten SSLCertificateKeyFile?
[Tue Apr 18 14:07:04.789482 2023] [ssl:emerg] [pid 1109:tid 1109] SSL Library Error: error:0A0000B1:SSL routines::no certificate assigned
```

I was wondering if the domain I'm using is somehow "colliding" with this "vmi1276647.contaboserver.net" domain.

I have another Contabo VPS with SSL installed but this is the first time I'm trying to install manually an "external" SSL certificate on one of their servers. Am I missing something on apache configuration files or is it not possible to install an external SSL certificate o Contabo machines?

Thank you for your help!



### Question Comments

=== COMMENTS ===
- (1) Lety [Commented Apr 18, 2023 at 13:36]: It seems that the certificate is not formatted as expected. you should check if your certificate is in PEM format, usually if you cat it you should see the first row like -----BEGIN CERTIFICATE-----
- (2) brasojs [Commented Apr 18, 2023 at 14:39]: Hi, I think the file assigned to the directive "SSLCertificateFile" is in PEM format, with header and footer -----BEGIN CERTIFICATE----- / -----END CERTIFICATE-----. Do u know a tool/command with i can check the right format of the certificate?  I've also tried to switch the .crt file with the .pem file but it gives me the same error
- (3) Lety [Commented Apr 18, 2023 at 14:58]: check if keyfile is pem encoded, it should start with -----BEGIN PRIVATE KEY-----, also ca public certificate should be in pem format. read this httpd.apache.org/docs/2.4/mod/… . pem certificate is ascii readable file and if start with -----BEGIN CERTIFICATE----- is in pem format
- (4) brasojs [Commented Apr 18, 2023 at 15:08]: Pem file, crt file and private key are in PEM format. All of them start with the --- begin <> ----- header and ends with ----end <> ----- footer.  I've also tried to check modulus of all 3 files, to see if there is some mismatch, following this: link and the output turned out empty
- (5) brasojs [Commented Apr 18, 2023 at 15:28]: I found it!  I remebered all the confs get merged in 1 big file for apache to run all the configurations it needs, and i saw "SSLEngine on" also in the ssl.conf file and i commented it.  Now the server started and the SSL certificate seems installed. Bit stupid by me but now all is ok! @Lety ty for you help!


---


# Accepted Answer

**UPDATE**
I commented the "SSLEngine on" row from the ssl.conf file, located under the /etc/httpd/conf.d folder and now the server started and the SSL certificate seems installed.

I think that collided with the same directive in the VirtualHost conf.