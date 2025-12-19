# Tests de Rebootstrap - Validation Fonctionnelle MirrorMaker 2 Transactis

## Objectif

Valider le comportement de MirrorMaker 2 lors de scénarios de rebootstrap, c'est-à-dire la capacité à reprendre la réplication après une interruption majeure ou un changement de configuration entre NEMO et Applicatif.

---

## Pré-requis

- [ ] Tests de réplication de base validés
- [ ] Tests de résilience exécutés
- [ ] Snapshots de configuration disponibles
- [ ] Procédure de backup des offsets

---

## Contexte Transactis

| Élément | Valeur |
|---------|--------|
| Mode MM2 actuel | Standalone (⚠️ SPOF identifié J1) |
| Workers MM2 | 2 (objectif: 3) |
| RTO cible | ≤ 5 minutes |
| RPO cible | ≤ 60 secondes |

**Constat J1 :** MM2 en mode standalone représente un SPOF. Migration vers Connect distribué requise pour production.

---

## 1. Scénarios de Rebootstrap

### 1.1 Vue d'Ensemble

| ID | Scénario | Déclencheur | Impact | Priorité |
|----|----------|-------------|--------|----------|
| BOOT-01 | Restart MM2 complet | Maintenance planifiée | Reprise depuis dernier offset | Haute |
| BOOT-02 | Reset des offsets | Demande métier | Rejeu depuis début/date | Haute |
| BOOT-03 | Ajout de topics | Nouveau pattern | Réplication nouveaux topics | Moyenne |
| BOOT-04 | Changement de cluster | Migration | Nouvelle cible | Basse |
| BOOT-05 | Récupération après perte | Incident majeur | Reconstruction | Haute |

---

## 2. Test BOOT-01 : Restart Complet de MirrorMaker 2

### 2.1 Objectif

Valider que MM2 reprend correctement la réplication après un arrêt/redémarrage complet.

### 2.2 Procédure

