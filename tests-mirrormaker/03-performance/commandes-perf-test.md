# Commandes de Test de Performance - MirrorMaker 2

## Objectif

Fournir toutes les commandes exactes à exécuter pour les tests de performance MirrorMaker 2, prêtes à l'emploi avec les paramètres adaptés.

---

## Pré-requis

- [x] ✅ Plan de tests performance validé (`plan-tests-performance.md`)
- [ ] Fichiers de configuration créés
- [ ] Variables d'environnement configurées

## Environnement Validé

| Paramètre | Valeur |
|-----------|--------|
| Infrastructure | 4 vCPU / 32 Go RAM / 250 Go Disk |
| Java | OpenJDK 17 |
| Confluent Platform | 7.7.3 |
| Architecture | Collocalisée (Broker + ZK + Connect + SR) |
| JMX Exporters | ✅ Fonctionnels |
| Dashboards Grafana | ✅ Fonctionnels |

---

## 1. Configuration Environnement

### 1.1 Variables d'Environnement

```bash
# Charger avant chaque session de test
export KAFKA_HOME="${KAFKA_INSTALL_PATH}"
export KAFKA_OPTS="-Djava.security.auth.login.config=${CLIENT_JAAS_CONFIG_PATH}"

# Clusters
export SRC_BOOTSTRAP="${SRC_BOOTSTRAP_SERVERS}"
export TGT_BOOTSTRAP="${TGT_BOOTSTRAP_SERVERS}"

# Fichiers de configuration
export PRODUCER_CONFIG="${TEST_CONFIG_PATH}/producer-perf.properties"
export CONSUMER_CONFIG="${TEST_CONFIG_PATH}/consumer-perf.properties"
export CLIENT_CONFIG="${TEST_CONFIG_PATH}/client-test.properties"

# Topics
export TOPIC_PERF="test-mm2-perf"
export TOPIC_LATENCY="test-mm2-latency"
export TOPIC_LARGE="test-mm2-large"
export TOPIC_PERF_REPLICATED="${SOURCE_CLUSTER_ALIAS}.test-mm2-perf"

# Alias cluster source (pour nommage topics répliqués)
export SOURCE_ALIAS="${SOURCE_CLUSTER_ALIAS}"

# Paramètres de test
export MSG_SIZE=${AVG_MESSAGE_SIZE_BYTES}
export NOMINAL_RATE=${NOMINAL_THROUGHPUT_MSG_SEC}
export BURST_RATE=${BURST_THROUGHPUT_MSG_SEC}
```

### 1.2 Fichiers de Configuration

**producer-perf.properties :**

```bash
cat > ${TEST_CONFIG_PATH}/producer-perf.properties << 'EOF'
bootstrap.servers=${SRC_BOOTSTRAP_SERVERS}
security.protocol=SASL_SSL
sasl.mechanism=${SASL_MECHANISM}
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${PERF_TEST_USER}" \
    password="${PERF_TEST_PASSWORD}";
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
acks=all
retries=3
batch.size=65536
linger.ms=5
buffer.memory=67108864
compression.type=lz4
EOF
```

**consumer-perf.properties :**

```bash
cat > ${TEST_CONFIG_PATH}/consumer-perf.properties << 'EOF'
bootstrap.servers=${TGT_BOOTSTRAP_SERVERS}
security.protocol=SASL_SSL
sasl.mechanism=${SASL_MECHANISM}
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${PERF_TEST_USER}" \
    password="${PERF_TEST_PASSWORD}";
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
group.id=perf-consumer-group-${RANDOM}
auto.offset.reset=earliest
enable.auto.commit=true
fetch.min.bytes=1048576
fetch.max.wait.ms=500
EOF
```

---

## 2. Commandes PERF-01 : Charge Nominale

### 2.1 Préparation

