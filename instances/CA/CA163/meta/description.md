# Spark Structured Streaming checkpoint recovery

A local Structured Streaming experiment reads text from a socket and performs stateful processing. The query fails on a subsequent start with:

```
This query does not support recovering from checkpoint location
```

The application should continue using the socket source, but must be configurable so that this non-replayable source does not attempt checkpoint recovery. How should the streaming configuration be changed?
