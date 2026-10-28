# Apache up in flames (AH00025). How to fix?

Apache 2.4 returns plain 500 pages for a directory using basic authentication from `.htaccess`. The log reports:

```text
AH00025: configuration error: couldn't check user: /writing/icons/rublev_trinity_icon.gif
```

What does AH00025 mean, and which `/etc/apache2/mods-enabled/auth*` module is needed?

The accepted answer is to load the authorization core module:

```apache
LoadModule authz_core_module modules/mod_authz_core.so
```