```bash
# Vérifier l'état initial
echo "=== État initial ==="

# Lag MM2
curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status | jq .

# Offset du topic
$KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list $SRC_BOOTSTRAP \
    --topic $TOPIC_PERF \
    --time -1 \
    --command-config $CLIENT_CONFIG

# Consumer groups
$KAFKA_HOME/bin/kafka-consumer-groups.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --describe \
    --group "mirrormaker2-*" 2>/dev/null | head -20
```

### 2.2 Exécution - Producer Charge Nominale

```bash
# Paramètres
NUM_RECORDS=3600000  # 1h à 1000 msg/sec
RECORD_SIZE=$MSG_SIZE
THROUGHPUT=$NOMINAL_RATE

# Démarrer le producer perf test
$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic $TOPIC_PERF \
    --num-records $NUM_RECORDS \
    --record-size $RECORD_SIZE \
    --throughput $THROUGHPUT \
    --producer.config $PRODUCER_CONFIG \
    --print-metrics \
    2>&1 | tee perf-01-producer-$(date +%Y%m%d-%H%M%S).log

# Sortie attendue :
# 1000 records sent, 999.0 records/sec (0.95 MB/sec), 5.2 ms avg latency, 120.0 ms max latency.
# ...
```

### 2.3 Consumer Parallèle (Vérification Réplication)

```bash
# Dans un autre terminal - consumer sur cluster cible
$KAFKA_HOME/bin/kafka-consumer-perf-test.sh \
    --broker-list $TGT_BOOTSTRAP \
    --topic $TOPIC_PERF_REPLICATED \
    --messages $NUM_RECORDS \
    --consumer.config $CONSUMER_CONFIG \
    --print-metrics \
    --show-detailed-stats \
    2>&1 | tee perf-01-consumer-$(date +%Y%m%d-%H%M%S).log
```

### 2.4 Monitoring Pendant le Test

```bash
# Script de monitoring continu (lancer dans un terminal séparé)
#!/bin/bash
# monitor-perf.sh

while true; do
    echo "=== $(date) ==="

    # Lag MM2
    echo "MM2 Lag:"
    curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "N/A"'

    # Throughput source
    echo "Source Messages In/sec:"
    curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(rate(kafka_server_brokertopicmetrics_messagesinpersec{job=\"kafka-source\"}[1m]))" \
        | jq -r '.data.result[0].value[1] // "N/A"'

    # CPU brokers
    echo "CPU Brokers (avg):"
    curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=avg(100-rate(node_cpu_seconds_total{mode=\"idle\",job=\"kafka-source\"}[1m])*100)" \
        | jq -r '.data.result[0].value[1] // "N/A"'

    sleep 10
done
```

---

## 3. Commandes PERF-02 : Montée en Charge

### 3.1 Script de Montée en Charge Progressive

