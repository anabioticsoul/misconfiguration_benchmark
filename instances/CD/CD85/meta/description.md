# ASP.Net MVC4 configuration error after installing MySQL Connector .NET

# Question

I'm creating a MVC4 web application project.When i'm using empty project and simply run it on browser it works fine.But the problem is when i'm trying to create a Internet application project instead of Empty project.Once i created internet application project and when trying to run it on browser it shows following configuration error.As i understood it's something related to MySQL connector assembly reference.Anyhow following is the error.

```
Server Error in '/' Application.

Configuration Error

Description: An error occurred during the processing of a configuration file required to service    this request. Please review the specific error details below and modify your configuration file appropriately. 

Parser Error Message: Could not load file or assembly 'MySql.Web.v20, Version=6.9.4.0, Culture=neutral, PublicKeyToken=c5687fc88969c44d' or one of its dependencies. The system cannot find the file specified.

Source Error: 


Line 265:      <providers>
Line 266:        <add name="AspNetSqlMembershipProvider" type="System.Web.Security.SqlMembershipProvider, System.Web, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" connectionStringName="LocalSqlServer" enablePasswordRetrieval="false" enablePasswordReset="true" requiresQuestionAndAnswer="true" applicationName="/" requiresUniqueEmail="false" passwordFormat="Hashed" maxInvalidPasswordAttempts="5" minRequiredPasswordLength="7" minRequiredNonalphanumericCharacters="1" passwordAttemptWindow="10" passwordStrengthRegularExpression=""/>
Line 267:        <add name="MySQLMembershipProvider" type="MySql.Web.Security.MySQLMembershipProvider, MySql.Web.v20, Version=6.9.4.0, Culture=neutral, PublicKeyToken=c5687fc88969c44d" connectionStringName="LocalMySqlServer" enablePasswordRetrieval="false" enablePasswordReset="true" requiresQuestionAndAnswer="true" applicationName="/" requiresUniqueEmail="false" passwordFormat="Clear" maxInvalidPasswordAttempts="5" minRequiredPasswordLength="7" minRequiredNonalphanumericCharacters="1" passwordAttemptWindow="10" passwordStrengthRegularExpression=""/>
Line 268:      </providers>
Line 269:    </membership>

Source File: C:\Windows\Microsoft.NET\Framework\v4.0.30319\Config\machine.config    Line: 267 

Assembly Load Trace: The following information can be helpful to determine why the assembly 'MySql.Web.v20, Version=6.9.4.0, Culture=neutral, PublicKeyToken=c5687fc88969c44d' could not be loaded.
```



### Question Comments

=== COMMENTS ===
- (1) Alexei Levenkov [Commented Oct 4, 2014 at 4:49]: It looks like someone changed machine.config instead of site's web.config - find out who and ask why it was done... Otherwise make sure to carefully read information in  "The following information can be helpful to determine why..." section of error message.
- (2) unknown: 
- (3) The Odd Developer [Commented Oct 4, 2014 at 5:00]: No no one changed it.Because i just created the project and tried to run it.
- (4) Alexei Levenkov [Commented Oct 4, 2014 at 5:06]: I'm pretty sure that it is not how one installed/created by .Net install (or Windows install, depending on version) looks like. So someone or something changed the machine.config file. If you don't care - just remove that line and it should fix your problem (possibly breaking something else that made the change...).
- (5) The Odd Developer [Commented Oct 4, 2014 at 5:13]: You mean to remove the line from web.config file?
- (6) The Odd Developer [Commented Oct 4, 2014 at 5:59]: I'm confusing why it works fine for empty project and not for internet application project.
- (7) unknown: 
- (8) Alexei Levenkov [Commented Oct 4, 2014 at 6:06]: Because one reads the element and tries to instantiate objects while other does not.
- (9) The Odd Developer [Commented Oct 4, 2014 at 6:32]: OK.I understood.Can you please tell me what should i do to avoid from this issue?I checked this issue on internet, but didn't found a solution.
- (10) Alexei Levenkov [Commented Oct 4, 2014 at 6:35]: Remove that line - you can always put it back if needed (also I don't think it should be in machine level config to start with). If not enough update your question/or ask new one with new error.
- (11) The Odd Developer [Commented Oct 4, 2014 at 6:37]: OK.Can you please tell me from which file i should remove this?I'm bit confused because i couldn't find this in web.config file.


---


# Accepted Answer

This nasty error occurs when you install MySQL .NET Connector 6.9.4 (probably other versions too) because if you do not uncheck "Web Providers" during the installation it writes in your machine.config which brings you to this error. Be sure to read the entire answer before applying any of these steps in order to start from where you have to start.

The real problem with other suggestions is that if you are not using MySQL in every project to just add a reference to MySQL dll to mitigate the problem in every project is not an option. Every project of yours that uses ASP.NET will require it because of the rows added in machine config by the installer!

To solve the problem properly :

1. Start the installer and click "Change"
2. then remove the "Web Providers" section entirely.
3. This will remove the declarations from your machine.config (which I find a horrible thing to do in installer but the installer creates them without any notification anyway).
4. After that it is a good idea to check you machine config which you can find [here](https://stackoverflow.com/a/2325492/1042934). And be sure that it did not spoil both [32 and 64 machine configs](https://stackoverflow.com/questions/6447936/updating-net-4-0-machine-config-seems-to-have-no-effect).
5. When your machine config is clear add the MySql.Web assembly to your project and add the MySQLMembershipProvider declaration in your project web.config - the standard procedure.
6. Enjoy the clean installation of MySQL connector.

But if you do it that way you may try to add Ado NET Entity Data model after, right? If that is the case it is most likely that you do not see the option for MySQL as an available data source in the wizard. This is because from version 6.7 when you install MySQL Connector .NET it will no longer [register as DDEX provider](http://msdn.microsoft.com/en-us/library/bb163935.aspx) automatically.

To correct this issue you have to download a separate installer provided especially for MySQL and .NET from [here](http://dev.mysql.com/tech-resources/articles/mysql-installer-for-windows.html) or the just Visual Studio integration plug-in directly from [here.](http://dev.mysql.com/downloads/windows/visualstudio/)

Be **sure** to check the *Visual Studio integration* and *connector* during the installation wizard on either of the above installers.