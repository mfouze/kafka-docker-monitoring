# Tuning MirrorMaker 2 Connect - Transactis

## Objectif

Fournir les configurations optimisées de MirrorMaker 2 en mode Connect distribué pour atteindre le SLA < 1h de downtime annuel.

---

## Environnement Validé ✅

| Paramètre | Valeur |
|-----------|--------|
| **vCPU** | 4 |
| **RAM** | 32 Go |
| **Disque** | 250 Go |
| **Java** | OpenJDK 17 |
| **Confluent Platform** | 7.7.3 |
| **Architecture** | **COLLOCALISÉE** (Broker + ZK + Connect + SR sur même instance) |

### ⚠️ Répartition Mémoire Connect (Architecture Collocalisée)

| Composant | Heap Recommandé | Note |
|-----------|-----------------|------|
| Kafka Broker | 6 Go | - |
| **Kafka Connect (MM2)** | **4 Go** | Ce composant |
| Schema Registry | 1 Go | - |
| ZooKeeper | 1 Go | - |
| OS + Page Cache | ~20 Go | - |
| **TOTAL** | **32 Go** | ✅ |

---

## 1. Architecture Connect Distribuée

### 1.1 Mode Actuel vs Cible

| Aspect | Actuel (Standalone) | Cible (Connect Distribué) |
|--------|---------------------|---------------------------|
| Haute disponibilité | NON (SPOF) | OUI |
| Rebalancing auto | NON | OUI |
| API REST config | NON | OUI |
| Scaling horizontal | Manuel | Automatique |
| Conformité SLA | NON | OUI |

### 1.2 Topologie Recommandée

```
┌─────────────────────────────────────────────────────────────────────┐
│                   KAFKA CONNECT CLUSTER (MM2)                        │
│                   Minimum 3 workers pour HA                          │
│                                                                      │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐           │
│  │  Worker 1     │  │  Worker 2     │  │  Worker 3     │           │
│  │  REST :8083   │  │  REST :8083   │  │  REST :8083   │           │
│  │  JMX  :7072   │  │  JMX  :7072   │  │  JMX  :7072   │           │
│  │               │  │               │  │               │           │
│  │  Tâches MM2:  │  │  Tâches MM2:  │  │  Tâches MM2:  │           │
│  │  - Source x2  │  │  - Source x2  │  │  - Source x2  │           │
│  │  - Checkpoint │  │  - Checkpoint │  │  - Heartbeat  │           │
│  └───────────────┘  └───────────────┘  └───────────────┘           │
│                                                                      │
│  Topics internes Connect (RF=3) :                                    │
│  ├── mm2-connect-configs                                             │
│  ├── mm2-connect-offsets                                             │
│  └── mm2-connect-status                                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Configuration Connect Worker

### 2.1 connect-distributed.properties

```properties
# =============================================================================
# KAFKA CONNECT DISTRIBUTED - CONFIGURATION MM2 TRANSACTIS
# SLA Target: < 1h downtime/an | Confluent Platform 7.7.3
# =============================================================================

# -----------------------------------------------------------------------------
# CLUSTER CONNECT
# -----------------------------------------------------------------------------
# Group ID unique pour ce cluster Connect
group.id=mm2-connect-cluster

# -----------------------------------------------------------------------------
# CONNEXION KAFKA (CLUSTER CIBLE - car MM2 côté target)
# -----------------------------------------------------------------------------
bootstrap.servers=${TARGET_BOOTSTRAP_SERVERS}
# Exemple: kafka-target-1:9093,kafka-target-2:9093,kafka-target-3:9093

# Protocole sécurisé
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${CONNECT_USER}" \
    password="${CONNECT_PASSWORD}";

# TLS
ssl.truststore.location=/etc/kafka-connect/ssl/truststore.jks
ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD}

# -----------------------------------------------------------------------------
# TOPICS INTERNES CONNECT (CRITIQUE POUR HA)
# -----------------------------------------------------------------------------
# Configuration storage (RF=3 obligatoire)
config.storage.topic=mm2-connect-configs
config.storage.replication.factor=3

