# Why does apache fail to start and only say "Configuration Failed" in error log?

# Question

Apache 2.2.23 fails to start for me, and the only entries in the log file are:

```
[Fri Feb 22 02:54:24 2013] [notice] suEXEC mechanism enabled (wrapper: /usr/sbin/suexec)
[Fri Feb 22 02:54:24 2013] [notice] Digest: generating secret for digest authentication ...
[Fri Feb 22 02:54:24 2013] [notice] Digest: done
Configuration Failed
[Fri Feb 22 02:54:57 2013] [notice] suEXEC mechanism enabled (wrapper: /usr/sbin/suexec)
[Fri Feb 22 02:54:57 2013] [notice] Digest: generating secret for digest authentication ...
[Fri Feb 22 02:54:57 2013] [notice] Digest: done
Configuration Failed
```

This has been driving me crazy. The network is fine, the disks are fine, the config files pass syntax checks, nothing has been changed since it previously worked. It just refuses to start, usually after some load spike.

I'd also mention that the restart mechanism includes doing kill -9 if graceful shutdown doesn't succeed.

I can't find anything on google or here about this.


---


# Accepted Answer

I finally found the solution to this, by removing all site configs, modules, and config directives.

Then, finally, the error log produced this gem:

```
[Fri Feb 22 03:04:22 2013] [emerg] (28)No space left on device: Couldn't create accept lock (/etc/httpd/logs/accept.lock.10752) (5)
[Fri Feb 22 03:04:24 2013] [warn] pid file /etc/httpd/run/httpd.pid overwritten -- Unclean shutdown of previous Apache run?
```

Now this, there were answers for on google. As mentioned [here](http://carlosrivero.com/fix-apache---no-space-left-on-device-couldnt-create-accept-lock) and other places, this error was caused by too many open semaphores from apache, as the disk was empty and writeable.

I solved this by running:

```
ipcs -s | grep www-data | awk '{print $2;}' | while read -r line; do ipcrm sem "$line"; done
```

and adding that to the restart script. Now, everything is fine. I assume there's a correlation between this and using kill -9, but without that I'm left with hung, unresponsive apache processes.



### Answer Comments

=== COMMENTS ===
- (1) user171959 [Commented May 1, 2013 at 13:27]: I've been bitten by this. Apache starting then dying with "Configuration Failed". Removing the semaphores fixes it. Something to do with kill -9 the server. Something more lucid out of apache would be nice.
- (2) unknown: 
- (3) Garrett Hyde [Commented Jun 13, 2013 at 15:03]: On my RHEL server, I had to replace grep www-data with grep apache , but your command worked. Thanks.
- (4) Unnikrishnan [Commented Jul 17, 2017 at 11:02]: Awesome man. Never expected this will work for me. But it worked :)
- (5) unknown: 