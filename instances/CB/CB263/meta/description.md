# HDFS cannot replicate a block to any DataNode

A Hadoop MapReduce job fails while writing an intermediate file:

```text
Vertex failed, vertexName=initialmap, vertexId=vertex_1449805139484_0001_1_00, diagnostics=[Task failed, taskId=task_1449805139484_0001_1_00_000003, diagnostics=[AttemptID:attempt_1449805139484_0001_1_00_000003_0 Info:Error: org.apache.hadoop.ipc.RemoteException(java.io.IOException): File /user/hadoop/gridmix-kon/input/_temporary/1/_temporary/attempt-.../part-m-00003/segment-121 could only be replicated to 0 nodes instead of minReplication (=1). There are 4 datanode(s) running and no node(s) are excluded in this operation.
```

The failure comes from HDFS block placement. Although four DataNodes are running and none are excluded, no DataNode can accept the new block. A common cause is that the DataNodes have no usable disk space. Check the live DataNode report with:

```text
hdfs dfsadmin -report
```

In particular, inspect `DFS Remaining` and `DFS Remaining%` for each DataNode. Other general causes include stopped DataNodes or DataNodes unable to contact the NameNode, but the stated four live, non-excluded DataNodes make unavailable writable disk space the relevant diagnosis here.

The relevant Hadoop block-manager logic reports this when it cannot select even one target while `minReplication` is 1. The configuration involved is in `hdfs-site.xml`; restoring usable DataNode capacity should allow the write to complete.