# Offset storage (RF=3 obligatoire)
offset.storage.topic=mm2-connect-offsets
offset.storage.replication.factor=3
offset.storage.partitions=25

# Status storage (RF=3 obligatoire)
status.storage.topic=mm2-connect-status
status.storage.replication.factor=3
status.storage.partitions=5

# -----------------------------------------------------------------------------
# PRODUCER CONFIG (pour écrire dans les topics internes)
# -----------------------------------------------------------------------------
producer.security.protocol=SASL_SSL
producer.sasl.mechanism=SCRAM-SHA-512
producer.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${CONNECT_USER}" \
    password="${CONNECT_PASSWORD}";
producer.ssl.truststore.location=/etc/kafka-connect/ssl/truststore.jks
producer.ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD}

# Performance producer
producer.acks=all
producer.retries=2147483647
producer.max.in.flight.requests.per.connection=1
producer.enable.idempotence=true

# -----------------------------------------------------------------------------
# CONSUMER CONFIG (pour lire les topics internes)
# -----------------------------------------------------------------------------
consumer.security.protocol=SASL_SSL
consumer.sasl.mechanism=SCRAM-SHA-512
consumer.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${CONNECT_USER}" \
    password="${CONNECT_PASSWORD}";
consumer.ssl.truststore.location=/etc/kafka-connect/ssl/truststore.jks
consumer.ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD}

# -----------------------------------------------------------------------------
# ADMIN CLIENT CONFIG
# -----------------------------------------------------------------------------
admin.security.protocol=SASL_SSL
admin.sasl.mechanism=SCRAM-SHA-512
admin.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${CONNECT_USER}" \
    password="${CONNECT_PASSWORD}";
admin.ssl.truststore.location=/etc/kafka-connect/ssl/truststore.jks
admin.ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD}

# -----------------------------------------------------------------------------
# CONVERTERS (JSON pour simplicité, Avro si Schema Registry)
# -----------------------------------------------------------------------------
key.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false

value.converter=org.apache.kafka.connect.json.JsonConverter
value.converter.schemas.enable=false

# Pour utiliser avec Schema Registry :
# key.converter=io.confluent.connect.avro.AvroConverter
# key.converter.schema.registry.url=http://schema-registry:8081
# value.converter=io.confluent.connect.avro.AvroConverter
# value.converter.schema.registry.url=http://schema-registry:8081

# -----------------------------------------------------------------------------
# REBALANCING ET HEARTBEAT (CRITIQUE POUR SLA)
# -----------------------------------------------------------------------------
# Timeout session (détection panne worker)
session.timeout.ms=30000

# Heartbeat (doit être < session.timeout.ms / 3)
heartbeat.interval.ms=10000

# Timeout rebalancing (temps max pour un rebalance)
rebalance.timeout.ms=60000

# Délai avant rebalancing scheduled
scheduled.rebalance.max.delay.ms=60000

# -----------------------------------------------------------------------------
# OFFSET MANAGEMENT
# -----------------------------------------------------------------------------
# Intervalle de commit des offsets
offset.flush.interval.ms=10000

# Timeout commit
offset.flush.timeout.ms=5000

# -----------------------------------------------------------------------------
# REST API
# -----------------------------------------------------------------------------
rest.host.name=0.0.0.0
rest.port=8083
rest.advertised.host.name=${HOSTNAME}
rest.advertised.port=8083

# Extension REST pour monitoring
# rest.extension.classes=org.apache.kafka.connect.rest.ConnectRestExtension

# -----------------------------------------------------------------------------
# PLUGINS
# -----------------------------------------------------------------------------
plugin.path=/opt/kafka/connect-plugins,/usr/share/java

# -----------------------------------------------------------------------------
# LOGGING ET MONITORING
# -----------------------------------------------------------------------------
# JMX Exporter configuré via KAFKA_OPTS
# Métriques exposées sur port 7072

# -----------------------------------------------------------------------------
# ERROR HANDLING
# -----------------------------------------------------------------------------
# Tolérance aux erreurs (à ajuster selon criticité)
errors.tolerance=none
# errors.tolerance=all (si on veut skip les erreurs)

