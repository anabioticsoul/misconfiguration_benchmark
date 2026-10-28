# Unable to configure ORC properties in Spark

A Spark application writes ORC files, but setting `orc.compress`, `hive.exec.orc.default.compress`, and related Hive properties through `DataFrameWriter.options` does not change the output. The ORC file still uses the default compression. Determine why the requested compression is ignored and make the smallest configuration-only correction so the ORC writer uses SNAPPY compression.
