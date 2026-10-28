# Configuration on demand is not supported by the current version of the Android Gradle plugin

# Question

After upgrading to Android Studio 3.1.2 I am getting the following error:

> Configuration on demand is not supported by the current version of the Android Gradle plugin since you are using Gradle version 4.6 or above. Suggestion: disable configuration on demand by setting org.gradle.configureondemand=false in your gradle.properties file or use a Gradle version less than 4.6.

I attempted following the suggestion but this did not fix the issue. Any ideas? All help is greatly appreciated, thank you.


---


# Accepted Answer

# No need to downgrade!

## Disabling configure on demand requires two steps:

1. Remove `org.gradle.configureondemand` from gradle.properties.
2. In Android Studio,  
   **For Mac** go to the `Preferences` > `Build, Execution, Deployment` > `Compiler` and uncheck the configure on demand.  
   **For Linux/Windows** go to the `File` > `Settings` > `Build, Execution, Deployment` > `Compiler` and uncheck the configure on demand.

Note, there are 2 `gradle.properties` files

1. In your project `gradle.properties`
2. `${HOME}/.gradle/gradle.properties`