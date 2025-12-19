# Offsets, Lag et Ordering - Validation Fonctionnelle MirrorMaker 2 Transactis

## Objectif

Valider la gestion des offsets, le suivi du lag de réplication et la préservation de l'ordre des messages par MirrorMaker 2 entre les clusters NEMO et Applicatif.

---

## Pré-requis

- [ ] Tests de réplication de base validés (`verification-replication.md`)
- [x] MirrorMaker 2 avec MirrorCheckpointConnector actif (validé J2)
- [x] Accès aux deux clusters (NEMO et Applicatif)

---

## Contexte Transactis

| Métrique | Seuil SLA | Dashboard |
|----------|-----------|-----------|
| Lag réplication (Active Records) | **≤ 10000** | mm2-detailed-metrics |
| Latence réplication avg | **≤ 1000 ms** | mm2-replication |
| Record Age avg | **≤ 5000 ms** | mm2-replication |

**Prometheus :** `http://localhost:9090`
**Grafana :** `http://localhost:3000`

---

## 1. Tests de Gestion des Offsets

### 1.1 Test FUNC-OFF-01 : Synchronisation des Offsets Consumer Groups

**Objectif :** Vérifier que les offsets des consumer groups sont synchronisés via le MirrorCheckpointConnector.

```bash
#!/bin/bash
# test-offset-sync.sh

TOPIC_SOURCE="test-mm2-offset"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-offset"
CONSUMER_GROUP="test-offset-group"
NUM_MESSAGES=1000

echo "=== Test de synchronisation des offsets ==="

# 1. Créer le topic et produire des messages
echo "1. Création du topic et production..."
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions 3 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic $TOPIC_SOURCE \
    --num-records $NUM_MESSAGES \
    --record-size 100 \
    --throughput -1 \
    --producer.config ${CLIENT_PROPERTIES_PATH} 2>&1 | tail -1

# 2. Consommer partiellement sur source (créer un offset committed)
echo "2. Consommation partielle sur source..."
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE \
    --group $CONSUMER_GROUP \
    --from-beginning \
    --max-messages 500 \
    --timeout-ms 30000 2>/dev/null > /dev/null

# 3. Vérifier l'offset sur source
echo "3. Offset sur source:"
$KAFKA_HOME/bin/kafka-consumer-groups.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --describe \
    --group $CONSUMER_GROUP 2>/dev/null | grep $TOPIC_SOURCE

# 4. Attendre la synchronisation via checkpoint
echo "4. Attente synchronisation checkpoint (60s)..."
sleep 60

# 5. Vérifier l'offset traduit sur cible
echo "5. Vérification offset traduit sur cible..."

# Le groupe sur le cible sera préfixé ou mappé selon la configuration
TARGET_GROUP="${SOURCE_CLUSTER_ALIAS}.$CONSUMER_GROUP"

# Vérifier le topic de checkpoint
echo ""
echo "=== Checkpoints MM2 ==="
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic ${SOURCE_CLUSTER_ALIAS}.checkpoints.internal \
    --from-beginning \
    --max-messages 10 \
    --timeout-ms 10000 2>/dev/null | grep "$CONSUMER_GROUP" | tail -5

# 6. Vérifier si le groupe est visible sur cible
echo ""
echo "=== Consumer groups sur cible ==="
$KAFKA_HOME/bin/kafka-consumer-groups.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --list 2>/dev/null | grep -E "$CONSUMER_GROUP|checkpoint"

# 7. Test de reprise avec offset traduit
echo ""
echo "=== Test de reprise avec offset traduit ==="
echo "Tentative de consommation sur cible avec le groupe traduit..."

# Utiliser l'API de traduction d'offset de MM2
# (Nécessite que sync.group.offsets.enabled=true)
```

### 1.2 Test FUNC-OFF-02 : Vérification des Offsets de Réplication

**Objectif :** Comparer les offsets source et cible pour chaque partition.

