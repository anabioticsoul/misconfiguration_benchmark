# How do I configure logback to gzip my logs automatically?

I am using Logback in my Java web application. My rolling file appender uses a monthly pattern (`last.%d{yyyy-MM}.gz`), but old logs are overwritten and no useful gzip history is retained. How should the configuration be changed so logs roll and compress reliably, including when a file grows large?
