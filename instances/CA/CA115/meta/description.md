# Disabling PHP Deprecation Warnings and Notices

I've been using and configuring PHP, but now I'm stuck in a weird problem, so I am going to ask you guys for help.

I don't want to see Deprecation Warnings and Notices in a production server, however I would like to see other error messages, such as Syntax Errors for example.

I'm running PHP 5.3.3-1ubuntu9.3 with Suhosin-Patch on Ubuntu 10.10.

In my `/etc/php5/apache2/php.ini` I've the following line:

```ini
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE
```

I've restarted the webserver. In the virtual host configuration there is no `php_admin_value` changing this configuration, and in the folder there isn't any `.htaccess` file.

Nevertheless Deprecation Warnings and Notices are still shown.

## Accepted answer

PHP has several places where configuration can be set, from global to specific: `php.ini`, modular configuration in `conf.d`, Apache virtual-host configuration, `.htaccess`, and finally the executed source code. A setting lower in that precedence list can override an earlier setting. The source can alter the setting with `error_reporting()` or `ini_set("error_reporting", ...)`; that source-level setting overrides the earlier configuration. Compile errors can still show because the script is not executed in that case.
