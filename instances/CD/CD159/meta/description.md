# Why is PHP Composer so slow?

# Question

Why is [PHP Composer](https://en.wikipedia.org/wiki/Composer_(software)) so slow when all I do is init a project with zero dependencies? Here are the commands I run:

```
composer init
```

<step through composer.json creation, define 0 zero dependencies>

```
composer install
```

Wait 3 minutes (not an exaggeration).

All composer has to do is pull in an autoloader and create `/vendor`, so why does it take so long? For that matter, why doesn't that step happen on `composer init`?

Is there a configuration option I can use to pull in a cached autloader and vendor upon `init`?



### Question Comments

=== COMMENTS ===
- (1) Mark Baker [Commented Feb 10, 2015 at 16:10]: More seriously: have you updated your composer in the last 30 days? There was a major performance improvement to the code just last month
- (2) unknown: 
- (3) axiac [Commented Feb 10, 2015 at 16:13]: I started compose install more than 5 minutes ago and it didn't complete yet. Composer version 1.0-dev (07c644ac229a21df80180598d8bb9aaba232eecb) 2015-02-03 12:51:10 . Maybe it's not the most recent version but still newer than your IBM mainframe ;-)
- (4) sjagr [Commented Feb 10, 2015 at 16:51]: Please confirm you've done composer self-update
- (5) AgmLauncher [Commented Feb 10, 2015 at 18:11]: I have, updated it last week or so.
- (6) Gordon Hickley [Commented Jun 25, 2015 at 3:47]: I struggled with composer update and composer self-update being incredibly slow. Taking more than 15 minutes and then throwing exceptions. I changed my router DNS servers (from Google's to my ISP's own) and composer worked like a charm.
- (7) unknown: 
- (8) levans [Commented Oct 9, 2018 at 18:23]: I was using my ISPs DNS servers, but based on the above comment, I put packagist.org in my /etc/hosts file and things started working. Note you shouldn't consider this canonical as packagist.org's IP is subject to change at any moment. However, it got me through an initial installation.
- (9) Constantin Galbenu [Commented Nov 23, 2018 at 9:30]: now, on my machine even composer --version is slow (otherwise a fast machine - Intel(R) Core(TM) i7-4790 CPU @ 3.60GHz, 16GB DDR3, SSD)


---


# Accepted Answer

Also, disable [Xdebug](https://en.wikipedia.org/wiki/Xdebug). Xdebug can cause Composer to take minutes even when running a command as simple as `composer --version`.