# Dead Letter Queue
# errors.deadletterqueue.topic.name=mm2-dlq
# errors.deadletterqueue.topic.replication.factor=3
# errors.deadletterqueue.context.headers.enable=true

# -----------------------------------------------------------------------------
# EXACTLY ONCE (si requis)
# -----------------------------------------------------------------------------
# exactly.once.source.support=enabled
# transaction.boundary=poll
```

---

## 3. Configuration JVM Connect (COLLOCALISÉE)

### 3.1 Fichier connect-distributed.sh ou service file

```bash
# =============================================================================
# JVM OPTIONS - KAFKA CONNECT MM2 (ARCHITECTURE COLLOCALISÉE)
# 32 Go RAM partagée → 4 Go Heap pour Connect
# =============================================================================

export KAFKA_HEAP_OPTS="-Xms4G -Xmx4G"

export KAFKA_JVM_PERFORMANCE_OPTS="
    -server
    -XX:+UseG1GC
    -XX:MaxGCPauseMillis=200
    -XX:InitiatingHeapOccupancyPercent=35
    -XX:G1HeapRegionSize=16M
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+ParallelRefProcEnabled
    -XX:+DisableExplicitGC
    -Djava.awt.headless=true
"

# JMX Exporter pour Prometheus
export KAFKA_OPTS="-javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=7072:/etc/kafka-connect/jmx_exporter.yml"
```

### 3.2 Contexte Mémoire (Instance Collocalisée)

```
┌─────────────────────────────────────────────────────────────┐
│                    RAM TOTALE : 32 Go                       │
├─────────────────────────────────────────────────────────────┤
│  Kafka Broker JVM        │ 6 Go  │                          │
│  >>> Kafka Connect JVM   │ 4 Go  │ ◄── CE COMPOSANT         │
│  Schema Registry JVM     │ 1 Go  │                          │
│  ZooKeeper JVM           │ 1 Go  │                          │
├─────────────────────────────────────────────────────────────┤
│  OS + Page Cache         │ ~20 Go│                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Configurations Connecteurs MM2 (JSON)

### 4.1 MirrorSourceConnector

```json
{
  "name": "nemo-to-applicatif-source",
  "config": {
    "connector.class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
    "tasks.max": "6",

    "source.cluster.alias": "nemo",
    "target.cluster.alias": "applicatif",

    "source.cluster.bootstrap.servers": "${SOURCE_BOOTSTRAP_SERVERS}",
    "target.cluster.bootstrap.servers": "${TARGET_BOOTSTRAP_SERVERS}",

    "source.cluster.security.protocol": "SASL_SSL",
    "source.cluster.sasl.mechanism": "SCRAM-SHA-512",
    "source.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${SOURCE_USER}\" password=\"${SOURCE_PASSWORD}\";",
    "source.cluster.ssl.truststore.location": "/etc/kafka-connect/ssl/source-truststore.jks",
    "source.cluster.ssl.truststore.password": "${SOURCE_TRUSTSTORE_PASSWORD}",

    "target.cluster.security.protocol": "SASL_SSL",
    "target.cluster.sasl.mechanism": "SCRAM-SHA-512",
    "target.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${TARGET_USER}\" password=\"${TARGET_PASSWORD}\";",
    "target.cluster.ssl.truststore.location": "/etc/kafka-connect/ssl/target-truststore.jks",
    "target.cluster.ssl.truststore.password": "${TARGET_TRUSTSTORE_PASSWORD}",

    "topics": ".*",
    "topics.exclude": ".*[\\.\\-]internal,.*\\.replica,__.*,connect-.*,mm2-.*",

    "replication.factor": "3",
    "sync.topic.configs.enabled": "true",
    "sync.topic.acls.enabled": "false",
    "refresh.topics.enabled": "true",
    "refresh.topics.interval.seconds": "60",

    "producer.override.acks": "all",
    "producer.override.batch.size": "65536",
    "producer.override.linger.ms": "5",
    "producer.override.buffer.memory": "67108864",
    "producer.override.compression.type": "lz4",
    "producer.override.max.in.flight.requests.per.connection": "1",
    "producer.override.enable.idempotence": "true",
    "producer.override.retries": "2147483647",

    "consumer.override.fetch.max.bytes": "52428800",
    "consumer.override.max.poll.records": "1000",
    "consumer.override.auto.offset.reset": "earliest",
    "consumer.override.max.poll.interval.ms": "300000",
    "consumer.override.session.timeout.ms": "30000",
    "consumer.override.heartbeat.interval.ms": "10000",

    "offset-syncs.topic.replication.factor": "3",

    "key.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter"
  }
}
```

