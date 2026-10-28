# hadooop 3.3.6 resource manager not working

# Question

i'm using a ubuntu 22.04 pc with djk 17, java 11, hadoop 3.3.6

```
```bash
cd hadoop/hadoop-3.3.6/sbin 
./start-all.sh
```
```

output:

```
```plaintext
WARNING: Attempting to start all Apache Hadoop daemons as u22 in 10 seconds.
WARNING: This is not a recommended production deployment configuration.
WARNING: Use CTRL-C to abort.
Starting namenodes on [localhost]
Starting datanodes
Starting secondary namenodes [sdb5]
Starting resourcemanager
Starting nodemanagers
```
```

but the jps command shows RM not started.

```
```bash
jps
```
```

output:

```
```plaintext
28968 NameNode
29322 SecondaryNameNode
29101 DataNode
31038 Jps
```
```

`And the hadoop-u22-resourcemanager-sdb5.log is which contains many lines. so i used justpaste.it and the log is in this link [justpaste.it](https://jpst.it/3og2N)`


---


# Accepted Answer

Your error output is saying you're using Java 17, which Hadoop does not support.

Try again with JAVA\_HOME environment variable set to a Java 11 installation