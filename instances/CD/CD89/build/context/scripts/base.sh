#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends default-jdk-headless liblog4j2-java
rm -rf /var/lib/apt/lists/*

mkdir -p /opt/cd89/classes /tmp/cd89-logs
cat > /opt/cd89/BarCodeOrderServlet.java <<'JAVA'
package com.jarmel.pharmacy.controls;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public final class BarCodeOrderServlet {
    private static final Logger LOGGER = LogManager.getLogger(BarCodeOrderServlet.class);

    private BarCodeOrderServlet() {
    }

    public static void main(String[] args) {
        LOGGER.trace("BARCODE_ORDER_EVENT");
        LogManager.shutdown();
    }
}
JAVA

javac -cp /usr/share/java/log4j-api.jar:/usr/share/java/log4j-core.jar \
  -d /opt/cd89/classes /opt/cd89/BarCodeOrderServlet.java
rm /opt/cd89/BarCodeOrderServlet.java