### 4.2 MirrorCheckpointConnector

```json
{
  "name": "nemo-to-applicatif-checkpoint",
  "config": {
    "connector.class": "org.apache.kafka.connect.mirror.MirrorCheckpointConnector",
    "tasks.max": "1",

    "source.cluster.alias": "nemo",
    "target.cluster.alias": "applicatif",

    "source.cluster.bootstrap.servers": "${SOURCE_BOOTSTRAP_SERVERS}",
    "target.cluster.bootstrap.servers": "${TARGET_BOOTSTRAP_SERVERS}",

    "source.cluster.security.protocol": "SASL_SSL",
    "source.cluster.sasl.mechanism": "SCRAM-SHA-512",
    "source.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${SOURCE_USER}\" password=\"${SOURCE_PASSWORD}\";",
    "source.cluster.ssl.truststore.location": "/etc/kafka-connect/ssl/source-truststore.jks",
    "source.cluster.ssl.truststore.password": "${SOURCE_TRUSTSTORE_PASSWORD}",

    "target.cluster.security.protocol": "SASL_SSL",
    "target.cluster.sasl.mechanism": "SCRAM-SHA-512",
    "target.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${TARGET_USER}\" password=\"${TARGET_PASSWORD}\";",
    "target.cluster.ssl.truststore.location": "/etc/kafka-connect/ssl/target-truststore.jks",
    "target.cluster.ssl.truststore.password": "${TARGET_TRUSTSTORE_PASSWORD}",

    "topics": ".*",
    "topics.exclude": ".*[\\.\\-]internal,.*\\.replica,__.*,connect-.*,mm2-.*",
    "groups": ".*",
    "groups.exclude": "console-consumer.*,_.*",

    "checkpoints.topic.replication.factor": "3",
    "emit.checkpoints.enabled": "true",
    "emit.checkpoints.interval.seconds": "10",
    "sync.group.offsets.enabled": "true",
    "sync.group.offsets.interval.seconds": "10",
    "refresh.groups.enabled": "true",
    "refresh.groups.interval.seconds": "60",

    "key.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter"
  }
}
```

### 4.3 MirrorHeartbeatConnector

```json
{
  "name": "nemo-to-applicatif-heartbeat",
  "config": {
    "connector.class": "org.apache.kafka.connect.mirror.MirrorHeartbeatConnector",
    "tasks.max": "1",

    "source.cluster.alias": "nemo",
    "target.cluster.alias": "applicatif",

    "source.cluster.bootstrap.servers": "${SOURCE_BOOTSTRAP_SERVERS}",
    "target.cluster.bootstrap.servers": "${TARGET_BOOTSTRAP_SERVERS}",

    "source.cluster.security.protocol": "SASL_SSL",
    "source.cluster.sasl.mechanism": "SCRAM-SHA-512",
    "source.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${SOURCE_USER}\" password=\"${SOURCE_PASSWORD}\";",
    "source.cluster.ssl.truststore.location": "/etc/kafka-connect/ssl/source-truststore.jks",
    "source.cluster.ssl.truststore.password": "${SOURCE_TRUSTSTORE_PASSWORD}",

    "target.cluster.security.protocol": "SASL_SSL",
    "target.cluster.sasl.mechanism": "SCRAM-SHA-512",
    "target.cluster.sasl.jaas.config": "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${TARGET_USER}\" password=\"${TARGET_PASSWORD}\";",
    "target.cluster.ssl.truststore.location": "/etc/kafka-connect/ssl/target-truststore.jks",
    "target.cluster.ssl.truststore.password": "${TARGET_TRUSTSTORE_PASSWORD}",

    "heartbeats.topic.replication.factor": "3",
    "emit.heartbeats.enabled": "true",
    "emit.heartbeats.interval.seconds": "5",

    "key.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",
    "value.converter": "org.apache.kafka.connect.converters.ByteArrayConverter"
  }
}
```