```bash
#!/bin/bash
# ramp-up-test.sh

PALIERS=(
    "${NOMINAL_RATE}"
    "$((NOMINAL_RATE * 15 / 10))"
    "$((NOMINAL_RATE * 2))"
    "$((NOMINAL_RATE * 25 / 10))"
    "$((NOMINAL_RATE * 3))"
    "-1"  # Pas de limite = max throughput
)

DUREE_PALIER=600  # 10 minutes par palier
RECORDS_PAR_PALIER=$((DUREE_PALIER * NOMINAL_RATE * 3))  # Assez de records pour chaque palier

RESULTS_FILE="perf-02-rampup-$(date +%Y%m%d-%H%M%S).csv"
echo "palier,throughput_target,throughput_actual,latency_avg,latency_p99,records_sent" > $RESULTS_FILE

for i in "${!PALIERS[@]}"; do
    PALIER=$((i + 1))
    THROUGHPUT=${PALIERS[$i]}

    echo ""
    echo "=========================================="
    echo "  PALIER $PALIER - Throughput cible: $THROUGHPUT msg/sec"
    echo "=========================================="
    echo "Début: $(date)"

    # Lancer le test pour ce palier
    OUTPUT=$($KAFKA_HOME/bin/kafka-producer-perf-test.sh \
        --topic $TOPIC_PERF \
        --num-records $RECORDS_PAR_PALIER \
        --record-size $MSG_SIZE \
        --throughput $THROUGHPUT \
        --producer.config $PRODUCER_CONFIG \
        2>&1)

    # Extraire les métriques de la sortie
    ACTUAL_THROUGHPUT=$(echo "$OUTPUT" | tail -1 | awk -F'[,()]' '{print $3}' | awk '{print $1}')
    AVG_LATENCY=$(echo "$OUTPUT" | tail -1 | awk -F',' '{print $4}' | awk '{print $1}')
    P99_LATENCY=$(echo "$OUTPUT" | tail -1 | awk -F',' '{print $6}' | awk '{print $1}')
    RECORDS_SENT=$(echo "$OUTPUT" | tail -1 | awk '{print $1}')

    echo "$PALIER,$THROUGHPUT,$ACTUAL_THROUGHPUT,$AVG_LATENCY,$P99_LATENCY,$RECORDS_SENT" >> $RESULTS_FILE

    echo "Throughput réel: $ACTUAL_THROUGHPUT msg/sec"
    echo "Latence moyenne: $AVG_LATENCY ms"
    echo "Latence P99: $P99_LATENCY ms"

    # Vérifier le lag MM2
    LAG=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "0"')
    echo "Lag MM2: $LAG records"

    # Condition d'arrêt si dégradation
    if (( $(echo "$P99_LATENCY > 10000" | bc -l) )); then
        echo "⚠️  P99 > 10s - Arrêt du test"
        break
    fi

    if (( $(echo "$LAG > 1000000" | bc -l) )); then
        echo "⚠️  Lag > 1M records - Arrêt du test"
        break
    fi

    echo "Fin palier: $(date)"
    echo ""
done

echo "Résultats sauvegardés dans $RESULTS_FILE"
cat $RESULTS_FILE
```

---

## 4. Commandes PERF-03 : Charge de Pointe (Burst)

### 4.1 Script de Test Burst

```bash
#!/bin/bash
# burst-test.sh

BURST_THROUGHPUT=$BURST_RATE
NOMINAL_THROUGHPUT=$NOMINAL_RATE
BURST_DURATION=300  # 5 minutes
PAUSE_DURATION=300  # 5 minutes
NUM_BURSTS=3

BURST_RECORDS=$((BURST_THROUGHPUT * BURST_DURATION))
NOMINAL_RECORDS=$((NOMINAL_THROUGHPUT * PAUSE_DURATION))

RESULTS_FILE="perf-03-burst-$(date +%Y%m%d-%H%M%S).log"

echo "=== Test de charge de pointe ===" | tee $RESULTS_FILE
echo "Burst: $BURST_THROUGHPUT msg/sec pendant $BURST_DURATION sec" | tee -a $RESULTS_FILE
echo "Pause: $NOMINAL_THROUGHPUT msg/sec pendant $PAUSE_DURATION sec" | tee -a $RESULTS_FILE
echo "Nombre de bursts: $NUM_BURSTS" | tee -a $RESULTS_FILE
echo "" | tee -a $RESULTS_FILE

for burst in $(seq 1 $NUM_BURSTS); do
    echo "========================================" | tee -a $RESULTS_FILE
    echo "  BURST $burst / $NUM_BURSTS" | tee -a $RESULTS_FILE
    echo "========================================" | tee -a $RESULTS_FILE

    # Capturer lag avant burst
    LAG_BEFORE=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "0"')
    echo "Lag avant burst: $LAG_BEFORE" | tee -a $RESULTS_FILE

    # Burst
    echo "Début burst: $(date)" | tee -a $RESULTS_FILE
    $KAFKA_HOME/bin/kafka-producer-perf-test.sh \
        --topic $TOPIC_PERF \
        --num-records $BURST_RECORDS \
        --record-size $MSG_SIZE \
        --throughput $BURST_THROUGHPUT \
        --producer.config $PRODUCER_CONFIG \
        2>&1 | tail -1 | tee -a $RESULTS_FILE

    # Capturer lag après burst
    LAG_AFTER=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "0"')
    echo "Lag après burst: $LAG_AFTER" | tee -a $RESULTS_FILE

    # Pause avec charge nominale
    echo "Début pause (charge nominale): $(date)" | tee -a $RESULTS_FILE
    $KAFKA_HOME/bin/kafka-producer-perf-test.sh \
        --topic $TOPIC_PERF \
        --num-records $NOMINAL_RECORDS \
        --record-size $MSG_SIZE \
        --throughput $NOMINAL_THROUGHPUT \
        --producer.config $PRODUCER_CONFIG \
        2>&1 | tail -1 | tee -a $RESULTS_FILE

    # Capturer lag après pause
    LAG_RECOVERED=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "0"')
    echo "Lag après récupération: $LAG_RECOVERED" | tee -a $RESULTS_FILE
    echo "" | tee -a $RESULTS_FILE
done

echo "Test burst terminé: $(date)" | tee -a $RESULTS_FILE
```

