#!/usr/bin/env bash
set -euo pipefail
export SPARK_LOCAL_IP=127.0.0.1
export SPARK_HOME=/opt/spark
export PYTHONPATH="$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip${PYTHONPATH:+:$PYTHONPATH}"
python3 -c 'import pyspark; assert pyspark.__version__ == "3.5.1"'
mkdir -p /opt/ca163
cat > /opt/ca163/socket_checkpoint.py <<'PY'
import argparse
import configparser
import socket
import sys
import threading
import time

from pyspark.sql import SparkSession


def socket_server(port, stop):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", port))
    server.listen(1)
    server.settimeout(0.5)
    try:
        while not stop.is_set():
            try:
                client, _ = server.accept()
            except socket.timeout:
                continue
            with client:
                client.sendall(b"alpha\nbeta\n")
    finally:
        server.close()


def checkpoint_from_config(path):
    parser = configparser.ConfigParser()
    parser.read(path)
    return parser.get("streaming", "checkpointLocation", fallback="")


def run_query(spark, checkpoint, port):
    reader = (spark.readStream.format("socket")
              .option("host", "127.0.0.1").option("port", str(port)))
    stream = reader.load()
    writer = (stream.writeStream.format("memory").queryName("ca163_socket_probe")
              .trigger(once=True))
    if checkpoint:
        writer = writer.option("checkpointLocation", checkpoint)
    query = writer.start()
    if not query.awaitTermination(15000):
        query.stop()
        raise RuntimeError("Socket stream did not complete its single trigger")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="/opt/ca163/query.conf")
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args()
    port = 17635
    stop = threading.Event()
    server_thread = threading.Thread(target=socket_server, args=(port, stop), daemon=True)
    server_thread.start()
    spark = (SparkSession.builder.master("local[2]").appName("CA163")
             .config("spark.ui.enabled", "false").config("spark.sql.shuffle.partitions", "1")
             .config("spark.sql.streaming.stopTimeout", "5000")
             .getOrCreate())
    spark.sparkContext.setLogLevel("ERROR")
    try:
        checkpoint = "" if args.smoke else checkpoint_from_config(args.config)
        run_query(spark, checkpoint, port)
        if not args.smoke:
            run_query(spark, checkpoint, port)
    finally:
        spark.stop()
        stop.set()
        server_thread.join(timeout=2)


if __name__ == "__main__":
    main()
PY
cat > /opt/ca163/READY <<'EOF'
ready
EOF
chmod 755 /opt/ca163/socket_checkpoint.py
chown -R spark:spark /opt/ca163