```bash
#!/bin/bash
# test-rebootstrap-restart.sh

echo "=== Test BOOT-01: Restart complet MM2 ==="

# 1. Capturer l'état avant restart
echo "1. Capture état initial..."

# Offsets des connecteurs
curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status \
    > /tmp/mm2-status-before.json

# Lag actuel
LAG_BEFORE=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
    | jq -r '.data.result[0].value[1] // 0')
echo "Lag avant: $LAG_BEFORE"

# Offsets du topic de test
$KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${SRC_BOOTSTRAP_SERVERS} \
    --topic test-mm2-perf \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} > /tmp/offsets-before.txt

echo "Offsets source avant:"
cat /tmp/offsets-before.txt

# 2. Démarrer une charge continue
echo ""
echo "2. Démarrage charge continue..."
$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic test-mm2-perf \
    --num-records 100000 \
    --record-size 100 \
    --throughput 500 \
    --producer.config ${CLIENT_PROPERTIES_PATH} 2>&1 > /tmp/producer.log &
PROD_PID=$!
echo "Producer PID: $PROD_PID"

sleep 10  # Laisser quelques messages passer

# 3. Arrêter tous les workers MM2
echo ""
echo "3. Arrêt de tous les workers MM2..."
for worker in ${MM2_WORKER_1_HOST} ${MM2_WORKER_2_HOST} ${MM2_WORKER_3_HOST}; do
    echo "  Arrêt $worker..."
    ssh ${SSH_USER}@$worker "sudo systemctl stop ${MM2_SERVICE_NAME}"
done

# Capturer le moment d'arrêt
STOP_TIME=$(date +%s)
echo "MM2 arrêté à $(date)"

# 4. Attendre (accumulation de lag)
echo ""
echo "4. Attente 60 secondes (accumulation lag)..."
sleep 60

# Capturer le lag pendant l'arrêt
MESSAGES_DURING_STOP=$((500 * 60))  # ~30000 messages
echo "Messages produits pendant l'arrêt: ~$MESSAGES_DURING_STOP"

# 5. Redémarrer MM2
echo ""
echo "5. Redémarrage MM2..."
for worker in ${MM2_WORKER_1_HOST} ${MM2_WORKER_2_HOST} ${MM2_WORKER_3_HOST}; do
    echo "  Démarrage $worker..."
    ssh ${SSH_USER}@$worker "sudo systemctl start ${MM2_SERVICE_NAME}"
done

START_TIME=$(date +%s)
echo "MM2 redémarré à $(date)"

# 6. Attendre la stabilisation
echo ""
echo "6. Attente stabilisation (connecteurs RUNNING)..."
MAX_WAIT=120
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    STATE=$(curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status 2>/dev/null | jq -r '.connector.state // "UNKNOWN"')
    TASKS_RUNNING=$(curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status 2>/dev/null | jq '[.tasks[] | select(.state=="RUNNING")] | length')

    echo "  T+${WAITED}s: Connector=$STATE, Tasks RUNNING=$TASKS_RUNNING"

    if [ "$STATE" = "RUNNING" ] && [ "$TASKS_RUNNING" -gt 0 ]; then
        break
    fi

    sleep 5
    WAITED=$((WAITED + 5))
done

RECOVERY_TIME=$(($(date +%s) - START_TIME))
echo "Temps de récupération: $RECOVERY_TIME secondes"

# 7. Observer le rattrapage du lag
echo ""
echo "7. Observation du rattrapage..."
for i in $(seq 1 24); do  # 2 minutes max
    LAG=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // 0' | cut -d. -f1)
    echo "  T+$((i*5))s: Lag = $LAG"

    if [ "$LAG" -lt 100 ]; then
        CATCHUP_TIME=$((i * 5))
        break
    fi
    sleep 5
done

# 8. Arrêter le producer
kill $PROD_PID 2>/dev/null

# 9. Validation finale
echo ""
echo "=== Résultats BOOT-01 ==="
echo "Temps d'arrêt MM2: 60 secondes"
echo "Temps de récupération: $RECOVERY_TIME secondes"
echo "Temps de rattrapage: $CATCHUP_TIME secondes"
echo "Lag initial après arrêt: ~$MESSAGES_DURING_STOP messages"
echo "Lag final: $LAG messages"

if [ $LAG -lt 100 ] && [ $RECOVERY_TIME -lt 60 ]; then
    echo ""
    echo "✅ TEST RÉUSSI - MM2 a repris correctement après restart"
else
    echo ""
    echo "❌ TEST ÉCHOUÉ - Problème de reprise"
fi
```

---

## 3. Test BOOT-02 : Reset des Offsets

### 3.1 Objectif

Valider la capacité à resetter les offsets pour rejouer les messages depuis un point spécifique.

### 3.2 Procédure

