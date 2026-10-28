# Hadoop can‘t open node manager

# Question

my Hadoop version is 3.x
jps shows NameNode,SecondaryNameNode,ResourceManager but no NodeManager.
log shows like

**ERROR org.apache.hadoop.yarn.server.nodemanager.NodeManager: Error starting NodeManagerjava.lang.ExceptionInInitializerErrorat com.google.inject.internal.cglib.reflect.$FastClassEmitter.(FastClassEmitter.java:67)at com.google.inject.internal.cglib.reflect.$FastClass$Generator.generateClass(FastClass.java:72)at com.google.inject.internal.cglib.core.$DefaultGeneratorStrategy.generate(DefaultGeneratorStrategy.java:25)at com.google.inject.internal.cglib.core.$AbstractClassGenerator.create(AbstractClassGenerator.java:216)at com.google.inject.internal.cglib.reflect.$FastClass$Generator.create(FastClass.java:64)at com.google.inject.internal.BytecodeGen.newFastClass(BytecodeGen.java:204)at com.google.inject.internal.ProviderMethod$FastClassProviderMethod.(ProviderMethod.java:256)at com.google.inject.internal.ProviderMethod.create(ProviderMethod.java:71)at com.google.inject.internal.ProviderMethodsModule.createProviderMethod(ProviderMethodsModule.java:275)at com.google.inject.internal.ProviderMethodsModule.getProviderMethods(ProviderMethodsModule.java:144)at com.google.inject.internal.ProviderMethodsModule.configure(ProviderMethodsModule.java:123)at com.google.inject.spi.Elements$RecordingBinder.install(Elements.java:340)at com.google.inject.spi.Elements$RecordingBinder.install(Elements.java:349)at com.google.inject.AbstractModule.install(AbstractModule.java:122)at com.google.inject.servlet.ServletModule.configure(ServletModule.java:52)at com.google.inject.AbstractModule.configure(AbstractModule.java:62)at com.google.inject.spi.Elements$RecordingBinder.install(Elements.java:340)at com.google.inject.spi.Elements.getElements(Elements.java:110)at com.google.inject.internal.InjectorShell$Builder.build(InjectorShell.java:138)at com.google.inject.internal.InternalInjectorCreator.build(InternalInjectorCreator.java:104)at com.google.inject.Guice.createInjector(Guice.java:96)at com.google.inject.Guice.createInjector(Guice.java:73)at com.google.inject.Guice.createInjector(Guice.java:62)at org.apache.hadoop.yarn.webapp.WebApps$Builder.build(WebApps.java:417)at org.apache.hadoop.yarn.webapp.WebApps$Builder.start(WebApps.java:465)at org.apache.hadoop.yarn.webapp.WebApps$Builder.start(WebApps.java:461)at org.apache.hadoop.yarn.server.nodemanager.webapp.WebServer.serviceStart(WebServer.java:125)at org.apache.hadoop.service.AbstractService.start(AbstractService.java:194)at org.apache.hadoop.service.CompositeService.serviceStart(CompositeService.java:122)at org.apache.hadoop.service.AbstractService.start(AbstractService.java:194)at org.apache.hadoop.yarn.server.nodemanager.NodeManager.initAndStartNodeManager(NodeManager.java:963)at org.apache.hadoop.yarn.server.nodemanager.NodeManager.main(NodeManager.java:1042)Caused by: java.lang.reflect.InaccessibleObjectException: Unable to make protected final java.lang.Class java.lang.ClassLoader.defineClass(java.lang.String,byte[],int,int,java.security.ProtectionDomain) throws java.lang.ClassFormatError accessible: module java.base does not "opens java.lang" to unnamed module @58ecb515at java.base/java.lang.reflect.AccessibleObject.checkCanSetAccessible(AccessibleObject.java:354)at java.base/java.lang.reflect.AccessibleObject.checkCanSetAccessible(AccessibleObject.java:297)at java.base/java.lang.reflect.Method.checkCanSetAccessible(Method.java:199)at java.base/java.lang.reflect.Method.setAccessible(Method.java:193)at com.google.inject.internal.cglib.core.$ReflectUtils$2.run(ReflectUtils.java:56)at java.base/java.security.AccessController.doPrivileged(AccessController.java:318)at com.google.inject.internal.cglib.core.$ReflectUtils.(ReflectUtils.java:46)... 32 more**

its my yarn-site.xml

```
<configuration>
    <property>
        <name>yarn.resourcemanager.hostsname</name>
        <value>127.0.0.1</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>8</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>8192</value>
    </property>
        <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>
```

my core-site.xml

```
< configuration>
<property>
    <name>fs.default.name</name>
    <value>hdfs://localhost:9000</value>
</property>
</configuration>
```

my mapped-site.xml

```
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
```

my Hdfs-site.xml

```
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
```

I tried to change the configuration of these four files a lot, but none of them worked. My log file shows that the error is the above. I have encountered this problem. It seems to be a jdk version problem. I have jdk8 and jdk11 on my computer. jdk17 but my javahome setting is jdk8, I installed it through brew and did not configure the environment.


---


# Accepted Answer

1. look at JAVA\_HOME environment variable is set to the appropriate JDK version (JDK 8) that is compatible with Hadoop 3.x.
2. Remove other JDK installations: To avoid any conflicts, consider uninstalling JDK 11 and JDK 17.
3. Look at Hadoop configuration files to ensure that they are using the correct JAVA\_HOME variable.
4. Restart Hadoop