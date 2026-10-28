# Issues with Spark 3.1.2, Hadoop 3.2.1, and AWS Hadoop Dependencies [duplicate]

# Question

**This question already has answers here**:

[java.lang.NoClassDefFoundError: org/apache/hadoop/fs/StorageStatistics](/questions/44411493/java-lang-noclassdeffounderror-org-apache-hadoop-fs-storagestatistics)

(2 answers)

Closed 2 years ago.

I'm encountering compatibility issues with Spark, Hadoop, and AWS Hadoop dependencies in my Java Spark application.

The Spark version running on my local machine is 3.1.2.

Problem:
I'm working on a Spark application (version 3.1.2) that interacts with data stored in Amazon S3. The application uses Hadoop (version 3.2.1) and includes dependencies for AWS Hadoop.

pom.xml

```
    <project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
      <modelVersion>4.0.0</modelVersion>

      <groupId>org.poc</groupId>
      <artifactId>delta-lake</artifactId>
      <version>1.0-SNAPSHOT</version>
      <packaging>jar</packaging>

      <name>delta-lake</name>
      <url>http://maven.apache.org</url>

      <properties>
        <java.version>1.8</java.version>
        <scala.version>2.12</scala.version>
        <spark.version>3.1.2</spark.version>
        <delta.version>1.0.0</delta.version>
        <aws.sdk.version>1.12.604</aws.sdk.version> <!-- Use the latest version -->
      </properties>

      <dependencies>
        <!-- Spark dependencies -->
        <dependency>
          <groupId>org.apache.spark</groupId>
          <artifactId>spark-core_${scala.version}</artifactId>
          <version>${spark.version}</version>
        </dependency>
        <dependency>
          <groupId>org.apache.spark</groupId>
          <artifactId>spark-sql_${scala.version}</artifactId>
          <version>${spark.version}</version>
        </dependency>

        <!-- Delta Lake dependencies -->
        <dependency>
          <groupId>io.delta</groupId>
          <artifactId>delta-core_2.12</artifactId>
          <version>${delta.version}</version>
        </dependency>

        <!-- Hadoop AWS for S3 connectivity -->
        <dependency>
          <groupId>org.apache.hadoop</groupId>
          <artifactId>hadoop-aws</artifactId>
          <version>3.3.1</version>
        </dependency>

        <!-- Hadoop dependencies -->
        <dependency>
          <groupId>org.apache.hadoop</groupId>
          <artifactId>hadoop-common</artifactId>
          <version>3.2.1</version> <!-- Update to match your Spark version -->
        </dependency>
        <dependency>
          <groupId>org.apache.hadoop</groupId>
          <artifactId>hadoop-hdfs</artifactId>
          <version>3.2.1</version> <!-- Update to match your Spark version -->
        </dependency>

        <!-- AWS SDK for Java dependencies -->
        <!-- https://mvnrepository.com/artifact/com.amazonaws/aws-java-sdk-s3 -->
        <dependency>
          <groupId>com.amazonaws</groupId>
          <artifactId>aws-java-sdk-s3</artifactId>
          <version>1.12.604</version>
        </dependency>

        <!-- https://mvnrepository.com/artifact/com.amazonaws/aws-java-sdk-core -->
        <dependency>
          <groupId>com.amazonaws</groupId>
          <artifactId>aws-java-sdk-core</artifactId>
          <version>1.12.604</version>
        </dependency>

      </dependencies>

      <build>
        <plugins>
          <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>3.8.1</version>
            <configuration>
              <source>${java.version}</source>
              <target>${java.version}</target>
            </configuration>
          </plugin>
          <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-shade-plugin</artifactId>
            <version>3.2.4</version>
            <executions>
              <execution>
                <phase>package</phase>
                <goals>
                  <goal>shade</goal>
                </goals>
                <configuration>
                  <createDependencyReducedPom>false</createDependencyReducedPom>
                </configuration>
              </execution>
            </executions>
          </plugin>
        </plugins>
      </build>
    </project>
```

Issues :

When running the Spark application, I'm encountering the following runtime error related to IOStatisticsSource:

```
java.lang.NoClassDefFoundError: org/apache/hadoop/fs/statistics/IOStatisticsSource
```

Questions:

What versions of Hadoop and AWS Hadoop dependencies are compatible with Spark 3.1.2?
Is there a conflict between Hadoop versions in my dependencies?
Should I remove the hadoop-aws dependency if I'm not using S3?
I've tried updating dependencies, removing hadoop-aws, and configuring serialization, but the issue persists.

Any guidance on resolving this issue or insights into the compatibility of these dependencies would be greatly appreciated.


---


# Accepted Answer

If you look, then you can see that [Spark 3.1.2 was compiled](https://mvnrepository.com/artifact/org.apache.spark/spark-core_2.12/3.1.2) with Hadoop 3.2.0 as a dependency, so you need to use the same version of other components.