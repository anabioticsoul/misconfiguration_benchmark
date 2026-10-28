# Config Error: This configuration section cannot be used at this path

# Question

I've encountered an error deploying a site to a server. When trying to load the home page, or access authentication on the new site in IIS, I get the error:

> Config Error: This configuration section cannot be used at this path.
> This happens when the section is locked at a parent level. Locking is
> either by default (overrideModeDefault="Deny"), or set explicitly by a
> location tag with overrideMode="Deny" or the legacy
> allowOverride="false".

More detail can be found here, in [Scenario 7](https://learn.microsoft.com/en-gb/archive/blogs/webtopics/troubleshooting-http-500-19-errors-in-iis-7) matches my hex error code.

The solution given on the linked site above is to set **Allow** for overrideModeDefault in the section mentioned in my error, in the *applicationHost.config* file. In my case, under **Security** in *system.webServer*. But if I look at the *applicationHost.config* on my local computer, where the site is properly deployed already, that section is set to **Deny**.

If this solution is correct, how is my local instance running just fine with the same *web.config*? According to my *applicationHost.config*, that section should be locked, but it's not. I'd prefer to not change the *applicationHost.config* file, because there are many other sites running on that server. Is there another solution?


---


# Accepted Answer

I had the same problem. Don't remember where I found it on the web, but here is what I did:

* Click "Start button"
* in the search box, enter "Turn windows features on or off"
* in the features window, Click: "Internet Information Services"
* Click: "World Wide Web Services"
* Click: "Application Development Features"
* Check (enable) the features. I checked all but CGI.



### Answer Comments

=== COMMENTS ===
- (1) hsCode [2022-09-14T09:08:28+00:00]: this error comes when you host mvc 3 or mvc 4 application in windows server 2016 or higher version... to solve it, you need to install, powershell version 2.0 and asp.net 3.5, asp.net 4.5 from add/remove features.
- (2) Josh P [2025-04-10T19:24:42+00:00]: I had the same error and my problem was I just needed to enable ASP.net 4.8.  Now my .asmx loads correctly in the browser.
- (3) blazenet01 [2026-02-14T05:55:20+00:00]: @hsCode To resolve it, make sure the required legacy components are installed via Add Roles and Features in Server Manager:  Enable .NET Framework 3.5 (includes ASP.NET 3.5)  Enable .NET Framework 4.5 Features (including ASP.NET 4.5)  Install/enable PowerShell 2.0 if the application depends on it