```bash
#!/bin/bash
# test-offset-comparison.sh

TOPIC_SOURCE="test-mm2-perf"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-perf"

echo "=== Comparaison des offsets source/cible ==="
echo ""

# Récupérer les offsets source
echo "Offsets Source (earliest / latest):"
SRC_EARLIEST=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${SRC_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_SOURCE \
    --time -2 \
    --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null)

SRC_LATEST=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${SRC_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_SOURCE \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null)

echo "$SRC_EARLIEST"
echo "$SRC_LATEST"

# Récupérer les offsets cible
echo ""
echo "Offsets Cible (earliest / latest):"
TGT_EARLIEST=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${TGT_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_TARGET \
    --time -2 \
    --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null)

TGT_LATEST=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${TGT_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_TARGET \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null)

echo "$TGT_EARLIEST"
echo "$TGT_LATEST"

# Calculer le lag par partition
echo ""
echo "=== Lag par partition ==="
echo "Partition | Source Latest | Cible Latest | Lag"
echo "----------|---------------|--------------|-----"

TOTAL_LAG=0
NUM_PARTITIONS=$(echo "$SRC_LATEST" | wc -l)

for i in $(seq 0 $((NUM_PARTITIONS - 1))); do
    SRC_OFF=$(echo "$SRC_LATEST" | grep ":$i:" | cut -d: -f3)
    TGT_OFF=$(echo "$TGT_LATEST" | grep ":$i:" | cut -d: -f3)

    LAG=$((SRC_OFF - TGT_OFF))
    TOTAL_LAG=$((TOTAL_LAG + LAG))

    printf "    %2d    | %13d | %12d | %5d\n" $i $SRC_OFF $TGT_OFF $LAG
done

echo ""
echo "Lag total: $TOTAL_LAG messages"

if [ $TOTAL_LAG -eq 0 ]; then
    echo "✅ Parfaitement synchronisé"
elif [ $TOTAL_LAG -lt 100 ]; then
    echo "⚠️ Léger retard (acceptable)"
else
    echo "❌ Lag important"
fi
```

---

## 2. Tests de Monitoring du Lag

### 2.1 Test FUNC-LAG-01 : Mesure du Lag en Temps Réel

**Objectif :** Mesurer et suivre le lag de réplication pendant une charge.

```bash
#!/bin/bash
# test-lag-monitoring.sh

DURATION=300  # 5 minutes
INTERVAL=5    # Toutes les 5 secondes
OUTPUT_FILE="lag-monitoring-$(date +%Y%m%d-%H%M%S).csv"

echo "=== Monitoring du lag de réplication ==="
echo "Durée: $DURATION secondes"
echo "Intervalle: $INTERVAL secondes"
echo "Fichier: $OUTPUT_FILE"

# Header CSV
echo "timestamp,lag_total,lag_max,throughput_mm2" > $OUTPUT_FILE

# Démarrer une charge en background
$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic test-mm2-perf \
    --num-records 1000000 \
    --record-size 100 \
    --throughput 1000 \
    --producer.config ${CLIENT_PROPERTIES_PATH} 2>&1 > /dev/null &
PROD_PID=$!

echo "Charge démarrée (PID: $PROD_PID)"
echo ""

# Monitoring
START_TIME=$(date +%s)
while [ $(($(date +%s) - START_TIME)) -lt $DURATION ]; do
    TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)

    # Lag via Prometheus
    LAG_TOTAL=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // 0' 2>/dev/null)

    LAG_MAX=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=max(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // 0' 2>/dev/null)

    THROUGHPUT=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(rate(kafka_consumer_fetch_manager_records_consumed_total{job=\"mm2-connect\"}[1m]))" \
        | jq -r '.data.result[0].value[1] // 0' 2>/dev/null)

    echo "$TIMESTAMP,$LAG_TOTAL,$LAG_MAX,$THROUGHPUT" >> $OUTPUT_FILE
    printf "%s | Lag: %8s | Max: %8s | Throughput: %8s msg/s\n" "$TIMESTAMP" "$LAG_TOTAL" "$LAG_MAX" "${THROUGHPUT%.*}"

    sleep $INTERVAL
done

# Arrêter la charge
kill $PROD_PID 2>/dev/null

echo ""
echo "Monitoring terminé. Résultats dans $OUTPUT_FILE"

# Statistiques
echo ""
echo "=== Statistiques ==="
awk -F',' 'NR>1 {sum+=$2; count++; if($2>max)max=$2; if(min==""||$2<min)min=$2} END {
    print "Lag Min: " min;
    print "Lag Max: " max;
    print "Lag Moyen: " sum/count
}' $OUTPUT_FILE
```

