#!/usr/bin/env python3
import configparser
import os
import shutil
import sys
import tempfile

from pyspark.sql import SparkSession

CONFIG = "/opt/misconfigbench/orc_config.conf"

def main():
    parser = configparser.ConfigParser()
    parser.read(CONFIG)
    requested = parser.get("orc", "compression", fallback="zlib").lower()
    if requested not in {"none", "snappy", "zlib", "lz4", "zstd"}:
        raise RuntimeError("Unsupported configured compression: " + requested)

    output = tempfile.mkdtemp(prefix="ca162-orc-")
    spark = (SparkSession.builder.master("local[2]")
             .appName("CA162-ORC-check")
             .config("spark.ui.enabled", "false")
             .getOrCreate())
    try:
        spark.range(0, 32).write.mode("overwrite").format("orc").option("compression", requested).save(output)
        rows = spark.read.orc(output).count()
        if rows != 32:
            raise RuntimeError("ORC read-back returned " + str(rows) + " rows")
        jvm = spark.sparkContext._jvm
        hadoop_conf = spark.sparkContext._jsc.hadoopConfiguration()
        path = jvm.org.apache.hadoop.fs.Path(output)
        files = path.getFileSystem(hadoop_conf).listStatus(path)
        data_file = None
        for status in files:
            name = status.getPath().getName()
            if name.endswith(".orc"):
                data_file = status.getPath()
                break
        if data_file is None:
            raise RuntimeError("No ORC data file produced")
        reader_options = jvm.org.apache.orc.OrcFile.readerOptions(hadoop_conf)
        reader = jvm.org.apache.orc.OrcFile.createReader(data_file, reader_options)
        codec = reader.getCompressionKind().toString().lower()
        if codec != "snappy":
            raise RuntimeError("Expected SNAPPY compression but found " + codec.upper())
        print("ORC compression: " + codec.upper())
        print("ORC rows: " + str(rows))
    finally:
        spark.stop()
        shutil.rmtree(output, ignore_errors=True)

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
