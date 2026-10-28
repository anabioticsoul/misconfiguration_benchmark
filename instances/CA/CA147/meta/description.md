# Change of `html_errors` in php.ini for CLI not taking effect

PHP CLI reports the loaded configuration file as `/etc/php/8.1/cli/php.ini`. That file contains the uncommented setting `html_errors = On`, but `php -i` still reports `html_errors => Off => Off`. Explain what is missing and make the intended CLI behavior effective.