---

## 5. Commandes PERF-04 : Test d'Endurance

### 5.1 Script de Test d'Endurance

```bash
#!/bin/bash
# endurance-test.sh

DURATION_HOURS=${1:-8}
DURATION_SECONDS=$((DURATION_HOURS * 3600))
THROUGHPUT=$NOMINAL_RATE
CHECKPOINT_INTERVAL=3600  # Checkpoint toutes les heures

TOTAL_RECORDS=$((THROUGHPUT * DURATION_SECONDS))
RECORDS_PER_BATCH=$((THROUGHPUT * CHECKPOINT_INTERVAL))

RESULTS_DIR="perf-04-endurance-$(date +%Y%m%d-%H%M%S)"
mkdir -p $RESULTS_DIR

echo "=== Test d'Endurance ===" | tee $RESULTS_DIR/summary.log
echo "Durée: $DURATION_HOURS heures" | tee -a $RESULTS_DIR/summary.log
echo "Throughput: $THROUGHPUT msg/sec" | tee -a $RESULTS_DIR/summary.log
echo "Total records: $TOTAL_RECORDS" | tee -a $RESULTS_DIR/summary.log
echo "Début: $(date)" | tee -a $RESULTS_DIR/summary.log
echo "" | tee -a $RESULTS_DIR/summary.log

# Lancer le monitoring en background
(
    while true; do
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)

        # Métriques système
        LAG=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
            | jq -r '.data.result[0].value[1] // "0"')

        HEAP=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(jvm_memory_bytes_used{job=\"mm2-connect\",area=\"heap\"})" \
            | jq -r '.data.result[0].value[1] // "0"')

        CPU=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=avg(100-rate(node_cpu_seconds_total{mode=\"idle\",job=\"kafka-source\"}[1m])*100)" \
            | jq -r '.data.result[0].value[1] // "0"')

        echo "$TIMESTAMP,$LAG,$HEAP,$CPU" >> $RESULTS_DIR/metrics.csv

        sleep 60
    done
) &
MONITOR_PID=$!

# Fonction de cleanup
cleanup() {
    echo "Arrêt du monitoring..."
    kill $MONITOR_PID 2>/dev/null
    echo "Fin: $(date)" | tee -a $RESULTS_DIR/summary.log
}
trap cleanup EXIT

# Header du fichier CSV
echo "timestamp,lag,heap_bytes,cpu_percent" > $RESULTS_DIR/metrics.csv

# Exécution par batches avec checkpoints
NUM_BATCHES=$((DURATION_HOURS))
for batch in $(seq 1 $NUM_BATCHES); do
    echo "=== Heure $batch / $NUM_BATCHES ===" | tee -a $RESULTS_DIR/summary.log
    echo "Début batch: $(date)" | tee -a $RESULTS_DIR/summary.log

    $KAFKA_HOME/bin/kafka-producer-perf-test.sh \
        --topic $TOPIC_PERF \
        --num-records $RECORDS_PER_BATCH \
        --record-size $MSG_SIZE \
        --throughput $THROUGHPUT \
        --producer.config $PRODUCER_CONFIG \
        2>&1 | tee $RESULTS_DIR/batch-$batch.log | tail -1 | tee -a $RESULTS_DIR/summary.log

    # Checkpoint métriques
    echo "Checkpoint:" | tee -a $RESULTS_DIR/summary.log
    LAG=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "0"')
    echo "  Lag: $LAG" | tee -a $RESULTS_DIR/summary.log

    ERRORS=$(curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status \
        | jq '.tasks[].state' | grep -c "FAILED" || echo "0")
    echo "  Erreurs MM2: $ERRORS" | tee -a $RESULTS_DIR/summary.log

    echo "" | tee -a $RESULTS_DIR/summary.log
done

echo "Test d'endurance terminé" | tee -a $RESULTS_DIR/summary.log
```

