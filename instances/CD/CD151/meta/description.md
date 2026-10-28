# Spark: Self-suppression not permitted when writing big file to HDFS

# Question

I'm writing a large file to HDFS using spark. Basically what I was doing was to join 3 big files and then convert the result dataframe to json using toJSON() and then use saveAsTextFile to save it to HDFS. The final file to write is approximately 4TB. The application run pretty slow(as I should expected?) and after 6 hours it throwed an exception java.lang.IllegalArgumentException: Self-suppression not permitted. The detailed failure reason are copied from the monitoring page to below:

```
Job aborted due to stage failure: Task 37 in stage 6.0 failed 4 times, most recent failure: Lost task 37.3 in stage 6.0 (TID 361, 192.168.10.149): java.lang.IllegalArgumentException: Self-suppression not permitted
at java.lang.Throwable.addSuppressed(Throwable.java:1043)
at org.apache.spark.util.Utils$.tryWithSafeFinally(Utils.scala:1219)
at org.apache.spark.rdd.PairRDDFunctions$$anonfun$saveAsHadoopDataset$1$$anonfun$13.apply(PairRDDFunctions.scala:1116)
at org.apache.spark.rdd.PairRDDFunctions$$anonfun$saveAsHadoopDataset$1$$anonfun$13.apply(PairRDDFunctions.scala:1095)
at org.apache.spark.scheduler.ResultTask.runTask(ResultTask.scala:66)
at org.apache.spark.scheduler.Task.run(Task.scala:88)
at org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:214)
at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1142)
at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:617)
at java.lang.Thread.run(Thread.java:745)
Caused by: org.apache.hadoop.ipc.RemoteException(java.io.IOException): File /user/dawei/upid_json_all/_temporary/0/_temporary/attempt_201512210857_0006_m_000037_361/part-00037 could only be replicated to 0 nodes instead of minReplication (=1).  There are 5 datanode(s) running and no node(s) are excluded in this operation.
at org.apache.hadoop.hdfs.server.blockmanagement.BlockManager.chooseTarget4NewBlock(BlockManager.java:1562)
at org.apache.hadoop.hdfs.server.namenode.FSNamesystem.getAdditionalBlock(FSNamesystem.java:3245)
at org.apache.hadoop.hdfs.server.namenode.NameNodeRpcServer.addBlock(NameNodeRpcServer.java:663)
at org.apache.hadoop.hdfs.protocolPB.ClientNamenodeProtocolServerSideTranslatorPB.addBlock(ClientNamenodeProtocolServerSideTranslatorPB.java:482)
at org.apache.hadoop.hdfs.protocol.proto.ClientNamenodeProtocolProtos$ClientNamenodeProtocol$2.callBlockingMethod(ClientNamenodeProtocolProtos.java)
at org.apache.hadoop.ipc.ProtobufRpcEngine$Server$ProtoBufRpcInvoker.call(ProtobufRpcEngine.java:619)
at org.apache.hadoop.ipc.RPC$Server.call(RPC.java:962)
at org.apache.hadoop.ipc.Server$Handler$1.run(Server.java:2040)
at org.apache.hadoop.ipc.Server$Handler$1.run(Server.java:2036)
at java.security.AccessController.doPrivileged(Native Method)
at javax.security.auth.Subject.doAs(Subject.java:422)
at org.apache.hadoop.security.UserGroupInformation.doAs(UserGroupInformation.java:1656)
at org.apache.hadoop.ipc.Server$Handler.run(Server.java:2034)

at org.apache.hadoop.ipc.Client.call(Client.java:1468)
at org.apache.hadoop.ipc.Client.call(Client.java:1399)
at org.apache.hadoop.ipc.ProtobufRpcEngine$Invoker.invoke(ProtobufRpcEngine.java:232)
at com.sun.proxy.$Proxy14.addBlock(Unknown Source)
at org.apache.hadoop.hdfs.protocolPB.ClientNamenodeProtocolTranslatorPB.addBlock(ClientNamenodeProtocolTranslatorPB.java:399)
at sun.reflect.GeneratedMethodAccessor119.invoke(Unknown Source)
at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
at java.lang.reflect.Method.invoke(Method.java:497)
at org.apache.hadoop.io.retry.RetryInvocationHandler.invokeMethod(RetryInvocationHandler.java:187)
at org.apache.hadoop.io.retry.RetryInvocationHandler.invoke(RetryInvocationHandler.java:102)
at com.sun.proxy.$Proxy15.addBlock(Unknown Source)
at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.locateFollowingBlock(DFSOutputStream.java:1532)
at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.nextBlockOutputStream(DFSOutputStream.java:1349)
at org.apache.hadoop.hdfs.DFSOutputStream$DataStreamer.run(DFSOutputStream.java:588)

Driver stacktrace:
```

can anyone tell me what causes this problem and how could I solve it?



### Question Comments

=== COMMENTS ===
- (1) AkhlD [Commented Dec 21, 2015 at 7:37]: Looks like an issue with your HDFS:  Caused by: org.apache.hadoop.ipc.RemoteException(java.io.IOException): File /user/dawei/upid_json_all/_temporary/0/_temporary/attempt_201512210857_0006_m_000037_361/part-00037 could only be replicated to 0 nodes instead of minReplication (=1).  There are 5 datanode(s) running and no node(s) are excluded in this operation.  Check your ulimit and in the DFS logs to see whats going on.
- (2) unknown: 
- (3) Ravindra babu [Commented Dec 21, 2015 at 9:03]: Are you using eclipse?
- (4) TheStupidOne [Commented Dec 21, 2015 at 9:09]: Nah, python on pycharm. I figured maybe it was caused by insufficient disk space - only about 7TB left on my disks, not enough for 3 replications.
- (5) unknown: 


---


# Accepted Answer

From this error:

```
Caused by: org.apache.hadoop.ipc.RemoteException(java.io.IOException): File 
/user/dawei/upid_json_all/_temporary/0/_temporary/attempt_201512210857_0006_m_000037_361/
part-00037 could only be replicated to 0 nodes instead of minReplication (=1).
There are 5 datanode(s) running and no node(s) are excluded in this operation.
```

It seems that replication is not happening. If you fix this error, things may fall in right place.

It may be due to below issues:

1. *Inconsistency in your datanodes*: Restart your Hadoop cluster and see if this solves your problem
2. *Communication between datanodes and namenode*: *Network connectivity Issues* and permission/firewall access issues related to port accessibility.
3. *Disk space may be full on datanode*
4. *Datanode may be busy or unresponsive*
5. *Invalid configuration* like Negative block size configuration

Have a look at related SE questions too on this topic.

[HDFS error: could only be replicated to 0 nodes, instead of 1](https://stackoverflow.com/questions/5293446/hdfs-error-could-only-be-replicated-to-0-nodes-instead-of-1)