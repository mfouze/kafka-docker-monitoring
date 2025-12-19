# Vérification de la Réplication - Validation Fonctionnelle MirrorMaker 2 Transactis

## Objectif

Valider que MirrorMaker 2 réplique correctement et complètement les données du cluster NEMO (source) vers le cluster Applicatif (cible).

---

## Pré-requis

- [x] MirrorMaker 2 opérationnel et en état RUNNING (validé J2)
- [ ] Topics de test créés sur le cluster NEMO
- [x] Accès aux deux clusters validé (cf. `01-prerequis/inventaire-acces.md`)

---

## Contexte Transactis

| Élément | Source (NEMO) | Cible (Applicatif) |
|---------|---------------|-------------------|
| Rôle | Échanges inter-applicatifs | Échanges intra-applicatifs |
| Brokers | 3 | 3 |
| Port sécurisé | 9093 | 9093 |
| Préfixe réplication | - | `nemo.` |

**Dashboard de validation :** `mm2-replication`, `mm2-detailed-metrics`

---

## 1. Tests de Réplication de Base

### 1.1 Test FUNC-REP-01 : Réplication Simple

**Objectif :** Vérifier qu'un message produit sur le source apparaît sur le cible.

```bash
#!/bin/bash
# test-replication-simple.sh

TOPIC_SOURCE="test-mm2-perf"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-perf"
TEST_MESSAGE="test-replication-$(date +%s)"

echo "=== Test de réplication simple ==="
echo "Message: $TEST_MESSAGE"

# 1. Produire sur source
echo "1. Production sur source..."
echo "$TEST_MESSAGE" | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE 2>/dev/null

echo "   Message produit sur $TOPIC_SOURCE"

# 2. Attendre la réplication
echo "2. Attente de la réplication (max 30s)..."
sleep 5

# 3. Consommer sur cible
echo "3. Consommation sur cible..."
RECEIVED=$(timeout 30 $KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --max-messages 100 \
    --timeout-ms 25000 2>/dev/null | grep "$TEST_MESSAGE")

# 4. Vérification
echo ""
if [ -n "$RECEIVED" ]; then
    echo "✅ TEST RÉUSSI - Message répliqué correctement"
    echo "   Reçu: $RECEIVED"
else
    echo "❌ TEST ÉCHOUÉ - Message non trouvé sur le cible"
fi
```

**Critères de succès :**

| Critère | OK | KO |
|---------|----|----|
| Message présent sur cible | ✅ | ❌ |
| Contenu identique | ✅ | ❌ |
| Délai < 30 sec | ✅ | ❌ |

### 1.2 Test FUNC-REP-02 : Réplication en Masse

**Objectif :** Vérifier la réplication de volumes importants de données.

