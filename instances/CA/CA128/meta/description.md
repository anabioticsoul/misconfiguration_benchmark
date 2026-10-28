# Error: Configuration with name 'default' not found in Android Studio

# Question

I am using the volley library to perform network operation in android. So I am trying to add this library in my project which is created in Android Studio and gradle system.

I added the volley library in my project but when I sync with gradle then I am getting error message. I tried all the answers which I see here but nothing worked for me.

**Error message** : Configuration with name 'default' not found in Android Studio

Volley/build.gradle

```
apply plugin: 'android-library'

android {

    compileSdkVersion 19
    buildToolsVersion '19.0.1'

    sourceSets {
        defaultConfig {
            minSdkVersion 8
            targetSdkVersion 19
        }

        main {
            assets.srcDirs       = ['assets']
            res.srcDirs          = ['res']
            aidl.srcDirs         = ['src']
            resources.srcDirs    = ['src']
            renderscript.srcDirs = ['src']
            java.srcDirs         = ['src']
            manifest.srcFile 'AndroidManifest.xml'

        }
    }
}
```

app/build.gradle

```
apply plugin: 'android'

android {
    compileSdkVersion 19
    buildToolsVersion '19.0.1'

    defaultConfig {
        minSdkVersion 8
        targetSdkVersion 19
        versionCode 1
        versionName "1.0"
    }
    buildTypes {
        release {
            runProguard false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.txt'
        }
    }
}

dependencies {
    compile 'com.android.support:appcompat-v7:19.+'
    compile project(':library:volley')
}
```

root/build.gradle

```
// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:0.9.1'
    }
}

allprojects {
    repositories {
        mavenCentral()
    }
}
```

settings.gradle

```
include ':app'
include ':library:volley'
```



### Question Comments

=== COMMENTS ===
- (1) Ajay S [Commented Mar 30, 2014 at 12:00]: Have you added library folder at correct location like projectname/library??
- (2) Bot [Commented Mar 30, 2014 at 12:03]: I added library directory in the app directory
- (3) k3b [Commented Sep 13, 2015 at 5:53]: stackoverflow.com/questions/22547364/…
- (4) tir38 [Commented Jun 2, 2016 at 19:23]: Possible duplicate of Android Studio Gradle Configuration with name 'default' not found
- (5) Zar E Ahmer [Commented May 17, 2017 at 5:45]: In my case one of my gradle configuration file is missing.It is not properly push.


---


# Accepted Answer

Add your library folder in your root location of your project and copy all the library files there. For ex YourProject/library then sync it and rest things seems OK to me.