#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

docker-compose -f ../../environment/plaintext/docker-compose.yml -f "${PWD}/docker-compose.plaintext.yml" down -v --remove-orphans
log "Starting up ibmdb2 container to get db2jcc4.jar"
docker-compose -f ../../environment/plaintext/docker-compose.yml -f "${PWD}/docker-compose.plaintext.yml" up -d ibmdb2

rm -f ${DIR}/db2jcc4.jar
log "Getting db2jcc4.jar"
docker cp ibmdb2:/opt/ibm/db2/V11.5/java/db2jcc4.jar ${DIR}/db2jcc4.jar

# Verify IBM DB has started within MAX_WAIT seconds
MAX_WAIT=2500
CUR_WAIT=0
log "Waiting up to $MAX_WAIT seconds for IBM DB to start"
docker container logs ibmdb2 > /tmp/out.txt 2>&1
while [[ ! $(cat /tmp/out.txt) =~ "Setup has completed" ]]; do
sleep 10
docker container logs ibmdb2 > /tmp/out.txt 2>&1
CUR_WAIT=$(( CUR_WAIT+10 ))
if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
     logerror "ERROR: The logs in ibmdb2 container do not show 'Setup has completed' after $MAX_WAIT seconds. Please troubleshoot with 'docker container ps' and 'docker container logs'.\n"
     exit 1
fi
done
log "ibmdb2 DB has started!"

docker-compose -f ../../environment/plaintext/docker-compose.yml -f "${PWD}/docker-compose.plaintext.yml" up -d

../../scripts/wait-for-connect-and-controlcenter.sh

# Keep it for utils.sh
# ${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

log "List tables"
docker exec -i ibmdb2 bash << EOF
su - db2inst1
db2 connect to sample user db2inst1 using passw0rd
db2 LIST TABLES
EOF

log "Creating JDBC IBM DB2 source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
               "tasks.max": "1",
               "connection.url":"jdbc:db2://ibmdb2:25010/sample",
               "connection.user":"db2inst1",
               "connection.password":"passw0rd",
               "mode": "bulk",
               "topic.prefix": "db2-",
               "errors.log.enable": "true",
               "errors.log.include.messages": "true"
          }' \
     http://localhost:8083/connectors/ibmdb2-source/config | jq .


sleep 5

log "Verifying topic db2-PURCHASEORDER"
timeout 60 docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic db2-PURCHASEORDER --from-beginning --max-messages 2