```bash
#!/bin/bash
# test-replication-bulk.sh

TOPIC_SOURCE="test-mm2-bulk"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-bulk"
NUM_MESSAGES=10000
MESSAGE_SIZE=100

echo "=== Test de réplication en masse ==="
echo "Messages: $NUM_MESSAGES × $MESSAGE_SIZE bytes"

# 1. Créer le topic si nécessaire
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions 10 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# 2. Capturer l'offset initial sur cible
OFFSET_INITIAL=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list ${TGT_BOOTSTRAP_SERVERS} \
    --topic $TOPIC_TARGET \
    --time -1 \
    --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null | \
    awk -F: '{sum+=$3} END {print sum}')
OFFSET_INITIAL=${OFFSET_INITIAL:-0}
echo "Offset initial cible: $OFFSET_INITIAL"

# 3. Produire les messages
echo "Production de $NUM_MESSAGES messages..."
START_TIME=$(date +%s)

$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic $TOPIC_SOURCE \
    --num-records $NUM_MESSAGES \
    --record-size $MESSAGE_SIZE \
    --throughput -1 \
    --producer.config ${CLIENT_PROPERTIES_PATH} 2>&1 | tail -1

PROD_TIME=$(date +%s)
echo "Production terminée en $((PROD_TIME - START_TIME)) secondes"

# 4. Attendre la réplication
echo "Attente de la réplication..."
MAX_WAIT=300  # 5 minutes max
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    OFFSET_CURRENT=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
        --broker-list ${TGT_BOOTSTRAP_SERVERS} \
        --topic $TOPIC_TARGET \
        --time -1 \
        --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null | \
        awk -F: '{sum+=$3} END {print sum}')

    REPLICATED=$((OFFSET_CURRENT - OFFSET_INITIAL))
    PERCENT=$((REPLICATED * 100 / NUM_MESSAGES))

    echo "  Répliqués: $REPLICATED / $NUM_MESSAGES ($PERCENT%)"

    if [ $REPLICATED -ge $NUM_MESSAGES ]; then
        break
    fi

    sleep 5
    WAITED=$((WAITED + 5))
done

END_TIME=$(date +%s)
REPL_TIME=$((END_TIME - PROD_TIME))

# 5. Résultat
echo ""
echo "=== Résultats ==="
echo "Messages produits:   $NUM_MESSAGES"
echo "Messages répliqués:  $REPLICATED"
echo "Temps de production: $((PROD_TIME - START_TIME)) sec"
echo "Temps de réplication: $REPL_TIME sec"
echo "Throughput réplication: $((REPLICATED / (REPL_TIME + 1))) msg/sec"

if [ $REPLICATED -ge $NUM_MESSAGES ]; then
    echo ""
    echo "✅ TEST RÉUSSI - Tous les messages ont été répliqués"
else
    echo ""
    echo "❌ TEST ÉCHOUÉ - $((NUM_MESSAGES - REPLICATED)) messages manquants"
fi
```

### 1.3 Test FUNC-REP-03 : Réplication Multi-Partitions

**Objectif :** Vérifier que la réplication fonctionne sur toutes les partitions.

```bash
#!/bin/bash
# test-replication-partitions.sh

TOPIC_SOURCE="test-mm2-partitions"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-partitions"
NUM_PARTITIONS=10
MESSAGES_PER_PARTITION=100

echo "=== Test de réplication multi-partitions ==="
echo "Partitions: $NUM_PARTITIONS"
echo "Messages par partition: $MESSAGES_PER_PARTITION"

# 1. Créer le topic
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions $NUM_PARTITIONS \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# 2. Produire sur chaque partition
echo "Production sur chaque partition..."
for partition in $(seq 0 $((NUM_PARTITIONS - 1))); do
    for i in $(seq 1 $MESSAGES_PER_PARTITION); do
        echo "partition-$partition-message-$i"
    done | $KAFKA_HOME/bin/kafka-console-producer.sh \
        --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
        --producer.config ${CLIENT_PROPERTIES_PATH} \
        --topic $TOPIC_SOURCE \
        --property "parse.key=false" 2>/dev/null &
done
wait
echo "Production terminée"

# 3. Attendre la réplication
echo "Attente de la réplication..."
sleep 30

# 4. Vérifier les offsets par partition
echo ""
echo "=== Offsets par partition ==="
echo "Partition | Source | Cible | Différence"
echo "----------|--------|-------|----------"

TOTAL_DIFF=0
for partition in $(seq 0 $((NUM_PARTITIONS - 1))); do
    SRC_OFFSET=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
        --broker-list ${SRC_BOOTSTRAP_SERVERS} \
        --topic $TOPIC_SOURCE \
        --partitions $partition \
        --time -1 \
        --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null | cut -d: -f3)

    TGT_OFFSET=$($KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
        --broker-list ${TGT_BOOTSTRAP_SERVERS} \
        --topic $TOPIC_TARGET \
        --partitions $partition \
        --time -1 \
        --command-config ${CLIENT_PROPERTIES_PATH} 2>/dev/null | cut -d: -f3)

    DIFF=$((SRC_OFFSET - TGT_OFFSET))
    TOTAL_DIFF=$((TOTAL_DIFF + DIFF))

    printf "    %2d    | %6d | %5d | %5d\n" $partition $SRC_OFFSET $TGT_OFFSET $DIFF
done

echo ""
if [ $TOTAL_DIFF -eq 0 ]; then
    echo "✅ TEST RÉUSSI - Toutes les partitions sont synchronisées"
else
    echo "❌ TEST ÉCHOUÉ - Différence totale: $TOTAL_DIFF messages"
fi
```