---

## 6. Commandes PERF-05 : Messages Volumineux

### 6.1 Script Test Tailles Variables

```bash
#!/bin/bash
# large-messages-test.sh

SIZES=(100 1024 10240 102400 1048576)  # 100B, 1KB, 10KB, 100KB, 1MB
TARGET_MBPS=10  # MB/sec constant
DURATION=900  # 15 minutes par taille

RESULTS_FILE="perf-05-sizes-$(date +%Y%m%d-%H%M%S).csv"
echo "size_bytes,target_msg_sec,actual_msg_sec,actual_mbps,latency_avg_ms,latency_p99_ms" > $RESULTS_FILE

for SIZE in "${SIZES[@]}"; do
    # Calculer le throughput pour maintenir le débit MB/sec constant
    THROUGHPUT=$((TARGET_MBPS * 1024 * 1024 / SIZE))
    RECORDS=$((THROUGHPUT * DURATION))

    echo ""
    echo "=========================================="
    echo "  Taille: $SIZE bytes"
    echo "  Throughput cible: $THROUGHPUT msg/sec"
    echo "  Records: $RECORDS"
    echo "=========================================="

    OUTPUT=$($KAFKA_HOME/bin/kafka-producer-perf-test.sh \
        --topic $TOPIC_LARGE \
        --num-records $RECORDS \
        --record-size $SIZE \
        --throughput $THROUGHPUT \
        --producer.config $PRODUCER_CONFIG \
        2>&1)

    # Parser la sortie
    LAST_LINE=$(echo "$OUTPUT" | tail -1)
    ACTUAL_MSG_SEC=$(echo "$LAST_LINE" | awk -F'[,()]' '{print $3}' | awk '{print $1}')
    ACTUAL_MBPS=$(echo "$LAST_LINE" | awk -F'[,()]' '{print $4}' | awk '{print $1}')
    AVG_LATENCY=$(echo "$LAST_LINE" | awk -F',' '{print $4}' | awk '{print $1}')
    P99_LATENCY=$(echo "$LAST_LINE" | awk -F',' '{print $6}' | awk '{print $1}')

    echo "$SIZE,$THROUGHPUT,$ACTUAL_MSG_SEC,$ACTUAL_MBPS,$AVG_LATENCY,$P99_LATENCY" >> $RESULTS_FILE

    echo "Résultat: $ACTUAL_MSG_SEC msg/sec, $ACTUAL_MBPS MB/sec, P99: $P99_LATENCY ms"

    # Pause pour stabilisation
    echo "Pause 60s pour stabilisation..."
    sleep 60
done

echo ""
echo "Résultats sauvegardés dans $RESULTS_FILE"
cat $RESULTS_FILE
```

---