```bash
#!/bin/bash
# test-rebootstrap-reset.sh

echo "=== Test BOOT-02: Reset des offsets ==="

TOPIC="test-mm2-reset"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.$TOPIC"

# 1. Préparer le topic avec des messages datés
echo "1. Préparation du topic avec messages..."
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC \
    --partitions 3 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# Produire 3 batches avec timestamps
echo "  Batch 1..."
for i in $(seq 1 100); do echo "batch1-msg-$i"; done | \
    $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC 2>/dev/null

TIMESTAMP_1=$(date +%s%3N)
sleep 30

echo "  Batch 2..."
for i in $(seq 1 100); do echo "batch2-msg-$i"; done | \
    $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC 2>/dev/null

TIMESTAMP_2=$(date +%s%3N)
sleep 30

echo "  Batch 3..."
for i in $(seq 1 100); do echo "batch3-msg-$i"; done | \
    $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC 2>/dev/null

echo "  Timestamps: T1=$TIMESTAMP_1, T2=$TIMESTAMP_2"

# 2. Attendre la réplication initiale
echo ""
echo "2. Attente réplication initiale..."
sleep 60

# Capturer l'offset actuel sur cible
OFFSET_INITIAL=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${TGT_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_TARGET \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} | awk -F: '{sum+=$3} END {print sum}')
echo "Offset cible initial: $OFFSET_INITIAL"

# 3. Simuler un reset - Supprimer le topic cible et recréer
echo ""
echo "3. Reset du topic cible..."

# Option A: Supprimer et laisser MM2 recréer
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --delete --topic $TOPIC_TARGET 2>/dev/null

echo "Topic cible supprimé"

# 4. Redémarrer le connecteur pour forcer le refresh
echo ""
echo "4. Restart du connecteur MM2..."
curl -X POST "http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/restart"

# 5. Attendre la re-réplication
echo ""
echo "5. Attente re-réplication..."
sleep 120

# 6. Vérifier que tous les messages sont re-répliqués
OFFSET_AFTER=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${TGT_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_TARGET \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} | awk -F: '{sum+=$3} END {print sum}')
echo "Offset cible après reset: $OFFSET_AFTER"

# 7. Vérifier le contenu
echo ""
echo "7. Vérification du contenu..."
COUNT_BATCH1=$($KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --timeout-ms 30000 2>/dev/null | grep "batch1" | wc -l)

COUNT_BATCH2=$($KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --timeout-ms 30000 2>/dev/null | grep "batch2" | wc -l)

COUNT_BATCH3=$($KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --timeout-ms 30000 2>/dev/null | grep "batch3" | wc -l)

echo ""
echo "=== Résultats BOOT-02 ==="
echo "Messages batch1: $COUNT_BATCH1 (attendu: 100)"
echo "Messages batch2: $COUNT_BATCH2 (attendu: 100)"
echo "Messages batch3: $COUNT_BATCH3 (attendu: 100)"
echo "Total: $OFFSET_AFTER (attendu: 300)"

if [ "$OFFSET_AFTER" -eq 300 ]; then
    echo ""
    echo "✅ TEST RÉUSSI - Tous les messages ont été re-répliqués"
else
    echo ""
    echo "❌ TEST ÉCHOUÉ - Messages manquants après reset"
fi
```

---

## 4. Test BOOT-03 : Ajout Dynamique de Topics

### 4.1 Objectif

Valider que MM2 détecte et réplique automatiquement les nouveaux topics correspondant au pattern.

### 4.2 Procédure

