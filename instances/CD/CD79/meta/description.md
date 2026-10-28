# Why can't I change document root in apache without error?

I'm trying to change my document root in Apache so I can start a new project and keep an old one available. When I change the document root, I get a 403 Forbidden error. The Apache error log reports: `client denied by server configuration` for `/Library/Webserver/CustomServer/`.

The custom document root should be served by Apache, but requests currently fail with HTTP 403. Diagnose the Apache configuration and restore access to the document root without weakening unrelated behavior.