## 7. Commandes PERF-06 : Latence End-to-End

### 7.1 Script de Mesure de Latence Précise

```bash
#!/bin/bash
# latency-test.sh

NUM_MESSAGES=1000
INTERVAL_MS=1000
RESULTS_FILE="perf-06-latency-$(date +%Y%m%d-%H%M%S).csv"

echo "iteration,send_ts,receive_ts,latency_ms" > $RESULTS_FILE

# Démarrer le consumer en background
CONSUMER_OUTPUT=$(mktemp)
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server $TGT_BOOTSTRAP \
    --topic ${SOURCE_ALIAS}.$TOPIC_LATENCY \
    --consumer.config $CONSUMER_CONFIG \
    --property print.timestamp=true \
    --property print.key=true \
    --timeout-ms 120000 \
    > $CONSUMER_OUTPUT 2>/dev/null &
CONSUMER_PID=$!

# Attendre que le consumer soit prêt
sleep 5

echo "Envoi de $NUM_MESSAGES messages..."

for i in $(seq 1 $NUM_MESSAGES); do
    SEND_TS=$(date +%s%3N)
    MSG_KEY="latency-$i"
    MSG_VALUE="$SEND_TS"

    # Envoyer le message
    echo "$MSG_KEY:$MSG_VALUE" | $KAFKA_HOME/bin/kafka-console-producer.sh \
        --bootstrap-server $SRC_BOOTSTRAP \
        --topic $TOPIC_LATENCY \
        --producer.config $PRODUCER_CONFIG \
        --property parse.key=true \
        --property key.separator=":" \
        2>/dev/null

    # Attendre l'intervalle
    sleep $(echo "scale=3; $INTERVAL_MS/1000" | bc)

    # Afficher progression
    if [ $((i % 100)) -eq 0 ]; then
        echo "  Envoyé: $i / $NUM_MESSAGES"
    fi
done

echo "Attente de la réception de tous les messages..."
sleep 30

# Arrêter le consumer
kill $CONSUMER_PID 2>/dev/null

# Analyser les résultats
echo "Analyse des latences..."

# Parser le fichier de sortie du consumer
while IFS= read -r line; do
    # Format attendu: CreateTime:TIMESTAMP    KEY    VALUE
    RECV_TS=$(echo "$line" | awk -F'\t' '{print $1}' | sed 's/CreateTime://')
    KEY=$(echo "$line" | awk -F'\t' '{print $2}')
    SEND_TS=$(echo "$line" | awk -F'\t' '{print $3}')

    if [[ "$KEY" == latency-* ]] && [ -n "$SEND_TS" ] && [ -n "$RECV_TS" ]; then
        LATENCY=$((RECV_TS - SEND_TS))
        ITERATION=$(echo "$KEY" | sed 's/latency-//')
        echo "$ITERATION,$SEND_TS,$RECV_TS,$LATENCY" >> $RESULTS_FILE
    fi
done < $CONSUMER_OUTPUT

# Cleanup
rm $CONSUMER_OUTPUT

# Calculer les statistiques
echo ""
echo "=== Statistiques de Latence ==="
awk -F',' 'NR>1 {
    sum+=$4; count++;
    latencies[count]=$4;
    if($4>max) max=$4;
    if(min=="" || $4<min) min=$4;
}
END {
    avg=sum/count;
    # Tri pour percentiles
    asort(latencies);
    p50=latencies[int(count*0.5)];
    p90=latencies[int(count*0.9)];
    p95=latencies[int(count*0.95)];
    p99=latencies[int(count*0.99)];

    printf "Messages analysés: %d\n", count;
    printf "Latence Min: %d ms\n", min;
    printf "Latence Max: %d ms\n", max;
    printf "Latence Moyenne: %.2f ms\n", avg;
    printf "Latence P50: %d ms\n", p50;
    printf "Latence P90: %d ms\n", p90;
    printf "Latence P95: %d ms\n", p95;
    printf "Latence P99: %d ms\n", p99;
}' $RESULTS_FILE | tee -a $RESULTS_FILE.summary

echo ""
echo "Résultats détaillés: $RESULTS_FILE"
echo "Résumé: $RESULTS_FILE.summary"
```

