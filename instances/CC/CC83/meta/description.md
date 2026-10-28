# Spark Write to S3 with S3A Committers fails on space character of partition column value

# Question

When trying to have spark (3.1.1) write to S3 bucket partitioned data using the S3A committers I am getting an error:

```
Caused by: java.lang.IllegalStateException: Cannot parse URI s3a://partition-spaces-test-bucket/test_spark_partitioning_s3a_committers/City=New York/part-00000-7d95735c-ecc4-4263-86fe-51263b45bbf2-73dcb7a0-7da5-4f45-a12f-e57face31212.c000.snappy.parquet
    at org.apache.hadoop.fs.s3a.commit.files.SinglePendingCommit.destinationPath(SinglePendingCommit.java:255)
    at org.apache.hadoop.fs.s3a.commit.files.SinglePendingCommit.validate(SinglePendingCommit.java:195)
    at org.apache.hadoop.fs.s3a.commit.files.PendingSet.validate(PendingSet.java:146)
    at org.apache.hadoop.fs.s3a.commit.files.PendingSet.load(PendingSet.java:109)
    at org.apache.hadoop.fs.s3a.commit.AbstractS3ACommitter.lambda$loadPendingsetFiles$4(AbstractS3ACommitter.java:478)
    at org.apache.hadoop.fs.s3a.commit.Tasks$Builder$1.run(Tasks.java:254)
    at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:515)
    at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
    at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128)
    at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628)
    at java.base/java.lang.Thread.run(Thread.java:829)
```

This is caused because of the space in the partition column value I am using.
When using the default spark FileOutputCommitter this is working and spark creates the directory with space in the name.

The S3A committer used the java.net.URI object to create the org.apache.hadoop.fs.Path object and the URI is the one throwing URISyntaxException because of this space.

My question is why did the S3A committer developers choose to use URI for the path and not create the Path directly from the string like done in the FileOutputCommitter, is there a good reason to do so?

And how can I overcome this assuming I don't want to change the values of this column by replacing space with another char such as underscore?


---


# Accepted Answer

> My question is why did the S3A committer developers choose to use URI for the path and not create the Path directly from the string like done in the FileOutputCommitter, is there a good reason to do so?

That is a good question. We do it that way because we have to marshall the list of paths from the workers to the job committer, which we do in JSON files. And that marshalling didn't round-trip properly with spaces. This has been found and fixed in [HADOOP-17112](https://issues.apache.org/jira/browse/HADOOP-17112) *whitespace not allowed in paths when saving files to s3a via committers*

One interesting question is: why didn't anybody notice? And that is because nobody else uses space in the partitioning. Not in any of the tests, TCP-DS benchmarks etc. One of those little assumptions which we developers had that turns out to not always hold. As well as fixing the issue we now make sure our tests do have parts with spaces in them to stop it ever coming back.

> And how can I overcome this assuming I don't want to change the values of this column by replacing space with another char such as underscore?

upgrade to hadoop-3.3.1 binaries

Note that all this code is open source, the fix for the bug was actually provided by the same person who identified the problem. While you are free to criticize the authors of the feature, we depend on reviews and testing from others. If we don't get that we can't guarantee our code meets the more obscure needs of some people. In particular, for the object stores, and the configurations space off all the S3 Store options (region, replication, IAM restrictions, encryption) and client connectivity options (proxy, AWS access point, ...) mean that it is really hard to get full coverage of the possible configurations. Anything you can do to help qualifying releases -or even better, check out build and test the modules before we entered the release phase, is always appreciated. It's the only way you can be confident that things are going to work in your world.



### Answer Comments

=== COMMENTS ===
- (1) Or Bar Yaacov [2022-01-19T06:37:00+00:00]: thank you for the detailed explanation, now I know that when I upgrade to spark 3.2.0 the problem will be resolved. So it just a matter of waiting for the Spark operator to support spark 3.2.0. For now I have modified the values to not contain spaces.