### 2.2 Test FUNC-LAG-02 : Alerting sur Lag

**Objectif :** Vérifier que les alertes se déclenchent en cas de lag excessif.

```bash
#!/bin/bash
# test-lag-alerting.sh

echo "=== Test d'alerting sur lag ==="

# 1. Vérifier la configuration des alertes
echo "1. Vérification des règles d'alerte..."
curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/rules" | \
    jq '.data.groups[].rules[] | select(.name | contains("lag") or contains("Lag"))' 2>/dev/null

# 2. Vérifier les alertes actives
echo ""
echo "2. Alertes actuellement actives..."
curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/alerts" | \
    jq '.data.alerts[] | select(.labels.alertname | contains("Lag"))' 2>/dev/null

# 3. Simuler un lag élevé (en pausant MM2)
echo ""
echo "3. Simulation de lag élevé (pause MM2)..."
curl -X PUT "http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/pause"

# Produire des messages
$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic test-mm2-perf \
    --num-records 50000 \
    --record-size 100 \
    --throughput -1 \
    --producer.config ${CLIENT_PROPERTIES_PATH} 2>&1 | tail -1

echo "Attente du déclenchement des alertes (60s)..."
sleep 60

# 4. Vérifier les alertes
echo ""
echo "4. Alertes après simulation..."
curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/alerts" | \
    jq '.data.alerts[] | {alertname: .labels.alertname, state: .state, value: .value}' 2>/dev/null

# 5. Reprendre MM2
echo ""
echo "5. Reprise de MM2..."
curl -X PUT "http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/resume"

echo "Attente de la résolution des alertes..."
sleep 120

# 6. Vérifier la résolution
echo ""
echo "6. État des alertes après reprise..."
curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/alerts" | \
    jq '.data.alerts[] | select(.labels.alertname | contains("Lag"))' 2>/dev/null
```

---

## 3. Tests de Préservation de l'Ordre

### 3.1 Test FUNC-ORD-01 : Ordre dans une Partition

**Objectif :** Vérifier que l'ordre des messages est préservé au sein d'une partition.

