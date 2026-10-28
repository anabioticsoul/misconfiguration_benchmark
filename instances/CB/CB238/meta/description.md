# intermittent MySQL crashes with error "Fatal error: cannot allocate memory for the buffer pool"

# Question

**Added on edit, 2013-05-29:** Because this is a long question and discussion, here's a short summary of the question and the solution. I had problems running MySQL and Apache on a small Linux server (1 GB of memory). Apache kept demanding more memory, and as a consquence, the OS always killed MySQL to regain its memory. **The solution** was to replace Apache with Lighttpd. After I did that, the memory use on the server has been completely stable for several months now, and I've had no crashes of any sort. **end of edit**

I'm a beginner system administrator for a small virtual server. The main function of the server is to run the open-source [Moodle](http://moodle.org) course management system software, written in PHP. It relies on a database, in this case MySQL, and a web server, in this case Apache.

The server is running 64-bit CentOS release 5.8 (Final) with 1 GB of memory and 200 GB of disk, kernel version 2.6.18-308.8.2.el5xen. The MySQL version is Ver 14.14 Distrib 5.5.25, for Linux (x86\_64) using readline 5.1.

I don't think the Moodle software is such a heavy user of MySQL. Currently, only about ten teachers have access to it, and when I dump and compress with bzip2 the entire database, the resulting dump's size is less than 1 MB.

