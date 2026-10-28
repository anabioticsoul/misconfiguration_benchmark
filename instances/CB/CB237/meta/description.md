# connect to postgres contsainer from another container

## Question

i tried to connect to an existing postgres sql from another docker container within same instanz but i cant get it working. Any ideas? I already searched the internet but nothing is workin. I think its an obvious mistake but i dont see it ...

yaml:

```yaml
version: '3'

services:

  raw_data_db:
    image: postgres:latest
    container_name: raw_data_db
    environment:
      POSTGRES_DB: raw_data
      POSTGRES_USER: my_username
      POSTGRES_PASSWORD: my_password
    ports:
      - "5434:5434"
    volumes:
      - /path/to/store/data:/var/lib/postgresql/data

  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  broker:
    image: confluentinc/cp-enterprise-kafka:latest
    container_name: broker
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://broker:9092
    depends_on:
      - zookeeper


  producer:
    build:
      context: .
      dockerfile: ./DockerfileProducer
    volumes:
      - ./producer.py:/app/producer.py
      - ./data_cleaned_1000.csv:/app/data_cleaned_1000.csv
    command: sh -c "sleep 10 && python /app/producer.py"

  consumer:
    build:
      context: .
      dockerfile: ./DockerfileConsumer
    volumes:
      - ./consumer.py:/app/consumer.py
    command: sh -c "sleep 30 && python /app/consumer.py"
```

For the host i tried everything. Localhost, ...

```python
conn = psycopg2.connect(
    database="raw_data",
    user="my_username",
    password="my_password",
    host="raw_data_db",
    port="5434"
)
```

This is the error i receive. When i connect to the postgres container from outside the docker instance, it works.

> psycopg2.OperationalError: connection to server at "localhost" (127.0.0.1), port 5434 failed: Connection refused

## Question Comments

- ElmoVanKielmo: Just use name of the service - raw_data_db in your case as the hostname.
- ElmoVanKielmo: Plus normally postgres listens on 5432 and not 5434
- Kinggpuu: You are my hero! Now its working. Thank you so much!!

## Accepted Answer

Unless you do an edit of port in your configuration file, Postgresql port defaults to 5432.