```bash
#!/bin/bash
# test-rebootstrap-new-topics.sh

echo "=== Test BOOT-03: Ajout dynamique de topics ==="

TOPIC_PREFIX="test-mm2-dynamic"
NUM_NEW_TOPICS=3

# 1. Vérifier la configuration du pattern
echo "1. Vérification du pattern de topics..."
TOPICS_PATTERN=$(curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/config | jq -r '.topics // ".*"')
echo "Pattern configuré: $TOPICS_PATTERN"

REFRESH_INTERVAL=$(curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/config | jq -r '.["refresh.topics.interval.seconds"] // "600"')
echo "Intervalle de refresh: $REFRESH_INTERVAL secondes"

# 2. Créer de nouveaux topics
echo ""
echo "2. Création de $NUM_NEW_TOPICS nouveaux topics..."

for i in $(seq 1 $NUM_NEW_TOPICS); do
    TOPIC="${TOPIC_PREFIX}-$(date +%s)-$i"
    echo "  Création: $TOPIC"

    $KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --create \
        --topic $TOPIC \
        --partitions 2 \
        --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

    # Produire quelques messages
    for j in $(seq 1 10); do
        echo "message-$j"
    done | $KAFKA_HOME/bin/kafka-console-producer.sh \
        --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
        --producer.config ${CLIENT_PROPERTIES_PATH} \
        --topic $TOPIC 2>/dev/null

    NEW_TOPICS+=($TOPIC)
done

echo "Topics créés: ${NEW_TOPICS[@]}"

# 3. Attendre le refresh (ou forcer)
echo ""
echo "3. Attente du refresh des topics..."
echo "   (Intervalle configuré: $REFRESH_INTERVAL secondes)"

# Attendre max 2× l'intervalle de refresh
MAX_WAIT=$((REFRESH_INTERVAL * 2))
if [ $MAX_WAIT -gt 300 ]; then
    MAX_WAIT=300  # Cap à 5 minutes pour le test
fi

WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    echo "  T+${WAITED}s: Vérification..."

    ALL_FOUND=true
    for topic in "${NEW_TOPICS[@]}"; do
        TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.$topic"
        EXISTS=$($KAFKA_HOME/bin/kafka-topics.sh \
            --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
            --command-config ${CLIENT_PROPERTIES_PATH} \
            --list 2>/dev/null | grep "^$TOPIC_TARGET$")

        if [ -z "$EXISTS" ]; then
            ALL_FOUND=false
        fi
    done

    if $ALL_FOUND; then
        echo "  Tous les topics répliqués!"
        break
    fi

    sleep 30
    WAITED=$((WAITED + 30))
done

# 4. Vérification finale
echo ""
echo "=== Vérification des topics répliqués ==="

SUCCESS=0
FAILED=0

for topic in "${NEW_TOPICS[@]}"; do
    TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.$topic"

    EXISTS=$($KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --list 2>/dev/null | grep "^$TOPIC_TARGET$")

    if [ -n "$EXISTS" ]; then
        # Vérifier les messages
        COUNT=$($KAFKA_HOME/bin/kafka-console-consumer.sh \
            --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
            --consumer.config ${CLIENT_PROPERTIES_PATH} \
            --topic $TOPIC_TARGET \
            --from-beginning \
            --timeout-ms 10000 2>/dev/null | wc -l)

        if [ "$COUNT" -eq 10 ]; then
            echo "✅ $topic → $TOPIC_TARGET: $COUNT messages"
            ((SUCCESS++))
        else
            echo "⚠️ $topic → $TOPIC_TARGET: $COUNT/10 messages"
            ((FAILED++))
        fi
    else
        echo "❌ $topic: Non répliqué"
        ((FAILED++))
    fi
done

echo ""
echo "=== Résultats BOOT-03 ==="
echo "Topics réussis: $SUCCESS"
echo "Topics échoués: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "✅ TEST RÉUSSI - Tous les nouveaux topics ont été répliqués"
else
    echo ""
    echo "❌ TEST ÉCHOUÉ - Certains topics n'ont pas été répliqués"
fi

# Nettoyage optionnel
echo ""
read -p "Supprimer les topics de test? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for topic in "${NEW_TOPICS[@]}"; do
        $KAFKA_HOME/bin/kafka-topics.sh \
            --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
            --command-config ${CLIENT_PROPERTIES_PATH} \
            --delete --topic $topic 2>/dev/null
    done
    echo "Topics supprimés"
fi
```

---

## 5. Test BOOT-05 : Récupération Après Perte

### 5.1 Objectif

Valider la procédure de récupération après une perte majeure (perte du cluster cible, corruption, etc.).

### 5.2 Procédure