I set up the system a few months ago. The Apache server has been stable all this time, but MySQL has crashed several times. I've tried to learn about the optimal configuration from the web, and the last time I changed the `/etc/my.cnf` file, I used the file `/usr/share/doc/mysql55-server-5.5.25/my-large.cnf` that comes with MySQL as an example. The file says that it's meant for systems with 512 MB of memory, so I thought that using its memory-related configuration parameters would be safe for this system. (I had earlier configured MySQL's memory-related parameters with much smaller numbers, and I thought that might have led to the crashes. While the crashes still occur, the system is at least faster now.) These are the current contents of `/etc/my.cnf`:

```
# /etc/my.cfg

# The main and only MySQL configuration file on [WEBSITE ADDRESS REDACTED].
# Last updated 2012-09-23 by Teemu Leisti.

# Most of the memory settings are set to be the same as the example setting file
# /usr/share/doc/mysql55-server-5.5.25/my-large.cnf, which is meant for systems
# with 512M of memory.  This server currently has twice that, i.e. 1G of memory,
# which should make these settings safe.


[client]
default_character_set           = utf8
port                            = 3306
socket                          = /var/lib/mysql/mysql.sock

[mysqld]
character_set_filesystem        = utf8
character_set_server            = utf8
datadir                         = /var/lib/mysql
innodb_additional_mem_pool_size = 20M
innodb_buffer_pool_size         = 256M # You can set .._buffer_pool_size up to
                                       # 50..80% of RAM, but beware of setting
                                       # memory usage too high
innodb_data_file_path           = ibdata1:10M:autoextend
innodb_data_home_dir            = /var/lib/mysql
innodb_flush_log_at_trx_commit  = 1
innodb_lock_wait_timeout        = 50
innodb_log_buffer_size          = 8M
innodb_log_file_size            = 64M # Set .._log_file_size to 25% of buffer
                                      # pool size
innodb_log_group_home_dir       = /var/lib/mysql
interactive_timeout             = 60
key_buffer_size                 = 256M
long_query_time                 = 10
max_allowed_packet              = 1M
max_connections                 = 30
port                            = 3306
query_cache_limit               = 2M # see http://emergent.urbanpug.com/?p=61
query_cache_size                = 16M
read_buffer_size                = 1M
read_rnd_buffer_size            = 4M
skip_networking                 # Only local processes need to use MySQL
skip_symbolic_links             # Disabling symbolic_links is recommended to
                                # prevent assorted security risks
slow_query_log_file             = /var/log/mysql-slow-queries.log
socket                          = /var/lib/mysql/mysql.sock
sort_buffer_size                = 1M
table_open_cache                = 256
thread_cache_size               = 8
thread_concurrency              = 2 #    = number of CPUs * 2
user                            = mysql
wait_timeout                    = 10

[mysqld_safe]
log_error                       = /var/log/mysqld.log
open_files_limit                = 4096
pid_file                        = /var/run/mysqld/mysqld.pid

[mysqldump]
quick
max_allowed_packet              = 16M

[mysql]
no-auto-rehash
# Remove the next comment character if you are not familiar with SQL
safe-updates

[myisamchk]
key_buffer_size                 = 128M
sort_buffer_size                = 128M
read_buffer                     = 2M
write_buffer                    = 2M

[mysqlhotcopy]
interactive-timeout
```

As you can see in the configuration, the setup uses the InnoDB engine, and it only serves requests from localhost. Apart from the system administrator (me), Moodle is the only user of MySQL.

When MySQL crashes, the following is invariably written to the log file `/var/log/mysqld.log` (except for the timestamps, of course):

```
120926 08:00:51 mysqld_safe Number of processes running now: 0
120926 08:00:51 mysqld_safe mysqld restarted
120926  8:00:53 [Note] Plugin 'FEDERATED' is disabled.
120926  8:00:53 InnoDB: The InnoDB memory heap is disabled
120926  8:00:53 InnoDB: Mutexes and rw_locks use GCC atomic builtins
120926  8:00:53 InnoDB: Compressed tables use zlib 1.2.3
120926  8:00:53 InnoDB: Using Linux native AIO
120926  8:00:53 InnoDB: Initializing buffer pool, size = 256.0M
InnoDB: mmap(274726912 bytes) failed; errno 12
120926  8:00:53 InnoDB: Completed initialization of buffer pool
120926  8:00:53 InnoDB: Fatal error: cannot allocate memory for the buffer pool
120926  8:00:53 [ERROR] Plugin 'InnoDB' init function returned error.
120926  8:00:53 [ERROR] Plugin 'InnoDB' registration as a STORAGE ENGINE failed.
120926  8:00:53 [ERROR] Unknown/unsupported storage engine: InnoDB
120926  8:00:53 [ERROR] Aborting

120926  8:00:53 [Note] /usr/libexec/mysqld: Shutdown complete

120926 08:00:53 mysqld_safe mysqld from pid file /var/run/mysqld/mysqld.pid ended
```

Sometimes I can restart MySQL by commanding `service mysqld restart`, but sometimes that command fails with this output: `mysqld dead but subsys locked`. In these cases, the only thing I've been able to think of to recover the situation is to restart the server, after which MySQL can be restarted. In these cases, the output looks like this:

```
120926 11:43:48 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
120926 11:43:48 [Note] Plugin 'FEDERATED' is disabled.
120926 11:43:48 InnoDB: The InnoDB memory heap is disabled
120926 11:43:48 InnoDB: Mutexes and rw_locks use GCC atomic builtins
120926 11:43:48 InnoDB: Compressed tables use zlib 1.2.3
120926 11:43:48 InnoDB: Using Linux native AIO
120926 11:43:48 InnoDB: Initializing buffer pool, size = 256.0M
120926 11:43:48 InnoDB: Completed initialization of buffer pool
120926 11:43:48 InnoDB: highest supported file format is Barracuda.
InnoDB: The log sequence number in ibdata files does not match
InnoDB: the log sequence number in the ib_logfiles!
120926 11:43:48  InnoDB: Database was not shut down normally!
InnoDB: Starting crash recovery.
InnoDB: Reading tablespace information from the .ibd files...
InnoDB: Restoring possible half-written data pages from the doublewrite
InnoDB: buffer...
120926 11:43:51  InnoDB: Waiting for the background threads to start
120926 11:43:52 InnoDB: 1.1.8 started; log sequence number 466807107
120926 11:43:52 [Note] Event Scheduler: Loaded 0 events
120926 11:43:52 [Note] /usr/libexec/mysqld: ready for connections.
Version: '5.5.25'  socket: '/var/lib/mysql/mysql.sock'  port: 0  MySQL Community Server (GPL)
```

Here's what the command `free -m` currently outputs:

```
# free -m
             total       used       free     shared    buffers     cached
Mem:          1024        869        154          0         70        153
-/+ buffers/cache:        644        379
Swap:            0          0          0
```

Usually the "free" column is between 50 and 100 MB.

The output of command `ulimit -a`:

```
# ulimit -a
core file size          (blocks, -c) 0
data seg size           (kbytes, -d) unlimited
scheduling priority             (-e) 0
file size               (blocks, -f) unlimited
pending signals                 (-i) 8192
max locked memory       (kbytes, -l) 32
max memory size         (kbytes, -m) unlimited
open files                      (-n) 1024
pipe size            (512 bytes, -p) 8
POSIX message queues     (bytes, -q) 819200
real-time priority              (-r) 0
stack size              (kbytes, -s) 10240
cpu time               (seconds, -t) unlimited
max user processes              (-u) 8192
virtual memory          (kbytes, -v) unlimited
file locks                      (-x) unlimited
```

I haven't changed any of Moodle's setting or code files, except for `/var/www/html/moodle/config.php`, which looks like this (comment lines deleted to save space):

```
<?php
unset($CFG);  // Ignore this line
global $CFG;  // This is necessary here for PHPUnit execution
$CFG = new stdClass();
$CFG->dbtype    = 'mysqli';           // 'pgsql', 'mysqli', 'mssql', 'sqlsrv' or 'oci'
$CFG->dblibrary = 'native';           // 'native' only at the moment
$CFG->dbhost    = 'localhost';        // eg 'localhost' or 'db.isp.com' or IP
$CFG->dbname    = 'moodle';           // database name, eg moodle
$CFG->dbuser    = 'moodleuser';       // your database username
$CFG->dbpass    = '[REDACTED]';       // your database password
$CFG->prefix    = 'moodle_';          // prefix to use for all table names
$CFG->dboptions = array(
    'dbpersist' => false,       // should persistent database connections be
                                //  used? set to 'false' for the most stable
                                //  setting, 'true' can improve performance
                                //  sometimes
    'dbsocket'  => true,        // should connection via UNIX socket be used?
                                //  if you set it to 'true' or custom path
                                //  here set dbhost to 'localhost',
                                //  (please note mysql is always using socket
                                //  if dbhost is 'localhost' - if you need
                                //  local port connection use '127.0.0.1')
    'dbport'    => '',          // the TCP port number to use when connecting
                                //  to the server. keep empty string for the
                                //  default port
);
$CFG->passwordsaltmain = '[REDACTED]';
$CFG->wwwroot   = 'http://[REDACTED]';
$CFG->dataroot  = '/var/moodledata';
$CFG->directorypermissions = 02777;
$CFG->admin = 'admin';
date_default_timezone_set('Europe/Helsinki');
$CFG->disableupdatenotifications = true;
require_once(dirname(__FILE__) . '/lib/setup.php'); // Do not edit
```

(However, I have installed two Moodle plugins, [the Attendance module and block](http://docs.moodle.org/23/en/Attendance_module), but I don't see how they could be involved with this problem.)

Even after I updated `/etc/my.cnf` to its current state a week ago, MySQL has crashed a couple of times with the symptoms given above. Being a beginner in database administration, and after doing a lot of googling about this problem, I'm at a loss as to what to do next. Any suggestions? Should I post more configuration data?

**Addition on edit:**

The contents of file `/var/log/messages.1` are:

```
Sep 23 04:02:18 [machine name] syslogd 1.4.1: restart.
Sep 26 08:00:51 [machine name] kernel: mysqld invoked oom-killer: gfp_mask=0x201d2, order=0, oomkilladj=0
Sep 26 08:00:51 [machine name] kernel:
Sep 26 08:00:51 [machine name] kernel: Call Trace:
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff802c1bd5>] out_of_memory+0x8b/0x203
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff8020fa49>] __alloc_pages+0x27f/0x308
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff802139c9>] __do_page_cache_readahead+0xc8/0x1af
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff8021423a>] filemap_nopage+0x14c/0x360
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff80208e9d>] __handle_mm_fault+0x444/0x144f
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff80263929>] _spin_lock_irqsave+0x9/0x14
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff8023f468>] lock_timer_base+0x1b/0x3c
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff80266d94>] do_page_fault+0xf72/0x131b
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff802e5f4f>] sys_io_getevents+0x311/0x359
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff802e4e56>] timeout_func+0x0/0x10
Sep 26 08:00:51 [machine name] kernel:  [<ffffffff8025f82b>] error_exit+0x0/0x6e
Sep 26 08:00:51 [machine name] kernel:
Sep 26 08:00:51 [machine name] kernel: Mem-info:
Sep 26 08:00:51 [machine name] kernel: DMA per-cpu:
Sep 26 08:00:51 [machine name] kernel: cpu 0 hot: high 0, batch 1 used:0
Sep 26 08:00:51 [machine name] kernel: cpu 0 cold: high 0, batch 1 used:0
Sep 26 08:00:51 [machine name] kernel: DMA32 per-cpu:
Sep 26 08:00:51 [machine name] kernel: cpu 0 hot: high 186, batch 31 used:117
Sep 26 08:00:51 [machine name] kernel: cpu 0 cold: high 62, batch 15 used:53
Sep 26 08:00:51 [machine name] kernel: Normal per-cpu: empty
Sep 26 08:00:51 [machine name] kernel: HighMem per-cpu: empty
Sep 26 08:00:51 [machine name] kernel: Free pages:        7256kB (0kB HighMem)
Sep 26 08:00:51 [machine name] kernel: Active:241649 inactive:0 dirty:0 writeback:0 unstable:0 free:1814 slab:4104 mapped-file:1153 mapped-anon:240592 pagetables:3298
Sep 26 08:00:51 [machine name] kernel: DMA free:3268kB min:32kB low:40kB high:48kB active:0kB inactive:0kB present:9068kB pages_scanned:0 all_unreclaimable? yes
Sep 26 08:00:51 [machine name] kernel: lowmem_reserve[]: 0 994 994 994
Sep 26 08:00:51 [machine name] kernel: DMA32 free:3988kB min:4016kB low:5020kB high:6024kB active:966596kB inactive:0kB present:1018080kB pages_scanned:6327262 all_unreclaimable? yes
Sep 26 08:00:52 [machine name] kernel: lowmem_reserve[]: 0 0 0 0
Sep 26 08:00:52 [machine name] kernel: Normal free:0kB min:0kB low:0kB high:0kB active:0kB inactive:0kB present:0kB pages_scanned:0 all_unreclaimable? no
Sep 26 08:00:52 [machine name] kernel: lowmem_reserve[]: 0 0 0 0
Sep 26 08:00:52 [machine name] kernel: HighMem free:0kB min:128kB low:128kB high:128kB active:0kB inactive:0kB present:0kB pages_scanned:0 all_unreclaimable? no
Sep 26 08:00:52 [machine name] kernel: lowmem_reserve[]: 0 0 0 0
Sep 26 08:00:52 [machine name] kernel: DMA: 1*4kB 2*8kB 1*16kB 1*32kB 2*64kB 2*128kB 1*256kB 1*512kB 2*1024kB 0*2048kB 0*4096kB = 3268kB
Sep 26 08:00:52 [machine name] kernel: DMA32: 17*4kB 2*8kB 2*16kB 1*32kB 0*64kB 0*128kB 1*256kB 1*512kB 1*1024kB 1*2048kB 0*4096kB = 3988kB
Sep 26 08:00:52 [machine name] kernel: Normal: empty
Sep 26 08:00:52 [machine name] kernel: HighMem: empty
Sep 26 08:00:52 [machine name] kernel: 1214 pagecache pages
Sep 26 08:00:52 [machine name] kernel: Swap cache: add 0, delete 0, find 0/0, race 0+0
Sep 26 08:00:52 [machine name] kernel: Free swap  = 0kB
Sep 26 08:00:52 [machine name] kernel: Total swap = 0kB
Sep 26 08:00:52 [machine name] kernel: Free swap:            0kB
Sep 26 08:00:52 [machine name] kernel: 262144 pages of RAM
Sep 26 08:00:52 [machine name] kernel: 8320 reserved pages
Sep 26 08:00:52 [machine name] kernel: 22510 pages shared
Sep 26 08:00:52 [machine name] kernel: 0 pages swap cached
Sep 26 08:00:52 [machine name] kernel: Out of memory: Killed process 1371, UID 27, (mysqld).
```

and then lines related to the reboot at 11:42.

**Addition on edit #2:**

I tried to comment on Michael's answer, but I ran afoul of the character limit of comments, so I'm answering here.

Thanks for you answer, Michael. I just edited my question to include the contents of the machine's system log at the time of the crash. (CentOS seems to call its system log `/var/log/messages`.)

Yes, both the MySQL and system logs appear nearly identical with the ones in the question you linked to. And now that you mention it, it's sort of obvious that the `mysql restarted` message means that MySQL had already crashed. The system log indicates that it's `oom_killer` what got the process. In your earlier answer, you write: "First guess: apache child processes run amok." Seems to me that Apache is the obvious suspect here, too.

Earlier, I found article [Optimizing MySQL and Apache for Low Memory Usage, Part 1](http://emergent.urbanpug.com/?p=60). For configuring Apache, the author recommends: "First off, Apache. My first statement is, if you can avoid it, try to. Lighttpd and thttpd are both very good no frills webservers, and you can run lighttpd with PHP. Even if you're running a high volume site, you can seriously gain some performance by passing off static content (images and javascript files, usually) to a lightweight, super-fast HTTPd server such as Lighttpd."

I'm thinking of taking the author's advice, and have agreed with my client that next weekend, I'll replace Apache with Lighttpd on the server. I hope that'll solve the problems. Using two virtual servers is most likely not possible.

I hadn't thought that using two stable, mature open-source servers such as MySQL and Apache on the same machine, with a reasonable amount of memory, would be this troublesome.


---


# Accepted Answer

Please review [my answer](https://dba.stackexchange.com/questions/25077/mysql-innodb-crash-post-mortem/25083#25083) to [this recent question](https://dba.stackexchange.com/questions/25077/mysql-innodb-crash-post-mortem). I believe the circumstances are identical.

Do not change your MySQL configuration at this point, as MySQL is not the problem -- it's only a symptom of the problem... which is that you appear to have a system with a small amount of memory and zero swap space.

Your server is **not** crashing *"because"* memory can't be allocated for the buffer pool. Your server is crashing... and then is unable to subsequently restart due to the unavailability of system memory. All of the memory configured for the InnoDB buffer pool is requested from the system at mysql startup.

When you see this log message...

```
120926 08:00:51 mysqld_safe Number of processes running now: 0
```

...your server has already died. If it hasn't logged anything prior to this, it's not going to log anything about the first crash. The subsequent logs are from after the automatic attempt to restart.

Check your syslog and you should find messages where the kernel went looking for processes to kill due to an extreme out-of-memory condition.

Step 1 would probably be to add some swap space and/or allocating RAM if at all possible.

If that isn't possible, you might actually consider **decreasing** the innodb-buffer-pool size in your configuration. (I never thought I'd actually hear myself say that). As long as your database is small and your traffic is light, you may not need a buffer pool that large... and since the InnoDB Buffer Pool memory is all allocated at startup whether it's needed or not, this would free up some of your system's memory for whatever else is demanding it. (The 75% to 80%-of-total-RAM recommendation for sizing the buffer pool is only true if the whole server is dedicated to MySQL.)

Step 2 will be to review Apache's forking model and what you might need to do differently in the configuration to prevent it from overwhelming your server. It is pretty likely that uncontrolled growth in quantity or memory requirements of the Apache child processes is starting a cascade of events, resulting in the kernel killing MySQL to try to avoid a complete crash of the entire server.

Depending on how much flexibility you have, you might even consider two separate virtual machines for Apache and MySQL.