---

## 2. Tests d'Intégrité des Données

### 2.1 Test FUNC-INT-01 : Vérification par Checksum

**Objectif :** Vérifier que les données sont identiques entre source et cible.

```bash
#!/bin/bash
# test-integrity-checksum.sh

TOPIC_SOURCE="test-mm2-integrity"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-integrity"
NUM_MESSAGES=1000

echo "=== Test d'intégrité par checksum ==="

# 1. Créer et peupler le topic
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions 1 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# Générer des messages avec contenu vérifiable
echo "Génération de $NUM_MESSAGES messages..."
for i in $(seq 1 $NUM_MESSAGES); do
    echo "integrity-test|$i|$(date +%s%N)|$(echo -n "payload-$i" | md5sum | cut -d' ' -f1)"
done | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE 2>/dev/null

echo "Attente de la réplication..."
sleep 30

# 2. Consommer et calculer checksum source
echo "Calcul checksum source..."
SOURCE_CHECKSUM=$($KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null | sort | md5sum | cut -d' ' -f1)

echo "Checksum source: $SOURCE_CHECKSUM"

# 3. Consommer et calculer checksum cible
echo "Calcul checksum cible..."
TARGET_CHECKSUM=$($KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null | sort | md5sum | cut -d' ' -f1)

echo "Checksum cible:  $TARGET_CHECKSUM"

# 4. Comparaison
echo ""
if [ "$SOURCE_CHECKSUM" = "$TARGET_CHECKSUM" ]; then
    echo "✅ TEST RÉUSSI - Checksums identiques"
    echo "   Les données sont parfaitement répliquées"
else
    echo "❌ TEST ÉCHOUÉ - Checksums différents"
    echo "   Il y a une différence dans les données répliquées"
fi
```

### 2.2 Test FUNC-INT-02 : Vérification Message par Message

**Objectif :** Comparer individuellement les messages source et cible.

```bash
#!/bin/bash
# test-integrity-messages.sh

TOPIC_SOURCE="test-mm2-verify"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-verify"
NUM_MESSAGES=100

echo "=== Test de vérification message par message ==="

# 1. Créer le topic et produire
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions 1 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# Messages avec identifiant unique
for i in $(seq 1 $NUM_MESSAGES); do
    echo "MSG-$i|$(uuidgen)|$(date -Iseconds)"
done > /tmp/source-messages.txt

cat /tmp/source-messages.txt | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE 2>/dev/null

echo "Attente de la réplication..."
sleep 30

# 2. Consommer des deux côtés
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null | sort > /tmp/consumed-source.txt

$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --consumer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_TARGET \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null | sort > /tmp/consumed-target.txt

# 3. Comparaison
echo ""
echo "=== Comparaison ==="
echo "Messages source: $(wc -l < /tmp/consumed-source.txt)"
echo "Messages cible:  $(wc -l < /tmp/consumed-target.txt)"

DIFF_OUTPUT=$(diff /tmp/consumed-source.txt /tmp/consumed-target.txt)

if [ -z "$DIFF_OUTPUT" ]; then
    echo ""
    echo "✅ TEST RÉUSSI - Tous les messages sont identiques"
else
    echo ""
    echo "❌ TEST ÉCHOUÉ - Différences détectées:"
    echo "$DIFF_OUTPUT" | head -20

    # Identifier les messages manquants
    MISSING=$(comm -23 /tmp/consumed-source.txt /tmp/consumed-target.txt | wc -l)
    EXTRA=$(comm -13 /tmp/consumed-source.txt /tmp/consumed-target.txt | wc -l)

    echo ""
    echo "Messages manquants sur cible: $MISSING"
    echo "Messages en trop sur cible:   $EXTRA"
fi

# Nettoyage
rm -f /tmp/source-messages.txt /tmp/consumed-*.txt
```

---

## 3. Tests de Configuration des Topics

