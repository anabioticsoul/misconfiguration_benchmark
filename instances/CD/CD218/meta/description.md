# I configured everything, but VSCode debugger is not working, why?

VSCode debugger is not working. I installed everything, and my configuration is:

- Windows 10 Pro
- WampServer 3.2.9 (working well, with a green icon)
- PHP 8.1.11 (I use this one, but I have other PHP versions installed on WampServer)
- Apache 2.4.41
- MariaDB 10.4.10
- Xdebug 3.1.5

VSCode debugger was working well before I updated WampServer (from 3.2.0 to 3.2.9) and added updates regarding that. I followed the wamserver.aviatechno.net instructions, including updating PHP, Apache, MariaDB, and MySQL.

I also followed community instructions, used `phpinfo()` with the Xdebug wizard, and followed the resulting instructions, but it did not work.

I added `xdebug_remote_enable = 1` and `xdebug_autostart = 1` to php.ini, and updated the Windows PATH to add the executable PHP path, but nothing happens.

What can be the issue?

## Relevant comments

A commenter pointed out that `xdebug_remote_enable` and `xdebug_autostart` are Xdebug 2 settings and do nothing in Xdebug 3, recommending the Xdebug upgrade guide. The question author later confirmed that removing those old settings and adding `xdebug.mode=debug` made the debugger work again.

## Accepted answer

I checked the Xdebug upgrade guide, deleted `xdebug_remote_enable=1` and `zend_extension=xdebug` lines added manually to the php.ini files, and added `xdebug.mode=debug` at the end of those files. It works perfectly again.