---

## 5. Déploiement des Connecteurs via API REST

### 5.1 Script de Déploiement

```bash
#!/bin/bash
# =============================================================================
# DÉPLOIEMENT CONNECTEURS MM2 VIA API REST
# =============================================================================

CONNECT_REST_URL="http://localhost:8083"
CONFIG_DIR="/etc/kafka-connect/connectors"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Vérifier que Connect est UP
check_connect() {
    log_info "Vérification de Connect..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" ${CONNECT_REST_URL}/)
    if [ "$RESPONSE" != "200" ]; then
        log_error "Connect n'est pas accessible (HTTP $RESPONSE)"
        exit 1
    fi
    log_info "Connect OK"
}

# Lister les connecteurs existants
list_connectors() {
    log_info "Connecteurs existants:"
    curl -s ${CONNECT_REST_URL}/connectors | jq .
}

# Déployer un connecteur
deploy_connector() {
    local CONFIG_FILE=$1
    local CONNECTOR_NAME=$(cat $CONFIG_FILE | jq -r '.name')

    log_info "Déploiement de $CONNECTOR_NAME..."

    # Vérifier si le connecteur existe
    EXISTS=$(curl -s -o /dev/null -w "%{http_code}" ${CONNECT_REST_URL}/connectors/${CONNECTOR_NAME})

    if [ "$EXISTS" == "200" ]; then
        log_warn "Le connecteur $CONNECTOR_NAME existe déjà, mise à jour..."
        curl -s -X PUT \
            -H "Content-Type: application/json" \
            -d @"$CONFIG_FILE" \
            "${CONNECT_REST_URL}/connectors/${CONNECTOR_NAME}/config" | jq .
    else
        log_info "Création du connecteur $CONNECTOR_NAME..."
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d @"$CONFIG_FILE" \
            "${CONNECT_REST_URL}/connectors" | jq .
    fi
}

# Vérifier le statut d'un connecteur
check_status() {
    local CONNECTOR_NAME=$1
    log_info "Statut de $CONNECTOR_NAME:"
    curl -s ${CONNECT_REST_URL}/connectors/${CONNECTOR_NAME}/status | jq .
}

# Supprimer un connecteur
delete_connector() {
    local CONNECTOR_NAME=$1
    log_warn "Suppression de $CONNECTOR_NAME..."
    curl -s -X DELETE ${CONNECT_REST_URL}/connectors/${CONNECTOR_NAME}
}

# Pause un connecteur
pause_connector() {
    local CONNECTOR_NAME=$1
    log_warn "Pause de $CONNECTOR_NAME..."
    curl -s -X PUT ${CONNECT_REST_URL}/connectors/${CONNECTOR_NAME}/pause
}

# Resume un connecteur
resume_connector() {
    local CONNECTOR_NAME=$1
    log_info "Resume de $CONNECTOR_NAME..."
    curl -s -X PUT ${CONNECT_REST_URL}/connectors/${CONNECTOR_NAME}/resume
}

# Restart un connecteur
restart_connector() {
    local CONNECTOR_NAME=$1
    log_info "Restart de $CONNECTOR_NAME..."
    curl -s -X POST ${CONNECT_REST_URL}/connectors/${CONNECTOR_NAME}/restart
}

# Main
main() {
    check_connect

    case "$1" in
        deploy)
            deploy_connector "${CONFIG_DIR}/mirror-source-connector.json"
            sleep 5
            deploy_connector "${CONFIG_DIR}/mirror-checkpoint-connector.json"
            sleep 5
            deploy_connector "${CONFIG_DIR}/mirror-heartbeat-connector.json"
            ;;
        status)
            list_connectors
            echo ""
            check_status "nemo-to-applicatif-source"
            check_status "nemo-to-applicatif-checkpoint"
            check_status "nemo-to-applicatif-heartbeat"
            ;;
        delete)
            delete_connector "nemo-to-applicatif-source"
            delete_connector "nemo-to-applicatif-checkpoint"
            delete_connector "nemo-to-applicatif-heartbeat"
            ;;
        restart)
            restart_connector "nemo-to-applicatif-source"
            restart_connector "nemo-to-applicatif-checkpoint"
            restart_connector "nemo-to-applicatif-heartbeat"
            ;;
        *)
            echo "Usage: $0 {deploy|status|delete|restart}"
            exit 1
            ;;
    esac
}

main "$@"
```