```bash
#!/bin/bash
# test-ordering-partition.sh

TOPIC_SOURCE="test-mm2-ordering"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-ordering"
NUM_MESSAGES=1000

echo "=== Test de préservation de l'ordre (intra-partition) ==="

# 1. Créer le topic avec une seule partition
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions 1 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# 2. Produire des messages numérotés
echo "Production de $NUM_MESSAGES messages numérotés..."
for i in $(seq 1 $NUM_MESSAGES); do
    echo "ORDER-$(printf '%05d' $i)"
done | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE 2>/dev/null

echo "Attente de la réplication..."
sleep 30

# 3. Consommer sur source et cible
echo "Consommation sur source..."
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null > /tmp/ordering-source.txt

echo "Consommation sur cible..."
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null > /tmp/ordering-target.txt

# 4. Vérifier l'ordre
echo ""
echo "=== Vérification de l'ordre ==="

# Vérifier que les fichiers ne sont pas triés (ordre naturel)
SOURCE_SORTED=$(cat /tmp/ordering-source.txt | sort -c 2>&1)
TARGET_SORTED=$(cat /tmp/ordering-target.txt | sort -c 2>&1)

# Comparer les séquences
SOURCE_SEQ=$(cat /tmp/ordering-source.txt | tr '\n' ',' | head -c 100)
TARGET_SEQ=$(cat /tmp/ordering-target.txt | tr '\n' ',' | head -c 100)

echo "Source (extrait): $SOURCE_SEQ..."
echo "Cible (extrait):  $TARGET_SEQ..."

# Vérifier l'ordre croissant
echo ""
echo "Vérification de l'ordre croissant..."

verify_order() {
    local file=$1
    local prev=0
    local errors=0

    while read line; do
        num=$(echo $line | sed 's/ORDER-//' | sed 's/^0*//')
        if [ "$num" -lt "$prev" ]; then
            ((errors++))
        fi
        prev=$num
    done < $file

    echo $errors
}

SRC_ERRORS=$(verify_order /tmp/ordering-source.txt)
TGT_ERRORS=$(verify_order /tmp/ordering-target.txt)

echo "Erreurs d'ordre source: $SRC_ERRORS"
echo "Erreurs d'ordre cible:  $TGT_ERRORS"

# Comparer les deux fichiers
DIFF_COUNT=$(diff /tmp/ordering-source.txt /tmp/ordering-target.txt | grep "^[<>]" | wc -l)

echo ""
if [ "$TGT_ERRORS" -eq 0 ] && [ "$DIFF_COUNT" -eq 0 ]; then
    echo "✅ TEST RÉUSSI - L'ordre est parfaitement préservé"
elif [ "$TGT_ERRORS" -eq 0 ]; then
    echo "⚠️ TEST PARTIEL - Ordre préservé mais contenu différent ($DIFF_COUNT lignes)"
else
    echo "❌ TEST ÉCHOUÉ - $TGT_ERRORS erreurs d'ordre détectées"
fi

# Nettoyage
rm -f /tmp/ordering-*.txt
```

### 3.2 Test FUNC-ORD-02 : Ordre avec Clé de Partitionnement

**Objectif :** Vérifier que les messages avec la même clé restent ordonnés.

```bash
#!/bin/bash
# test-ordering-key.sh

TOPIC_SOURCE="test-mm2-key-ordering"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-key-ordering"
NUM_KEYS=5
MESSAGES_PER_KEY=100

echo "=== Test d'ordre par clé de partitionnement ==="
echo "Clés: $NUM_KEYS"
echo "Messages par clé: $MESSAGES_PER_KEY"

# 1. Créer le topic
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions 10 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# 2. Produire des messages avec clés
echo "Production de messages avec clés..."
for key in $(seq 1 $NUM_KEYS); do
    for seq in $(seq 1 $MESSAGES_PER_KEY); do
        echo "key-$key:KEY${key}-SEQ$(printf '%05d' $seq)"
    done
done | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE \
    --property "parse.key=true" \
    --property "key.separator=:" 2>/dev/null

echo "Attente de la réplication..."
sleep 30

# 3. Consommer avec affichage de la clé
echo "Consommation sur cible..."
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --max-messages $((NUM_KEYS * MESSAGES_PER_KEY)) \
    --property print.key=true \
    --property key.separator=":" \
    --timeout-ms 60000 2>/dev/null > /tmp/key-ordering-target.txt

# 4. Vérifier l'ordre par clé
echo ""
echo "=== Vérification de l'ordre par clé ==="

ALL_OK=true
for key in $(seq 1 $NUM_KEYS); do
    # Extraire les messages de cette clé
    grep "^key-$key:" /tmp/key-ordering-target.txt | cut -d: -f2 > /tmp/key-$key.txt

    # Vérifier l'ordre
    PREV=0
    ERRORS=0
    while read line; do
        SEQ=$(echo $line | sed 's/KEY[0-9]*-SEQ//' | sed 's/^0*//')
        if [ "$SEQ" -le "$PREV" ]; then
            ((ERRORS++))
        fi
        PREV=$SEQ
    done < /tmp/key-$key.txt

    COUNT=$(wc -l < /tmp/key-$key.txt)

    if [ "$ERRORS" -eq 0 ]; then
        echo "✅ Clé $key: $COUNT messages en ordre"
    else
        echo "❌ Clé $key: $ERRORS erreurs d'ordre sur $COUNT messages"
        ALL_OK=false
    fi
done

echo ""
if $ALL_OK; then
    echo "✅ TEST RÉUSSI - L'ordre est préservé pour toutes les clés"
else
    echo "❌ TEST ÉCHOUÉ - Des erreurs d'ordre ont été détectées"
fi

# Nettoyage
rm -f /tmp/key-ordering-target.txt /tmp/key-*.txt
```

