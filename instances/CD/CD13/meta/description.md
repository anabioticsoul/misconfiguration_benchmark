# MySQL failed to start. Error 1053. Windows Server 2008 R2

# Question

I did a server restart for my web server and on restart, MySQL won't start.
If I use taskmanager to kill mysqld.exe and try the start from services console, it gets about 50% through the startup, stalls for a long time, and when it eventually finishes it shows the message:

"Windows could not start the MySQL service on Local Computer. Error 1053: The service did not respond to the start or control request in a timely fashion."

I had this once before and from memory all I had to do to correct it was delete the ib\_logfile0 and ib\_logfile1 files.

This has not helped this time.

Please help! I have 9 websites down and need them backup ASAP.

***UPDATE:***

An update on this... If I change the default database engine in my.ini from InnoDB to MyISAM and enable the skip\_innodb option, the MySQL service starts. But none of the websites work properly. (eg. If I go to a wordpress site, it loads the Wordpress installation wizard instead of the existing website). So I think it has something to do with INNODB.

***UPDATE 2:***

MySQL Error log last entries (before I deleted the .err file):

```
Version: '5.1.66-community'  socket: ''  port: 3306  MySQL Community Server (GPL)
130829  9:47:27 [Note] C:\Program Files\MySQL\MySQL Server 5.1\bin\mysqld: Normal shutdown

130829  9:47:27 [Note] Event Scheduler: Purging the queue. 0 events
130829  9:47:27  InnoDB: Starting shutdown...
130829  9:47:29  InnoDB: Shutdown completed; log sequence number 0 725928381
130829  9:47:29 [Note] C:\Program Files\MySQL\MySQL Server 5.1\bin\mysqld: Shutdown complete

130829 11:49:13 [Note] Plugin 'FEDERATED' is disabled.
130829 11:49:14  InnoDB: Initializing buffer pool, size = 47.0M
130829 11:49:15  InnoDB: Completed initialization of buffer pool
130829 11:49:18  InnoDB: Started; log sequence number 0 725928381
130829 12:04:26 [Note] Event Scheduler: Loaded 0 events
130829 12:04:26 [Note] C:\Program Files\MySQL\MySQL Server 5.1\bin\mysqld: ready for connections.
Version: '5.1.66-community'  socket: ''  port: 3306  MySQL Community Server (GPL)
130829 12:14:22 [Note] Plugin 'FEDERATED' is disabled.
130829 12:14:22 [Note] Plugin 'InnoDB' is disabled.
130829 12:14:23 [Note] Event Scheduler: Loaded 0 events
130829 12:14:23 [Note] C:\Program Files\MySQL\MySQL Server 5.1\bin\mysqld: ready for connections.
Version: '5.1.66-community'  socket: ''  port: 3306  MySQL Community Server (GPL)
130829 12:28:45 [Note] C:\Program Files\MySQL\MySQL Server 5.1\bin\mysqld: Normal shutdown

130829 12:28:45 [Note] Event Scheduler: Purging the queue. 0 events
130829 12:28:45 [Note] C:\Program Files\MySQL\MySQL Server 5.1\bin\mysqld: Shutdown complete

enter code here
enter code here
```



### Question Comments

=== COMMENTS ===
- (1) GioMac [Commented Aug 29, 2013 at 9:42]: what about mysql logs?
- (2) unknown: 
- (3) Reece [Commented Aug 29, 2013 at 23:43]: Are you referring to the "server_name".err files in the data folder? There was nothing useful in there that tells me where it's getting stuck or why.  Is there another logging that can be turned on?
- (4) GioMac [Commented Aug 29, 2013 at 23:46]: yes, please copy contents somewhere
- (5) Himalaya Garg [Commented Jan 12, 2020 at 10:42]: This link helped me find the error in console.
- (6) unknown: 


---


# Accepted Answer

I managed to get it working again late yesterday afternoon by removing the existing **ib\_logfile\*** files, the existing ***MYSERVER*.err** file (which was 981KB by the way) and making the following changes to the **my.ini** file:

* increased **innodb\_additional\_mem\_pool\_size** from 2M to 100M
* increased **innodb\_buffer\_pool\_size** from 47M to 100M
* increased **innodb\_log\_file\_size** from 24M to 50M

I don't know what possessed me to change these, but I was at a "almost at last resort" stage (which would've been to build a new VM guest and configure IIS/MySQL/PHP from scratch).  
How or why these changes made a difference, I don't know, but at least it's working again.



### Answer Comments

=== COMMENTS ===
- (1) HPWD [Commented Sep 15, 2017 at 15:32]: Our issues are nearly identical. About the only difference is the timestamp on the error log. :) To fix mine, I copied the contents of my database directory and then deleted everything inside. I uninstalled MariaDB and reinstalled. Confirmed the service did start and that I could connect using Heidi. After that, I stopped mysql (technically MariaDB since during install, I renamed mine to MariaDB), restored the contents from my backup using Beyond Compare to only bring back the files I wanted), and then started the service. NO idea why it worked that way but it is what it is.