---

## 6. Métriques de Validation MM2

### 6.1 Requêtes Prometheus

```promql
# =============================================================================
# MÉTRIQUES MM2 - VALIDATION SLA
# Dashboard: MM2 Replication Metrics (mm2-replication)
# =============================================================================

# --- LATENCE RÉPLICATION (CRITIQUE) ---

# Latence moyenne réplication - SEUIL MAX: 1000ms
avg(kafka_connect_mirror_source_connector_replication_latency_ms)
# ALERTE si > 1000ms

# Latence max réplication - SEUIL MAX: 5000ms
max(kafka_connect_mirror_source_connector_replication_latency_ms_max)
# ALERTE si > 5000ms

# --- AGE DES RECORDS ---

# Age moyen - SEUIL MAX: 5000ms
avg(kafka_connect_mirror_source_connector_record_age_ms_avg)

# Age max - SEUIL MAX: 30000ms
max(kafka_connect_mirror_source_connector_record_age_ms_max)

# --- THROUGHPUT ---

# Records/sec répliqués
sum(kafka_connect_mirror_source_connector_record_rate)

# Bytes/sec répliqués
sum(kafka_connect_mirror_source_connector_byte_rate)

# --- LAG (via mm2-detailed-metrics) ---

# Active records (lag indicator) - SEUIL MAX: 10000
sum(kafka_connect_source_task_metrics_source_record_active_count{connector=~".*source.*"})

# Ratio replication (doit être ~100%)
100 * sum(kafka_connect_source_task_metrics_source_record_write_total)
    / sum(kafka_connect_source_task_metrics_source_record_poll_total)

# --- SANTÉ CONNECTEURS ---

# Connecteurs en état RUNNING
count(kafka_connect_connector_status{status="running"})

# Tâches en erreur - DOIT ÊTRE 0
count(kafka_connect_connector_task_status{status="failed"})

# --- ERREURS PRODUCER MM2 ---

# Erreurs d'écriture - DOIT ÊTRE 0
sum(kafka_producer_producer_metrics_record_error_total{client_id=~".*mirror.*"})

# Buffer exhausted (backpressure) - DOIT ÊTRE 0
sum(kafka_producer_producer_metrics_buffer_exhausted_total{client_id=~".*mirror.*"})
```

### 6.2 Seuils de Validation SLA

| Métrique | Seuil OK | Seuil Warning | Seuil Critical |
|----------|----------|---------------|----------------|
| Replication Latency Avg | < 100ms | 100-500ms | > 1000ms |
| Replication Latency Max | < 500ms | 500-2000ms | > 5000ms |
| Record Age Avg | < 1000ms | 1000-5000ms | > 5000ms |
| Active Records (Lag) | < 1000 | 1000-10000 | > 10000 |
| Replication Ratio | > 99% | 95-99% | < 95% |
| Failed Tasks | 0 | - | > 0 |
| Producer Errors | 0 | 1-10 | > 10 |

---

## 7. Règles d'Alerte Prometheus

