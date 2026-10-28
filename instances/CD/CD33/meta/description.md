# php-fpm said "failed to post process the configuration"

# Question

I build php 5.3.5 with FPM, but when I trien to started the php-fpm daemon this way :

`sudo /usr/local/sbin/php-fpm start`

nothing happens (the programs show me the help)

and when I did this

sudo /usr/local/sbin/php-fpm -t

```
 Jan 25 09:54:59.634168 [ALERT] [pool www] pm.min_spare_servers(0) must be a positive value
```

`Jan 25 09:54:59.634293 [ERROR] failed to post process the configuration`

Any clue? I need to make this php work with nginx


---


# Accepted Answer

What kind of help do you receive?

You should set `pm.min_spare_servers` to something like `pm.min_spare_servers = 5`

Also check `pm.max_spare_servers` in php-fpm.conf



### Answer Comments

=== COMMENTS ===
- (1) Nisanio [Commented Jan 25, 2011 at 18:45]: The program print the "usage" message
- (2) unknown: 
- (3) Denis Kot [Commented Jan 26, 2011 at 7:42]: you mean something like: Usage: php-fpm [ flags ] < options >  Normal Options:     start stop restart pause zap       Default init.d options. ...? try to: 'sudo bash' then: '/usr/local/sbin/php-fpm start'  what about '/usr/local/sbin/php-fpm -t'? now it doesn't complain about config options?
- (4) dubis [Commented Jan 14, 2019 at 15:50]: I changed 2 lines in my php-fpm.conf this one pm.min_spare_servers = 1 and this one : pm.max_spare_servers = 5
- (5) unknown: 