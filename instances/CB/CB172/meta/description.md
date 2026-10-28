# How to set the PATH environment variable in Jenkins configuration on Windows?

# Question

When I run my build process on Windows Server 2008, it fails with the error message like

> Cannot run program "foo": CreateProcess: error=2, The system cannot find the file specified

I've already had a similar issue on Ubuntu Server and resolved it by adding the path to the folder with the binaries installed globally by Composer to the PATH variable in Jenkins config (`Manage Jenkins -> Configure System -> Global properties -> Environment variables: name=PATH, value=$PATH:$COMPOSER_HOME/vendor/bin/`):

![enter image description here](images/CB172/wsmFF.png)

(Due to a permissions moving `COMPOSER_HOME` outside of the `/root` directory was also needed to another one, accessible for Jenkins, was also needed.)

Now I tried the same on Windows, but it doesn't work. So, maybe I'm just setting the `PATH` wrong. What I've tried:

```
PATH
$PATH:D:\path\to\COMPOSER_HOME\vendor\bin

PATH
$PATH;D:\path\to\COMPOSER_HOME\vendor\bin

PATH
%PATH%D:\path\to\COMPOSER_HOME\vendor\bin

PATH
%PATH%;D:\path\to\COMPOSER_HOME\vendor\bin
```

How to set the `PATH` environment variable in Jenkins configs correctly working on Windows?



### Question Comments

=== COMMENTS ===
- (1) Rao [Commented Apr 7, 2016 at 11:28]: The last one that you tried should work. However, confused why do you want to add jenkins bin here? Instead you should it on the command line where you start jenkins itself. Also check if there are any spaces in the existing path variable. Check this please.
- (2) unknown: 
- (3) automatix [Commented Apr 7, 2016 at 11:47]: Thanks for your comment! To your question about "Jenkins bin": By default there is no bin folder in the Jenkins root directory. This bin is just a custom one I've created for storing there the binaries of the global ly installed Composer packages.
- (4) automatix [Commented Apr 7, 2016 at 11:48]: Just tried it out again with %PATH%;D:\path\to\Jenkins\bin . It doesn't work. And there are no spaces in the path.
- (5) Rao [Commented Apr 7, 2016 at 11:50]: May be you want to set it on the command line and restart jenkins and see?
- (6) automatix [Commented Apr 7, 2016 at 12:27]: Just checked this: Added D:\path\to\Jenkins\bin; to the Path , logged out, and restarted Jenkins. It hasn't helped.
- (7) unknown: 
- (8) dge [Commented Apr 7, 2016 at 12:50]: Check out the comments in this Q&A , it probably answers your question.
- (9) automatix [Commented Apr 8, 2016 at 11:44]: Thank you for the hint. I read the post, but there is no the Prepare jobs environment setting, there is no such option in my configs (maybe due to the newer version).
- (10) CJCombrink [Commented Jul 11, 2018 at 12:24]: Possible duplicate of modify PATH variable in jenkins master


---


# Accepted Answer

The issue I had was caused not by a wrong `Path` configuration. `%PATH%;D:\path\to\COMPOSER_HOME\vendor\bin` is correct.

![enter image description here](images/CB172/3bLfe.png)