---

## 8. Commandes PERF-07 : Rattrapage de Lag

### 8.1 Script de Test de Rattrapage

```bash
#!/bin/bash
# catchup-test.sh

LAG_TARGET=${1:-100000}  # Nombre de records de lag à créer
RESULTS_FILE="perf-07-catchup-$(date +%Y%m%d-%H%M%S).log"

echo "=== Test de Rattrapage ===" | tee $RESULTS_FILE
echo "Lag cible: $LAG_TARGET records" | tee -a $RESULTS_FILE
echo "" | tee -a $RESULTS_FILE

# Étape 1: Mettre MM2 en pause
echo "Étape 1: Pause des connecteurs MM2" | tee -a $RESULTS_FILE
curl -X PUT http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/pause
curl -X PUT http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_CHECKPOINT_CONNECTOR_NAME}/pause
curl -X PUT http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_HEARTBEAT_CONNECTOR_NAME}/pause

sleep 5
echo "Connecteurs en pause" | tee -a $RESULTS_FILE

# Étape 2: Produire les messages pour créer le lag
echo "" | tee -a $RESULTS_FILE
echo "Étape 2: Création du lag ($LAG_TARGET records)" | tee -a $RESULTS_FILE
LAG_START=$(date +%s)

$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic $TOPIC_PERF \
    --num-records $LAG_TARGET \
    --record-size $MSG_SIZE \
    --throughput -1 \
    --producer.config $PRODUCER_CONFIG \
    2>&1 | tail -1 | tee -a $RESULTS_FILE

LAG_END=$(date +%s)
LAG_DURATION=$((LAG_END - LAG_START))
echo "Lag créé en $LAG_DURATION secondes" | tee -a $RESULTS_FILE

# Étape 3: Reprendre MM2 et mesurer le rattrapage
echo "" | tee -a $RESULTS_FILE
echo "Étape 3: Reprise MM2 et mesure du rattrapage" | tee -a $RESULTS_FILE
CATCHUP_START=$(date +%s)

curl -X PUT http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/resume
curl -X PUT http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_CHECKPOINT_CONNECTOR_NAME}/resume
curl -X PUT http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_HEARTBEAT_CONNECTOR_NAME}/resume

echo "Connecteurs repris à $(date)" | tee -a $RESULTS_FILE

# Monitoring du rattrapage
echo "timestamp,lag" > $RESULTS_FILE.lag.csv

while true; do
    LAG=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "0"' | cut -d. -f1)

    TIMESTAMP=$(date +%s)
    echo "$TIMESTAMP,$LAG" >> $RESULTS_FILE.lag.csv

    ELAPSED=$((TIMESTAMP - CATCHUP_START))
    echo "  T+${ELAPSED}s: Lag = $LAG records"

    if [ "$LAG" -lt 100 ]; then
        CATCHUP_END=$(date +%s)
        CATCHUP_DURATION=$((CATCHUP_END - CATCHUP_START))
        echo "" | tee -a $RESULTS_FILE
        echo "=== Rattrapage terminé ===" | tee -a $RESULTS_FILE
        echo "Durée de rattrapage: $CATCHUP_DURATION secondes" | tee -a $RESULTS_FILE
        echo "Vitesse moyenne: $(echo "scale=2; $LAG_TARGET / $CATCHUP_DURATION" | bc) records/sec" | tee -a $RESULTS_FILE
        break
    fi

    if [ "$ELAPSED" -gt 3600 ]; then
        echo "TIMEOUT: Rattrapage non terminé après 1h" | tee -a $RESULTS_FILE
        break
    fi

    sleep 5
done

echo "" | tee -a $RESULTS_FILE
echo "Résultats: $RESULTS_FILE" | tee -a $RESULTS_FILE
echo "Courbe lag: $RESULTS_FILE.lag.csv" | tee -a $RESULTS_FILE
```

