# Hadoop daemons are not running

I followed [this guide](http://thepowerofdata.io/setting-up-a-apache-hadoop-2-7-single-node-on-ubuntu-14-04/) to install Hadoop. At the end, when I run `jps`, I only get `12815 JPS` instead of the Hadoop daemons.

I also tried starting the daemons manually:

```text
hadoop-daemon.sh start namenode
hadoop-daemon.sh start datanode
yarn-daemon.sh start resourcemanager
yarn-daemon.sh start nodemanager
mr-jobhistory-daemon.sh start historyserver
```

Starting the NameNode reports:

```text
[Fatal Error] core-site.xml:21:2: The markup in the document following the root element must be well-formed.
```

How can I fix this?

A useful diagnostic comment says to check whether `core-site.xml` is well-formed XML, especially line 21. The accepted resolution was to remove the duplicated `<configuration>...</configuration>` wrapper that had been pasted into the Hadoop XML configuration files, then format the NameNode and start HDFS and YARN again.
