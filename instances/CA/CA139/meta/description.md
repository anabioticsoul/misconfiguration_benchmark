# How to set PHP memory_limit in DDEV

## Question

I am running a local shopware6 environment inside Docker with DDEV configuration.

After trying to fetch all products (about 11,000) via `https://sw6.ddev.site/api/search/product` I get this error:

`Error: Allowed memory size of 1073741824 bytes exhausted (tried to allocate 88686592 bytes)`

It points to `/var/www/html/vendor/symfony/http-foundation/Response.php`, where `sendContent()` echoes the response content.

I know from the staging server how to adjust the memory limit, but locally I set `memory_limit = 1024M`. Running `<?php phpinfo(); ?>` in the container shows `memory_limit => -1 => -1`.

The edited file is `/var/www/html/config/etc/php7/conf.d/php.ini`:

```ini
[Date]
date.timezone="UTC"

memory_limit = 1024M
upload_max_filesize = 6M
max_execution_time = 30
```

### Question comments

- Justinas suggested first resolving why the application uses so much memory and batching requests.
- The asker noted that live and development servers do not show the error and that Docker has 8 GB available.
- Justinas explained that more products require more RAM and that raising the limit is temporary.
- rfay clarified that the issue is the PHP `memory_limit`, not Docker's allocation.
- The asker noted that the `php.ini` content resets to its default after entering the container.

## Accepted answer

The default 1 GB that DDEV sets up is more than most production sites allow. To change it, create a configuration file in `.ddev/php/<name>.ini`; for example, create `.ddev/php/memlimit.ini` with:

```ini
[PHP]
memory_limit = 2G
```

This changes the limit, but the application should still be investigated because it is using so much memory.
