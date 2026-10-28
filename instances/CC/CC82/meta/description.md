# java.lang.NoClassDefFoundError: org/apache/kafka/common/serialization/ByteArraySerializer for spark streaming

# Question

I am trying to run a spark streaming application on Ubuntu, but I get some errors. For some reason Ubuntu 22.04 does not locate the jar files despite the fact the same configuration works on Windows.

I run the following configuration in a script

```
    spark = SparkSession \
        .builder \
        .appName("File Streaming PostgreSQL") \
        .master("local[3]") \
        .config("spark.streaming.stopGracefullyOnShutdown", "true") \
        .config("spark.jars.packages", "org.apache.spark:spark-avro_2.12:3.3.0,org.apache.spark:spark-sql-kafka-0-10_2.12:3.3.0") \
        .config("spark.sql.shuffle.partitions", 2) \
        .getOrCreate()
```

in addition to that, I download and locate **all** the jar files for avro and sql in `/usr/local/spark/jars`

* spark-sql-kafka-0-10\_2.12-3.3.0.jar
* spark-sql-kafka-0-10\_2.12-3.3.0-tests.jar
* spark-sql-kafka-0-10\_2.12-3.3.0-javadoc.jar
* spark-sql-kafka-0-10\_2.12-3.3.0-sources.jar
* spark-sql-kafka-0-10\_2.12-3.3.0-test-sources.jar
* spark-avro\_2.12-3.3.0.jar
* spark-avro\_2.12-3.3.0-tests.jar
* spark-avro\_2.12-3.3.0-javadoc.jar
* spark-avro\_2.12-3.3.0-sources.jar
* spark-avro\_2.12-3.3.0-test-sources.jar

my spark version is 3.3.0 and scala version is 2.12.14 and OpenJDK 64-Bit Server VM, Java 11.0.16, but I get the following error

```
ile "/usr/local/spark/python/lib/py4j-0.10.9.5-src.zip/py4j/protocol.py", line 326, in get_return_value
py4j.protocol.Py4JJavaError: An error occurred while calling o39.load.
: java.lang.NoClassDefFoundError: org/apache/kafka/common/serialization/ByteArraySerializer
        at org.apache.spark.sql.kafka010.KafkaSourceProvider$.<init>(KafkaSourceProvider.scala:601)
        at org.apache.spark.sql.kafka010.KafkaSourceProvider$.<clinit>(KafkaSourceProvider.scala)
        at org.apache.spark.sql.kafka010.KafkaSourceProvider.org$apache$spark$sql$kafka010$KafkaSourceProvider$$validateStreamOptions(KafkaSourceProvider.scala:338)
        at org.apache.spark.sql.kafka010.KafkaSourceProvider.sourceSchema(KafkaSourceProvider.scala:71)
        at org.apache.spark.sql.execution.datasources.DataSource.sourceSchema(DataSource.scala:236)
        at org.apache.spark.sql.execution.datasources.DataSource.sourceInfo$lzycompute(DataSource.scala:118)
        at org.apache.spark.sql.execution.datasources.DataSource.sourceInfo(DataSource.scala:118)
        at org.apache.spark.sql.execution.streaming.StreamingRelation$.apply(StreamingRelation.scala:34)
        at org.apache.spark.sql.streaming.DataStreamReader.loadInternal(DataStreamReader.scala:168)
        at org.apache.spark.sql.streaming.DataStreamReader.load(DataStreamReader.scala:144)
        at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
        at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
        at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
        at java.base/java.lang.reflect.Method.invoke(Method.java:566)
        at py4j.reflection.MethodInvoker.invoke(MethodInvoker.java:244)
        at py4j.reflection.ReflectionEngine.invoke(ReflectionEngine.java:357)
        at py4j.Gateway.invoke(Gateway.java:282)
        at py4j.commands.AbstractCommand.invokeMethod(AbstractCommand.java:132)
        at py4j.commands.CallCommand.execute(CallCommand.java:79)
        at py4j.ClientServerConnection.waitForCommands(ClientServerConnection.java:182)
        at py4j.ClientServerConnection.run(ClientServerConnection.java:106)
        at java.base/java.lang.Thread.run(Thread.java:829)
Caused by: java.lang.ClassNotFoundException: org.apache.kafka.common.serialization.ByteArraySerializer
        at java.base/jdk.internal.loader.BuiltinClassLoader.loadClass(BuiltinClassLoader.java:581)
        at java.base/jdk.internal.loader.ClassLoaders$AppClassLoader.loadClass(ClassLoaders.java:178)
        at java.base/java.lang.ClassLoader.loadClass(ClassLoader.java:522)
        ... 22 more
```

This problem persists despite that I have the following configuration on `.bashrc`

```
#configuration for local Spark and Hadoop
SPARK_HOME=/usr/local/spark-3.3.0-bin-hadoop3
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
export PYSPARK_PYTHON=/usr/bin/python3
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin
```

It is important to notice that everything works fine on Windows, and other applications that do not make use of SQL injection and avro serialization work just fine on Ubuntu 22.04 as well.


---


# Accepted Answer

You need `kafka-clients.jar` for the mentioned class.

You don't need Spark tests, sources or Javadoc in your Spark runtime.

Also, if you're trying to use Avro with a Schema Registry, then spark-avro isn't what you want.



### Answer Comments

=== COMMENTS ===
- (1) Ivan [2022-08-15T16:18:52+00:00]: My spark version is 3.3.0, but when I look for kafka-clients.jar the most current version is 3.2.x. In this case, would not be a problem of incompatibility?
- (2) Ivan [2022-08-15T21:31:20+00:00]: As I expected, your approach does not work. At least in this case.
- (3) OneCricketeer [2022-08-16T13:51:33+00:00]: Version doesn't really matter. Kafka doesn't depend on Spark. Any version above Kafka 2.1.0 should work. Unclear what you tried, but you need to add it into spark.jars.packages line. It works fine github.com/OneCricketeer/docker-stacks/blob/master/hadoop-sp‌​ark/…