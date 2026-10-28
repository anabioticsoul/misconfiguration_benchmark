# Apache httpd is restarting once a day with error AH00428: Parent: child process xxxxx exited with status 3221225477 -- Restarting

We have Apache/2.4.34 (Win32) OpenSSL/1.0.2o configuration for one of our user environment. The apache process exits once daily and restarts automatically. Things are working fine after the restart. They have applied patch(SSL). Could it be a reason for restart? IS there any compatibility issues with Apache/2.4.34 (Win32) OpenSSL/1.0.2o configuration

And The apache process increases memory to 1.5G in less than a day, around 12 midnight and its releasing automatically, then some times its restarting immediately, and some times its running fine for few hours and then its restarting with exit code 3221225477 . My doubt is how to check why its increasing memory and how to find reason for restarting?

normally error log is not reporting any error except AH00428: Parent: child process xxxxx exited with status 3221225477 -- Restarting.

They also reported XPath allocation errors, malformed requests, SSL certificate warnings, and a daily restart cron job. Their configuration uses mpm_winnt with ThreadsPerChild 360, MaxRequestsPerChild 0, SSL, and a third-party mod_aipx module.

## Accepted Answer

This problem often happens in Windows because of smaller Apache’s default stack size. And it usually happens when working with php code that allocates a lot of stacks.

To solve this issue, add the following at the end of apache config file, httpd.conf

```apache
<IfModule mpm_winnt_module>
    ThreadStackSize 8888888
</IfModule>
```

For more information refer to:
<https://stackoverflow.com/questions/1138269/apache-error-notice-parent-child-process-exited-with-status-3221225477-res>

### Answer Comments

- bhanu: I tried by increasing thread stack size, but no luck it is still restarting. so I tried by updating MaxRequestsPerChild 200000. with this change apache is no restarting but I do see all the webservices handled by apache are refreshing for every 2-3 hours. is it normal behaviour?
- Bright: The MaxRequestsPerChild directive sets the limit on the number of connections that an individual child server process will handle. When this directive is set to 0, the process will never expire.
- Costa: I spent hours trying to debug some 3rd party PHP code to figure out what php function or library was causing Apache to restart. All the while it was an "out of memory" error. Thanks, this fixed my issue.
