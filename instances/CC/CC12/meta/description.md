# Getting "project" nuget configuration is invalid error [duplicate]

# Question

**This question already has answers here**:

[Unable to Install Any Package in Visual Studio 2015](/questions/32344232/unable-to-install-any-package-in-visual-studio-2015)

(19 answers)

Closed 9 years ago.

I'm getting "[project] nuget configuration is invalid" error. I received an error like this before and used the 'Update Nuget package manager' solution mentioned here:

[Unable to Install Any Package in Visual Studio 2015](https://stackoverflow.com/questions/32344232/unable-to-install-any-package-in-visual-studio-2015)

I've also tried the other solutions mentioned in that link to no avail.

* **Restarting Visual Studio**
* **Deleting nuget.config**
* **Deleting packages.config**
* **Updating nuGet Package Manager.**

Also, I'm able to see the nuGet Packages at the solution level and other projects within this solution.

And, if I go to Package Manager Console (Tools -> NuGet Package Manager -> Package Manager Console), I can't see the projects having this issue in the project drop down, but I see the other projects in the solution.


---


# Accepted Answer

NOTE: This is mentioned in the question but **restarting Visual Studio** fixes the issue in most cases.

Updating Visual Studio to 'Update 2' got it working again.

`Tools -> Extensions and Updates ->Visual Studio Update 2`

As mentioned in the question and the link i posted therein, I'd already updated NuGet Package Manager to 3.4.4 prior to this and restarted to no avail, so I don't know if the combination of both these actions worked.