---

## 4. Tests des Heartbeats

### 4.1 Test FUNC-HB-01 : Vérification des Heartbeats

**Objectif :** Vérifier que le MirrorHeartbeatConnector fonctionne correctement.

```bash
#!/bin/bash
# test-heartbeats.sh

HEARTBEAT_TOPIC="heartbeats"

echo "=== Vérification des Heartbeats MM2 ==="

# 1. Vérifier l'état du connecteur heartbeat
echo "1. État du connecteur heartbeat..."
curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_HEARTBEAT_CONNECTOR_NAME}/status | jq .

# 2. Consommer les heartbeats sur le cible
echo ""
echo "2. Heartbeats récents (10 derniers)..."
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $HEARTBEAT_TOPIC \
    --from-beginning \
    --max-messages 10 \
    --timeout-ms 30000 2>/dev/null

# 3. Vérifier la fréquence des heartbeats
echo ""
echo "3. Fréquence des heartbeats..."

# Consommer avec timestamps
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $HEARTBEAT_TOPIC \
    --property print.timestamp=true \
    --max-messages 5 \
    --timeout-ms 30000 2>/dev/null

echo ""
echo "Les heartbeats devraient arriver toutes les ${MM2_HEARTBEAT_INTERVAL} secondes"

# 4. Vérifier la latence via les heartbeats
echo ""
echo "4. Mesure de latence via heartbeats..."
# Le heartbeat contient un timestamp qui peut être comparé au temps de réception
```

---

## 5. Tableau Récapitulatif des Tests

| ID | Test | Description | Résultat | Observations |
|----|------|-------------|----------|--------------|
| FUNC-OFF-01 | Sync offsets | Consumer groups sync | ⬜ | - |
| FUNC-OFF-02 | Comparaison offsets | Offsets source/cible | ⬜ | - |
| FUNC-LAG-01 | Monitoring lag | Suivi temps réel | ⬜ | - |
| FUNC-LAG-02 | Alerting lag | Déclenchement alertes | ⬜ | - |
| FUNC-ORD-01 | Ordre partition | Intra-partition | ⬜ | - |
| FUNC-ORD-02 | Ordre par clé | Avec partitionnement | ⬜ | - |
| FUNC-HB-01 | Heartbeats | Fonctionnement | ⬜ | - |

**Légende:** ✅ Pass | ⚠️ Partiel | ❌ Fail | ⬜ Non testé

---

## 6. Critères d'Acceptation

| Critère | Obligatoire | Résultat |
|---------|-------------|----------|
| Lag < seuil en régime nominal | OUI | ⬜ |
| Ordre préservé (intra-partition) | OUI | ⬜ |
| Ordre préservé (par clé) | OUI | ⬜ |
| Offsets synchronisés | NON | ⬜ |
| Heartbeats fonctionnels | NON | ⬜ |
| Alerting lag fonctionnel | OUI | ⬜ |

---

## Artifacts Produits

- [ ] Fichiers CSV de monitoring lag
- [ ] Logs des tests d'ordre
- [ ] Rapport de validation

---

**Client** : Transactis
**SLA Lag** : ≤ 10000 records
**Version** : 2.0
