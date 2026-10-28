# How can I display and log PHP errors on IIS7?

We're running PHP 5.2.5 on an IIS 7 Server and we're having problems making PHP errors visible. At the moment whenever we have a PHP error the server sends back a 500 error with the message "The page cannot be displayed because an internal server error has occurred."

This might be a good setting for production websites but it's rather annoying on a development server.

I have tried configuring `php.ini` to display errors to the screen as well as log them to a specific folder but it seems that the Server catches all errors before and prevents any handling by PHP.

Does someone know what we have to do to make IIS display PHP errors on screen?

The accepted guidance is to verify `error_reporting = E_ALL` and `display_errors = On`, then inspect IIS 7 `system.webServer->httpErrors`. Change `errorMode` from `DetailedLocalOnly` to `Detailed`, or otherwise remove the server-level HTTP error override when appropriate. Detailed errors should only be exposed on a development server.