---

## 9. Commandes de Vérification et Validation

### 9.1 Vérification Cohérence des Données

```bash
# Compter les messages sur source et cible
echo "=== Vérification cohérence ==="

# Count sur source
SOURCE_COUNT=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list $SRC_BOOTSTRAP \
    --topic $TOPIC_PERF \
    --time -1 \
    --command-config $CLIENT_CONFIG \
    | awk -F':' '{sum+=$3} END {print sum}')
echo "Messages sur source: $SOURCE_COUNT"

# Count sur cible
TARGET_COUNT=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list $TGT_BOOTSTRAP \
    --topic $TOPIC_PERF_REPLICATED \
    --time -1 \
    --command-config $CLIENT_CONFIG \
    | awk -F':' '{sum+=$3} END {print sum}')
echo "Messages sur cible: $TARGET_COUNT"

# Différence
DIFF=$((SOURCE_COUNT - TARGET_COUNT))
echo "Différence: $DIFF"

if [ "$DIFF" -eq 0 ]; then
    echo "✅ Cohérence OK"
else
    echo "⚠️  Écart détecté"
fi
```

### 9.2 Export Métriques Prometheus

```bash
# Exporter les métriques pour analyse
START_TIME=${1:-"1h"}
END_TIME=${2:-"now"}
STEP="15s"

METRICS=(
    "sum(rate(kafka_server_brokertopicmetrics_messagesinpersec{job=\"kafka-source\"}[1m]))"
    "sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})"
    "histogram_quantile(0.99,sum(rate(kafka_network_requestmetrics_totaltimems_bucket{request=\"Produce\"}[1m]))by(le))"
)

for metric in "${METRICS[@]}"; do
    FILENAME=$(echo "$metric" | md5sum | cut -c1-8)
    curl -s -G "${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query_range" \
        --data-urlencode "query=$metric" \
        --data-urlencode "start=$(date -d "-$START_TIME" +%s)" \
        --data-urlencode "end=$(date +%s)" \
        --data-urlencode "step=$STEP" \
        -o "metrics-$FILENAME.json"
done
```

---

## 10. Nettoyage Post-Test

```bash
#!/bin/bash
# cleanup-perf-tests.sh

echo "=== Nettoyage post-test ==="

# Supprimer les données des topics de test
# ATTENTION: Ne pas exécuter en production

# Option 1: Purge via retention
$KAFKA_HOME/bin/kafka-configs.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --entity-type topics \
    --entity-name $TOPIC_PERF \
    --alter \
    --add-config retention.ms=1000

sleep 60

$KAFKA_HOME/bin/kafka-configs.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --entity-type topics \
    --entity-name $TOPIC_PERF \
    --alter \
    --delete-config retention.ms

# Option 2: Supprimer et recréer le topic
# $KAFKA_HOME/bin/kafka-topics.sh \
#     --bootstrap-server $SRC_BOOTSTRAP \
#     --command-config $CLIENT_CONFIG \
#     --delete \
#     --topic $TOPIC_PERF

# Reset consumer groups de test
$KAFKA_HOME/bin/kafka-consumer-groups.sh \
    --bootstrap-server $TGT_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --group perf-consumer-group \
    --reset-offsets \
    --to-earliest \
    --execute \
    --topic $TOPIC_PERF_REPLICATED

echo "Nettoyage terminé"
```

---

## Artifacts Produits

- [ ] Logs des tests (`perf-*.log`)
- [ ] Fichiers CSV de métriques (`perf-*.csv`)
- [ ] Scripts exécutables sauvegardés

---

**Auteur** : `${AUTHOR_NAME}`
**Date de création** : `${DATE_CREATION}`
**Version** : 1.0