### 3.1 Test FUNC-CFG-01 : Synchronisation des Configurations

**Objectif :** Vérifier que les configurations de topics sont répliquées.

```bash
#!/bin/bash
# test-topic-config-sync.sh

TOPIC_SOURCE="test-mm2-config"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.test-mm2-config"

echo "=== Test de synchronisation des configurations ==="

# 1. Créer un topic avec configuration spécifique
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create --if-not-exists \
    --topic $TOPIC_SOURCE \
    --partitions 5 \
    --replication-factor ${REPLICATION_FACTOR} \
    --config retention.ms=86400000 \
    --config cleanup.policy=delete \
    --config max.message.bytes=1048576 \
    --config min.insync.replicas=2 2>/dev/null

echo "Topic source créé avec configuration personnalisée"

# Produire un message pour déclencher la création sur cible
echo "trigger" | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_SOURCE 2>/dev/null

echo "Attente de la synchronisation..."
sleep 30

# 2. Récupérer la configuration source
echo ""
echo "=== Configuration Source ==="
SRC_CONFIG=$($KAFKA_HOME/bin/kafka-configs.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --entity-type topics \
    --entity-name $TOPIC_SOURCE \
    --describe 2>/dev/null)
echo "$SRC_CONFIG"

# 3. Récupérer la configuration cible
echo ""
echo "=== Configuration Cible ==="
TGT_CONFIG=$($KAFKA_HOME/bin/kafka-configs.sh \
    --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --entity-type topics \
    --entity-name $TOPIC_TARGET \
    --describe 2>/dev/null)
echo "$TGT_CONFIG"

# 4. Comparer les configurations clés
echo ""
echo "=== Comparaison des configurations ==="

check_config() {
    local config_name=$1
    local src_value=$(echo "$SRC_CONFIG" | grep "$config_name" | cut -d= -f2)
    local tgt_value=$(echo "$TGT_CONFIG" | grep "$config_name" | cut -d= -f2)

    if [ "$src_value" = "$tgt_value" ]; then
        echo "✅ $config_name: $src_value (identique)"
    else
        echo "❌ $config_name: Source=$src_value, Cible=$tgt_value"
    fi
}

check_config "retention.ms"
check_config "cleanup.policy"
check_config "max.message.bytes"

# Note: min.insync.replicas peut être différent si le cluster cible a moins de réplicas
```

### 3.2 Test FUNC-CFG-02 : Réplication du Nombre de Partitions

**Objectif :** Vérifier que le nombre de partitions est conservé.

```bash
#!/bin/bash
# test-partition-count.sh

TOPICS=("test-mm2-perf" "test-mm2-latency" "test-mm2-resilience")

echo "=== Vérification du nombre de partitions ==="
echo ""
echo "Topic | Partitions Source | Partitions Cible | Identique"
echo "------|-------------------|------------------|----------"

ALL_OK=true

for topic in "${TOPICS[@]}"; do
    TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.$topic"

    SRC_PARTITIONS=$($KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --describe --topic $topic 2>/dev/null | grep "PartitionCount" | awk '{print $2}')

    TGT_PARTITIONS=$($KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --describe --topic $TOPIC_TARGET 2>/dev/null | grep "PartitionCount" | awk '{print $2}')

    if [ "$SRC_PARTITIONS" = "$TGT_PARTITIONS" ]; then
        STATUS="✅ Oui"
    else
        STATUS="❌ Non"
        ALL_OK=false
    fi

    printf "%-30s | %17s | %16s | %s\n" "$topic" "$SRC_PARTITIONS" "$TGT_PARTITIONS" "$STATUS"
done

echo ""
if $ALL_OK; then
    echo "✅ TEST RÉUSSI - Toutes les partitions sont correctement répliquées"
else
    echo "❌ TEST ÉCHOUÉ - Certains topics ont un nombre de partitions différent"
fi
```

---

## 4. Tests de Création Automatique de Topics

### 4.1 Test FUNC-AUTO-01 : Création Automatique sur Source

**Objectif :** Vérifier qu'un nouveau topic sur source est automatiquement créé sur cible.

