# Getting Async Task Checkpoint failed error with Flink Presto 1.14.0 library

I am trying to use Flink S3 checkpointing with the Flink S3 Presto library. My S3-related Flink configuration is:

```yaml
fs.allowed-fallback-filesystems: s3p
state.backend: filesystem
state.checkpoints.dir: s3p://gamma-flink-test-checkpoint/checkpoints/
state.backend.fs.checkpointdir: s3p://gamma-flink-test-checkpoint/checkpoints/
state.savepoints.dir: s3p://gamma-flink-test-checkpoint/savepoints/
state.backend.fs.savepointdir: s3p://gamma-flink-test-checkpoint/savepoints/
s3.connection.timeout: 600000
s3.socket.timeout: 600000
s3.connection.establish.timeout: 600000
```

About 40% of checkpoints fail without a visible Flink dashboard exception. Job manager logs show an AWS SDK `SdkClientException` caused by `Unable to execute HTTP request: Read timed out` while `PrestoS3FileSystem$PrestoS3OutputStream.uploadObject` closes a checkpoint stream. Task manager logs also show cleanup interrupted while the Presto S3 filesystem retries metadata and delete operations. The issue occurs with the Presto library, while the Hadoop S3 library works, and lowering job traffic reduces the failure percentage.

## Accepted answer

The Flink Presto implementation uses the same configuration keys as the Presto file system. The configuration keys differ between Presto and Hadoop. In Hadoop, there is no `s3.connection.timeout`; the corresponding key is `s3.connect-timeout`. Likewise, there is no `s3.socket.timeout`; the corresponding key is `s3.socket-timeout`.