```yaml
# =============================================================================
# ALERTES MM2 - CONFORMITÉ SLA < 1h ANNUEL
# =============================================================================

groups:
  - name: mm2-sla-alerts
    rules:
      # Latence réplication critique
      - alert: MM2ReplicationLatencyCritical
        expr: avg(kafka_connect_mirror_source_connector_replication_latency_ms) > 1000
        for: 2m
        labels:
          severity: critical
          sla_impact: high
        annotations:
          summary: "MM2 replication latency critical"
          description: "Avg replication latency is {{ $value }}ms (threshold: 1000ms)"

      # Lag croissant
      - alert: MM2LagIncreasing
        expr: |
          deriv(sum(kafka_connect_source_task_metrics_source_record_active_count)[5m:1m]) > 500
        for: 3m
        labels:
          severity: warning
          sla_impact: medium
        annotations:
          summary: "MM2 lag is increasing"
          description: "Lag growth rate: {{ $value }} records/min"

      # Lag critique
      - alert: MM2LagCritical
        expr: sum(kafka_connect_source_task_metrics_source_record_active_count) > 10000
        for: 1m
        labels:
          severity: critical
          sla_impact: high
        annotations:
          summary: "MM2 lag is critical"
          description: "Current lag: {{ $value }} records (threshold: 10000)"

      # Tâche en échec
      - alert: MM2TaskFailed
        expr: count(kafka_connect_connector_task_status{status="failed",connector=~".*mirror.*"}) > 0
        for: 1m
        labels:
          severity: critical
          sla_impact: high
        annotations:
          summary: "MM2 task failed"
          description: "{{ $value }} MM2 task(s) in failed state"

      # Connecteur arrêté
      - alert: MM2ConnectorNotRunning
        expr: count(kafka_connect_connector_status{status="running",connector=~".*mirror.*"}) < 3
        for: 1m
        labels:
          severity: critical
          sla_impact: high
        annotations:
          summary: "MM2 connector not running"
          description: "Only {{ $value }} MM2 connectors running (expected: 3)"

      # Erreurs producer
      - alert: MM2ProducerErrors
        expr: sum(rate(kafka_producer_producer_metrics_record_error_total{client_id=~".*mirror.*"}[5m])) > 0
        for: 2m
        labels:
          severity: warning
          sla_impact: medium
        annotations:
          summary: "MM2 producer errors detected"
          description: "Error rate: {{ $value }}/sec"

      # Heartbeat manquant
      - alert: MM2HeartbeatMissing
        expr: |
          absent(kafka_connect_connector_status{connector=~".*heartbeat.*",status="running"})
        for: 2m
        labels:
          severity: warning
          sla_impact: low
        annotations:
          summary: "MM2 heartbeat connector missing"
          description: "Heartbeat connector not running"
```

---

## 8. Checklist de Déploiement MM2

### 8.1 Pré-déploiement

| Étape | Action | Validé |
|-------|--------|--------|
| 1 | Topics internes créés (RF=3) | [ ] |
| 2 | Certificats déployés sur 3 workers | [ ] |
| 3 | Credentials SASL source/target valides | [ ] |
| 4 | Connectivité réseau source→target testée | [ ] |
| 5 | JMX Exporter configuré port 7072 | [ ] |
| 6 | Prometheus scrape configuré | [ ] |

### 8.2 Post-déploiement

| Vérification | Commande/Métrique | Attendu |
|--------------|-------------------|---------|
| Connecteurs RUNNING | API REST /connectors/status | 3 running |
| Tâches RUNNING | API REST | 8 tasks (6+1+1) |
| Latence < 1000ms | Grafana mm2-replication | < 1000ms |
| Lag < 10000 | Grafana mm2-detailed-metrics | < 10000 |
| Pas d'erreurs | Producer errors metric | 0 |

---

## Artifacts Produits

- [x] Configuration connect-distributed.properties
- [x] Configuration JVM Connect (adapté collocation 4 Go)
- [x] JSON MirrorSourceConnector
- [x] JSON MirrorCheckpointConnector
- [x] JSON MirrorHeartbeatConnector
- [x] Script déploiement API REST
- [x] Règles d'alerte Prometheus
- [x] Checklist déploiement

---

**Client** : Transactis
**Architecture** : Collocalisée (4 vCPU / 32 Go / 250 Go)
**Version** : 2.0 - Adapté architecture collocalisée
**Conformité SLA** : < 1h downtime annuel