```bash
#!/bin/bash
# test-rebootstrap-recovery.sh

echo "=== Test BOOT-05: Récupération après perte ==="
echo "⚠️  Ce test simule une perte majeure. À exécuter avec précaution."

TOPIC="test-mm2-recovery"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.$TOPIC"

# 1. Préparer un topic avec des données
echo "1. Préparation du topic avec données..."
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC \
    --partitions 5 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic $TOPIC \
    --num-records 10000 \
    --record-size 100 \
    --throughput -1 \
    --producer.config ${CLIENT_PROPERTIES_PATH} 2>&1 | tail -1

# Attendre la réplication
echo "Attente réplication initiale..."
sleep 60

# Capturer les métriques avant
OFFSET_SOURCE=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${SRC_BOOTSTRAP_SERVERS} \
    --topic $TOPIC \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} | awk -F: '{sum+=$3} END {print sum}')

OFFSET_TARGET_BEFORE=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${TGT_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_TARGET \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} | awk -F: '{sum+=$3} END {print sum}')

echo "Offset source: $OFFSET_SOURCE"
echo "Offset cible avant simulation: $OFFSET_TARGET_BEFORE"

# 2. Simuler la perte (supprimer topic cible + reset offsets MM2)
echo ""
echo "2. Simulation de perte..."

# Arrêter MM2
for worker in ${MM2_WORKER_1_HOST} ${MM2_WORKER_2_HOST} ${MM2_WORKER_3_HOST}; do
    ssh ${SSH_USER}@$worker "sudo systemctl stop ${MM2_SERVICE_NAME}"
done
echo "MM2 arrêté"

# Supprimer le topic cible
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --delete --topic $TOPIC_TARGET 2>/dev/null
echo "Topic cible supprimé"

# Supprimer les offsets du consumer MM2
$KAFKA_HOME/bin/kafka-consumer-groups.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --delete --group "mirrormaker2-*" 2>/dev/null
echo "Consumer groups MM2 supprimés"

# 3. Procédure de récupération
echo ""
echo "3. Procédure de récupération..."

# Redémarrer MM2
for worker in ${MM2_WORKER_1_HOST} ${MM2_WORKER_2_HOST} ${MM2_WORKER_3_HOST}; do
    ssh ${SSH_USER}@$worker "sudo systemctl start ${MM2_SERVICE_NAME}"
done
echo "MM2 redémarré"

# 4. Attendre la re-réplication complète
echo ""
echo "4. Attente re-réplication complète..."
MAX_WAIT=600  # 10 minutes max
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    # Vérifier si le topic existe sur cible
    EXISTS=$($KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --list 2>/dev/null | grep "^$TOPIC_TARGET$")

    if [ -n "$EXISTS" ]; then
        OFFSET_TARGET=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
            --broker-list ${TGT_BOOTSTRAP_SERVERS} \
            --topic $TOPIC_TARGET \
            --time -1 \
            --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null | awk -F: '{sum+=$3} END {print sum}')

        PERCENT=$((OFFSET_TARGET * 100 / OFFSET_SOURCE))
        echo "  T+${WAITED}s: Répliqué $OFFSET_TARGET/$OFFSET_SOURCE ($PERCENT%)"

        if [ "$OFFSET_TARGET" -ge "$OFFSET_SOURCE" ]; then
            echo "  Réplication complète!"
            break
        fi
    else
        echo "  T+${WAITED}s: Topic cible pas encore créé..."
    fi

    sleep 30
    WAITED=$((WAITED + 30))
done

RECOVERY_TIME=$WAITED

# 5. Validation finale
echo ""
echo "=== Résultats BOOT-05 ==="
echo "Messages sur source: $OFFSET_SOURCE"
echo "Messages récupérés: $OFFSET_TARGET"
echo "Temps de récupération: $RECOVERY_TIME secondes"

if [ "$OFFSET_TARGET" -ge "$OFFSET_SOURCE" ]; then
    echo ""
    echo "✅ TEST RÉUSSI - Récupération complète après perte"
else
    LOST=$((OFFSET_SOURCE - OFFSET_TARGET))
    echo ""
    echo "❌ TEST ÉCHOUÉ - $LOST messages non récupérés"
fi
```

---

## 6. Tableau Récapitulatif

| ID | Test | Description | Résultat | Temps de Récupération |
|----|------|-------------|----------|----------------------|
| BOOT-01 | Restart complet | Arrêt/redémarrage MM2 | ⬜ | - sec |
| BOOT-02 | Reset offsets | Rejouer depuis début | ⬜ | - sec |
| BOOT-03 | Ajout topics | Nouveaux topics auto | ⬜ | - sec |
| BOOT-04 | Changement cluster | Migration cible | ⬜ | N/A |
| BOOT-05 | Récupération perte | Reconstruction complète | ⬜ | - sec |

**Légende:** ✅ Pass | ⚠️ Partiel | ❌ Fail | ⬜ Non testé

---

## 7. Critères d'Acceptation

| Critère | Obligatoire | Résultat |
|---------|-------------|----------|
| Reprise après restart < 2 min | OUI | ⬜ |
| 0 message perdu après restart | OUI | ⬜ |
| Détection nouveaux topics | NON | ⬜ |
| Récupération après perte | OUI | ⬜ |

---

## Artifacts Produits

- [ ] Logs des tests de rebootstrap
- [ ] Métriques de temps de récupération
- [ ] Rapport de validation

---

**Client** : Transactis
**RTO** : ≤ 5 minutes
**RPO** : ≤ 60 secondes
**Version** : 2.0