```bash
#!/bin/bash
# test-auto-topic-creation.sh

TOPIC_NEW="test-mm2-new-$(date +%s)"
TOPIC_TARGET="${SOURCE_CLUSTER_ALIAS}.$TOPIC_NEW"

echo "=== Test de création automatique de topic ==="
echo "Nouveau topic: $TOPIC_NEW"

# 1. Vérifier que le topic n'existe pas
echo "1. Vérification que le topic n'existe pas..."
EXISTS=$($KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --list 2>/dev/null | grep "^$TOPIC_NEW$")

if [ -n "$EXISTS" ]; then
    echo "   Topic existe déjà, nettoyage..."
    $KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --delete --topic $TOPIC_NEW 2>/dev/null
    sleep 5
fi

# 2. Créer le topic sur source
echo "2. Création du topic sur source..."
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --create \
    --topic $TOPIC_NEW \
    --partitions 3 \
    --replication-factor ${REPLICATION_FACTOR} 2>/dev/null

# 3. Produire un message pour déclencher la réplication
echo "3. Production d'un message de test..."
echo "test-auto-creation" | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config ${CLIENT_PROPERTIES_PATH} \
    --topic $TOPIC_NEW 2>/dev/null

# 4. Attendre et vérifier sur cible
echo "4. Attente de la création sur cible (max 60s)..."
MAX_WAIT=60
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    TARGET_EXISTS=$($KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --list 2>/dev/null | grep "^$TOPIC_TARGET$")

    if [ -n "$TARGET_EXISTS" ]; then
        echo "   Topic créé sur cible après $WAITED secondes"
        break
    fi

    sleep 5
    WAITED=$((WAITED + 5))
    echo "   Attente... ($WAITED/$MAX_WAIT sec)"
done

# 5. Vérification
echo ""
if [ -n "$TARGET_EXISTS" ]; then
    echo "✅ TEST RÉUSSI - Le topic a été automatiquement créé sur le cible"

    # Vérifier les détails
    echo ""
    echo "Détails du topic cible:"
    $KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
        --command-config ${CLIENT_PROPERTIES_PATH} \
        --describe --topic $TOPIC_TARGET 2>/dev/null
else
    echo "❌ TEST ÉCHOUÉ - Le topic n'a pas été créé sur le cible"
fi

# Nettoyage
echo ""
echo "Nettoyage..."
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --delete --topic $TOPIC_NEW 2>/dev/null
```

---

## 5. Tableau Récapitulatif des Tests

| ID | Test | Description | Résultat | Observations |
|----|------|-------------|----------|--------------|
| FUNC-REP-01 | Réplication simple | Un message source → cible | ⬜ | - |
| FUNC-REP-02 | Réplication en masse | 10000+ messages | ⬜ | - |
| FUNC-REP-03 | Multi-partitions | Toutes partitions | ⬜ | - |
| FUNC-INT-01 | Checksum | Intégrité données | ⬜ | - |
| FUNC-INT-02 | Message par message | Comparaison détaillée | ⬜ | - |
| FUNC-CFG-01 | Config topics | Sync configurations | ⬜ | - |
| FUNC-CFG-02 | Nb partitions | Conservation partitions | ⬜ | - |
| FUNC-AUTO-01 | Création auto | Nouveau topic | ⬜ | - |

**Légende:** ✅ Pass | ⚠️ Partiel | ❌ Fail | ⬜ Non testé

---

## 6. Critères d'Acceptation

| Critère | Obligatoire | Résultat |
|---------|-------------|----------|
| 100% messages répliqués | OUI | ⬜ |
| Intégrité données (checksum) | OUI | ⬜ |
| Toutes partitions répliquées | OUI | ⬜ |
| Configurations synchronisées | NON | ⬜ |
| Création auto topics | NON | ⬜ |

---

## Artifacts Produits

- [ ] Logs des tests de réplication
- [ ] Fichiers de comparaison (checksums)
- [ ] Rapport de validation

---

**Client** : Transactis
**Clusters** : NEMO → Applicatif
**Version** : 2.0
