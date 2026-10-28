# intellij - spring is not being recognized (Unmapped Spring configuration)

## Question

I am using IntelliJ IDEA and all plugins for Spring are activated, but when I load my Maven project I have the following error:

> Spring Configuration Check  
> Unmapped Spring configuration files found.  
> Please configure/setup Spring facet for modules

Any ideas what prevented it from being configured automatically?

## Question Comments

- **Bhavesh Agarwal, Jan 23, 2015:** When this popup comes, IntelliJ is suspecting that some files in the module should be Spring beans. You can provide the Spring contexts and confirm that they are Spring beans so IntelliJ can provide Spring-specific suggestions and editing help. There is no harm in ignoring the popup, but using the IDE's support can be useful.

## Accepted Answer

1. Open the project structure dialog, either by clicking the warning or through File => Project Structure.
2. Select **Modules** in the left-hand list.
3. Right-click the modules with missing files and select **Add => Spring**.
4. In the new tab, click the **+** button.
5. Select the XML files from the list by checking their boxes.

This configures the module's Spring facet and maps the Spring context XML files.
