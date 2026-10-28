# Calling undefined curl_init() function in IIS

## Question

I have IIS 10 and my program calls curl_init function to make API calls. But I get this error: *"Call to undefined function curl_init()"*. Also when I look at the output of phpinfo() there is no cURL section shown.

I've triple checked the php.ini file for `extension=curl` and the `ext` folder for `php_curl.dll`. I also downloaded ssleay32.dll and libeay32.dll files to the system32 folder in C:. I restarted the server a couple of times. Still, when I check phpinfo() there is no curl section there.

The question discusses whether the PHP path must be added to the Windows environment variables for DLL dependencies, noting that another WampServer machine works without that manual change.

## Accepted Answer

After searching for the cause, the accepted answer reports that adding the PHP path to the environment variables made the cURL section appear in phpinfo() and made the error disappear. The answer's steps are: Windows Start -> Edit the system environment variables -> Advanced -> Environment Variables -> New. It also notes that the different WampServer behavior may be due to WampServer's own configuration.
