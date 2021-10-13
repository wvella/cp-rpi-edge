
# 🎓️ How to extend

Before learning how to create your own examples/reproduction models, here are some explanations on how the playground works internally:

## 🏫 How it works

### 📁 Folder structure

The main categories like `ccloud`, `connect`, `environment` are in root folder:

![folder_structure](./images/folder_structure.jpg)

All the tests are and **must** be at second level:

![folder_structure](./images/folder_structure2.jpg)

This is important because each test is sourcing [`scripts/utils.sh`](https://github.com/vdesabou/kafka-docker-playground/blob/master/scripts/utils.sh) like this:

```bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh
```

### 🐳 Docker override

The playground makes extensive use of docker-compose [override](https://docs.docker.com/compose/extends/).

Each test is built based on an [environment](#/content?id=%F0%9F%94%90-environments), [PLAINTEXT](https://github.com/vdesabou/kafka-docker-playground/tree/master/environment/plaintext) being the most common one.

Let's have a look at some examples to understand how it works:

#### Connector using PLAINTEXT

Example with ([active-mq-sink.sh](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-active-mq-sink/active-mq-sink.sh)):

```shell
${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"
```

The *local* [`${PWD}/docker-compose.plaintext.yml`](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-active-mq-sink/docker-compose.plaintext.yml) is only composed of:

```yml
---
version: '3.5'
services:
  activemq:
    image: rmohr/activemq:5.15.9
    hostname: activemq
    container_name: activemq
    ports:
      - '61616:61616'
      - '8161:8161'

  connect:
    environment:
      CONNECT_PLUGIN_PATH: /usr/share/confluent-hub-components/confluentinc-kafka-connect-activemq-sink
```

It contains:

* `activemq` container required for the test 
* For `connect` container, it will override value `CONNECT_PLUGIN_PATH` from [`environment/plaintext/docker-compose.yml`](https://github.com/vdesabou/kafka-docker-playground/blob/master/environment/plaintext/docker-compose.yml)

PLAINTEXT is used thanks to the call to `${DIR}/../../environment/plaintext/start.sh`

> [!INFO]
> The *local* docker-compose file should be named docker-compose.%environment%[.%optional'%].yml 
> 
> Example: 
> 
> `docker-compose.plaintext.yml` or `docker-compose.plaintext.mtls.yml`
> 
> This is required for [stop.sh](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-active-mq-sink/stop.sh) script to work properly.


#### Environment SASL/SSL 

Environments are also overriding [PLAINTEXT](https://github.com/vdesabou/kafka-docker-playground/tree/master/environment/plaintext), so for example [SASL/SSL](https://github.com/vdesabou/kafka-docker-playground/tree/master/environment/sasl-ssl) has a [docker-compose.yml](https://github.com/vdesabou/kafka-docker-playground/blob/master/environment/sasl-ssl/docker-compose.yml) file like this:

```yml
    ####
    #
    # This file overrides values from environment/plaintext/docker-compose.yml
    #
    ####

  zookeeper:
    environment:
      KAFKA_OPTS: -Djava.security.auth.login.config=/etc/kafka/secrets/zookeeper_jaas.conf
                  -Dzookeeper.authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
                  -DrequireClientAuthScheme=sasl
                  -Dzookeeper.allowSaslFailedClients=false
    volumes:
      - ../../environment/sasl-ssl/security:/etc/kafka/secrets

  broker:
    volumes:
      - ../../environment/sasl-ssl/security:/etc/kafka/secrets
    environment:
      KAFKA_INTER_BROKER_LISTENER_NAME: SASL_SSL
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: SASL_SSL:SASL_SSL
      KAFKA_ADVERTISED_LISTENERS: SASL_SSL://broker:9092
      KAFKA_LISTENERS: SASL_SSL://:9092
      CONFLUENT_METRICS_REPORTER_SECURITY_PROTOCOL: SASL_SSL
      CONFLUENT_METRICS_REPORTER_SASL_JAAS_CONFIG: "org.apache.kafka.common.security.plain.PlainLoginModule required \
        username=\"client\" \
        password=\"client-secret\";"
      CONFLUENT_METRICS_REPORTER_SASL_MECHANISM: PLAIN
      CONFLUENT_METRICS_REPORTER_SSL_TRUSTSTORE_LOCATION: /etc/kafka/secrets/kafka.client.truststore.jks
      CONFLUENT_METRICS_REPORTER_SSL_TRUSTSTORE_PASSWORD: confluent
      CONFLUENT_METRICS_REPORTER_SSL_KEYSTORE_LOCATION: /etc/kafka/secrets/kafka.client.keystore.jks
      CONFLUENT_METRICS_REPORTER_SSL_KEYSTORE_PASSWORD: confluent
      CONFLUENT_METRICS_REPORTER_SSL_KEY_PASSWORD: confluent
      KAFKA_SASL_ENABLED_MECHANISMS: PLAIN
      KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL: PLAIN
      KAFKA_SSL_KEYSTORE_FILENAME: kafka.broker.keystore.jks
      KAFKA_SSL_KEYSTORE_CREDENTIALS: broker_keystore_creds
      KAFKA_SSL_KEY_CREDENTIALS: broker_sslkey_creds
      KAFKA_SSL_TRUSTSTORE_FILENAME: kafka.broker.truststore.jks
      KAFKA_SSL_TRUSTSTORE_CREDENTIALS: broker_truststore_creds
      # enables 2-way authentication
      KAFKA_SSL_CLIENT_AUTH: "required"
      KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM: "HTTPS"
      KAFKA_OPTS: -Djava.security.auth.login.config=/etc/kafka/secrets/broker_jaas.conf
      KAFKA_SSL_PRINCIPAL_MAPPING_RULES: RULE:^CN=(.*?),OU=TEST.*$$/$$1/,DEFAULT

            <snip>
```

It only contains what is required to add SASL/SSL to a PLAINTEXT environment 💫 !

#### Connector using SASL/SSL

Example with ([gcs-sink-sasl-ssl.sh](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-gcp-gcs-sink/gcs-sink-sasl-ssl.sh)):

```shell
${DIR}/../../environment/sasl-ssl/start.sh "${PWD}/docker-compose.sasl-ssl.yml""
```

The *local* [`${PWD}/docker-compose.sasl-ssl.yml`](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-gcp-gcs-sink/docker-compose.sasl-ssl.yml) is only composed of:

```yml
version: '3.5'
services:
  connect:
    volumes:
        - ../../connect/connect-gcp-gcs-sink/keyfile.json:/tmp/keyfile.json:ro
        - ../../environment/sasl-ssl/security:/etc/kafka/secrets
    environment:
      CONNECT_PLUGIN_PATH: /usr/share/confluent-hub-components/confluentinc-kafka-connect-gcs
```

> [!TIP]
> [connect-gcp-gcs-sink](https://github.com/vdesabou/kafka-docker-playground/tree/master/connect/connect-gcp-gcs-sink) example contains various examples with security [gcs-sink-2way-ssl.sh](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-gcp-gcs-sink/gcs-sink-2way-ssl.sh), [gcs-sink-kerberos.sh](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-gcp-gcs-sink/gcs-sink-kerberos.sh), [gcs-sink-ldap-authorizer-sasl-plain.sh](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-gcp-gcs-sink/gcs-sink-ldap-authorizer-sasl-plain.sh) or even RBAC [gcs-sink-rbac-sasl-plain.sh](https://github.com/vdesabou/kafka-docker-playground/blob/master/connect/connect-gcp-gcs-sink/gcs-sink-rbac-sasl-plain.sh)

## 👷‍♂️ Build your example

### 👍️ Examples

#### 🔓️ Plaintext example

#### 🔒️ Security example

### 📝 See properties file

### 🔃 Re-create containers

## 🥽 Deep dive

### 🤖 How CI works

## 🏭 Reusables

### Producing data

### Consuming data

### Using proxy