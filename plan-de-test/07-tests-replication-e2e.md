# Section 7 : Tests de Réplication Bout-en-Bout

**Objectif** : Valider l'intégrité de la réplication MM2 de bout en bout  
**Durée estimée** : 3 heures  
**Prérequis** : MM2 opérationnel, clusters source et target accessibles  
**SLA cible** : RPO < 1 minute, intégrité 100%

---

## 7.1 Objectifs de cette Section

| Objectif | Description | SLA |
|----------|-------------|-----|
| Intégrité données | 100% des messages répliqués sans corruption | 100% |
| Lag réplication | Délai maximal entre source et target | < 60 s |
| Ordre préservé | Ordre des messages par partition maintenu | 100% |
| Offsets synchronisés | Consumer groups peuvent basculer | RPO < 1 min |

---

## 7.2 Test 7.1 - Intégrité des Données

### Objectif

Vérifier que 100% des messages sont répliqués sans corruption.

### Méthodologie

1. Produire N messages avec contenu vérifiable (hash MD5)
2. Consommer sur le cluster source
3. Consommer sur le cluster target (via MM2)
4. Comparer les contenus

### Script de Test

```bash
#!/bin/bash
# Configuration
SOURCE_TOPIC="e2e-integrity-test"
TARGET_TOPIC="source.e2e-integrity-test"  # Préfixe MM2
NUM_MESSAGES=10000
MESSAGE_SIZE=1024

# Génération et production avec checksums
echo "=== Production de ${NUM_MESSAGES} messages ==="
for i in $(seq 1 ${NUM_MESSAGES}); do
  # Générer message avec ID et checksum
  PAYLOAD="MSG_${i}_$(date +%s%N)_$(head -c 900 /dev/urandom | base64 | head -c 900)"
  CHECKSUM=$(echo -n "${PAYLOAD}" | md5sum | awk '{print $1}')
  MESSAGE="${i}|${CHECKSUM}|${PAYLOAD}"
  
  echo "${MESSAGE}" | kafka-console-producer \
    --bootstrap-server ${SOURCE_BOOTSTRAP} \
    --topic ${SOURCE_TOPIC} \
    --producer.config producer-tls.properties
done

echo "=== Attente réplication (60s) ==="
sleep 60

echo "=== Consommation source ==="
kafka-console-consumer \
  --bootstrap-server ${SOURCE_BOOTSTRAP} \
  --topic ${SOURCE_TOPIC} \
  --from-beginning \
  --max-messages ${NUM_MESSAGES} \
  --consumer.config consumer-tls.properties > /tmp/source_messages.txt

echo "=== Consommation target ==="
kafka-console-consumer \
  --bootstrap-server ${TARGET_BOOTSTRAP} \
  --topic ${TARGET_TOPIC} \
  --from-beginning \
  --max-messages ${NUM_MESSAGES} \
  --consumer.config consumer-tls.properties > /tmp/target_messages.txt

echo "=== Comparaison ==="
diff /tmp/source_messages.txt /tmp/target_messages.txt
if [ $? -eq 0 ]; then
  echo "PASS: Tous les messages identiques"
else
  echo "FAIL: Différences détectées"
fi
```

### Grille de Résultats

| Métrique | Valeur | Attendu |
|----------|--------|---------|
| Messages produits | _____ | 10000 |
| Messages sur source | _____ | 10000 |
| Messages sur target | _____ | 10000 |
| Messages corrompus | _____ | 0 |
| Messages manquants | _____ | 0 |
| Messages dupliqués | _____ | 0 |

### Critères de Succès

- [ ] 100% des messages répliqués
- [ ] 0 corruption (checksums valides)
- [ ] 0 message manquant
- [ ] 0 duplication (exactly-once si activé)

---

## 7.3 Test 7.2 - Mesure du Lag de Réplication

### Objectif

Mesurer le délai entre production sur source et disponibilité sur target.

### Méthodologie

1. Produire des messages avec timestamp
2. Consommer immédiatement sur target
3. Calculer le delta temporel

### Script de Test

```bash
#!/bin/bash
# Configuration
SOURCE_TOPIC="e2e-lag-test"
TARGET_TOPIC="source.e2e-lag-test"

# Produire un message avec timestamp
TIMESTAMP=$(date +%s%3N)
echo "${TIMESTAMP}" | kafka-console-producer \
  --bootstrap-server ${SOURCE_BOOTSTRAP} \
  --topic ${SOURCE_TOPIC} \
  --producer.config producer-tls.properties

# Attendre et consommer sur target
sleep 1
START_POLL=$(date +%s%3N)
MESSAGE=$(kafka-console-consumer \
  --bootstrap-server ${TARGET_BOOTSTRAP} \
  --topic ${TARGET_TOPIC} \
  --max-messages 1 \
  --timeout-ms 60000 \
  --consumer.config consumer-tls.properties)
END_POLL=$(date +%s%3N)

# Calcul lag
ORIGINAL_TS=${MESSAGE}
LAG=$((END_POLL - ORIGINAL_TS))
echo "Lag réplication: ${LAG} ms"
```

### Test en Boucle (100 mesures)

```bash
#!/bin/bash
echo "timestamp_source,timestamp_target,lag_ms" > /tmp/lag_results.csv

for i in $(seq 1 100); do
  TS_SOURCE=$(date +%s%3N)
  echo "${TS_SOURCE}" | kafka-console-producer ... &
  
  sleep 2
  
  TS_TARGET=$(kafka-console-consumer ... --max-messages 1)
  LAG=$(($(date +%s%3N) - TS_SOURCE))
  
  echo "${TS_SOURCE},${TS_TARGET},${LAG}" >> /tmp/lag_results.csv
  sleep 1
done

# Statistiques
awk -F',' 'NR>1 {sum+=$3; if($3>max)max=$3; if(min==""||$3<min)min=$3} END {print "Avg:",sum/(NR-1),"ms, Min:",min,"ms, Max:",max,"ms"}' /tmp/lag_results.csv
```

### Grille de Résultats

| Métrique | Valeur | SLA |
|----------|--------|-----|
| Lag moyen | _____ ms | < 5000 ms |
| Lag P50 | _____ ms | < 3000 ms |
| Lag P95 | _____ ms | < 10000 ms |
| Lag P99 | _____ ms | < 30000 ms |
| Lag max | _____ ms | < 60000 ms |

### Critères de Succès

- [ ] Lag moyen < 5 secondes
- [ ] Lag P99 < 30 secondes
- [ ] Lag max < 60 secondes (RPO)

---

## 7.4 Test 7.3 - Préservation de l'Ordre

### Objectif

Vérifier que l'ordre des messages par partition est préservé.

### Méthodologie

1. Produire des messages séquentiels avec numéro d'ordre
2. Vérifier l'ordre sur le cluster target

### Script de Test

```bash
#!/bin/bash
SOURCE_TOPIC="e2e-order-test"
TARGET_TOPIC="source.e2e-order-test"
NUM_MESSAGES=1000

# Production séquentielle
for i in $(seq 1 ${NUM_MESSAGES}); do
  echo "SEQ_${i}" | kafka-console-producer \
    --bootstrap-server ${SOURCE_BOOTSTRAP} \
    --topic ${SOURCE_TOPIC} \
    --producer.config producer-tls.properties
done

sleep 30

# Vérification ordre sur target
kafka-console-consumer \
  --bootstrap-server ${TARGET_BOOTSTRAP} \
  --topic ${TARGET_TOPIC} \
  --from-beginning \
  --max-messages ${NUM_MESSAGES} \
  --consumer.config consumer-tls.properties > /tmp/order_check.txt

# Vérification séquentielle
EXPECTED=1
while read line; do
  SEQ=$(echo $line | grep -oP 'SEQ_\K\d+')
  if [ "$SEQ" != "$EXPECTED" ]; then
    echo "ERREUR: Attendu SEQ_${EXPECTED}, reçu SEQ_${SEQ}"
    exit 1
  fi
  EXPECTED=$((EXPECTED + 1))
done < /tmp/order_check.txt

echo "PASS: Ordre préservé pour ${NUM_MESSAGES} messages"
```

### Grille de Résultats

| Test | Messages | Ordre Préservé | Erreurs |
|------|----------|----------------|---------|
| Partition unique | 1000 | ☐ Oui ☐ Non | _____ |
| Multi-partitions | 5000 | ☐ Par partition | _____ |

### Critères de Succès

- [ ] Ordre préservé au sein de chaque partition
- [ ] Aucune inversion de séquence

---

## 7.5 Test 7.4 - Synchronisation des Offsets Consumer

### Objectif

Valider que MirrorCheckpointConnector synchronise correctement les offsets.

### Méthodologie

1. Créer un consumer group sur le cluster source
2. Consommer des messages et committer les offsets
3. Vérifier la translation des offsets sur le cluster target
4. Simuler un failover et reprendre la consommation sur target

### Script de Test

```bash
#!/bin/bash
SOURCE_TOPIC="e2e-offset-test"
TARGET_TOPIC="source.e2e-offset-test"
GROUP_ID="test-consumer-group"

# Étape 1: Produire 1000 messages
for i in $(seq 1 1000); do
  echo "MSG_${i}" | kafka-console-producer ...
done

# Étape 2: Consommer 500 messages sur source (commit offsets)
kafka-console-consumer \
  --bootstrap-server ${SOURCE_BOOTSTRAP} \
  --topic ${SOURCE_TOPIC} \
  --group ${GROUP_ID} \
  --max-messages 500 \
  --consumer.config consumer-tls.properties

# Étape 3: Vérifier offset source
kafka-consumer-groups \
  --bootstrap-server ${SOURCE_BOOTSTRAP} \
  --describe --group ${GROUP_ID}

# Étape 4: Attendre sync MM2 (CheckpointConnector)
sleep 30

# Étape 5: Vérifier offset traduit sur target
kafka-consumer-groups \
  --bootstrap-server ${TARGET_BOOTSTRAP} \
  --describe --group ${GROUP_ID}

# Étape 6: Reprendre consommation sur target (doit commencer à 501)
kafka-console-consumer \
  --bootstrap-server ${TARGET_BOOTSTRAP} \
  --topic ${TARGET_TOPIC} \
  --group ${GROUP_ID} \
  --max-messages 100 \
  --consumer.config consumer-tls.properties
```

### Grille de Résultats

| Métrique | Source | Target |
|----------|--------|--------|
| Offset consommé | 500 | _____ |
| Offset traduit | N/A | _____ |
| Premier message après failover | N/A | MSG_501 ? |
| Messages rejoués | N/A | _____ |
| Messages manqués | N/A | _____ |

### Critères de Succès

- [ ] Offset correctement traduit
- [ ] Reprise sans perte de message
- [ ] Reprise avec minimum de replay (< 100 messages)

---

## 7.6 Test 7.5 - Réplication sous Charge

### Objectif

Valider le comportement de la réplication sous charge de production soutenue.

### Configuration

```bash
# Charge soutenue: 5000 msg/s pendant 30 minutes
THROUGHPUT=5000
DURATION_MIN=30
NUM_RECORDS=$((THROUGHPUT * 60 * DURATION_MIN))  # 9M messages
```

### Script de Test

```bash
#!/bin/bash
SOURCE_TOPIC="e2e-load-test"
TARGET_TOPIC="source.e2e-load-test"

# Démarrer production
kafka-producer-perf-test \
  --topic ${SOURCE_TOPIC} \
  --num-records 9000000 \
  --record-size 1024 \
  --throughput 5000 \
  --producer.config producer-tls.properties &

PRODUCER_PID=$!

# Monitoring lag pendant le test
while kill -0 $PRODUCER_PID 2>/dev/null; do
  # Récupérer lag MM2
  LAG=$(curl -s http://connect:8083/connectors/mirror-source/status | jq '.tasks[0].trace // "N/A"')
  SOURCE_OFFSET=$(kafka-run-class kafka.tools.GetOffsetShell --broker-list ${SOURCE_BOOTSTRAP} --topic ${SOURCE_TOPIC} --time -1)
  TARGET_OFFSET=$(kafka-run-class kafka.tools.GetOffsetShell --broker-list ${TARGET_BOOTSTRAP} --topic ${TARGET_TOPIC} --time -1)
  
  echo "$(date): Source=${SOURCE_OFFSET}, Target=${TARGET_OFFSET}"
  sleep 10
done

wait $PRODUCER_PID
```

### Métriques à Collecter (toutes les 5 min)

| Temps | Source Offset | Target Offset | Lag (msgs) | Lag (s) |
|-------|---------------|---------------|------------|---------|
| T+5min | _____ | _____ | _____ | _____ |
| T+10min | _____ | _____ | _____ | _____ |
| T+15min | _____ | _____ | _____ | _____ |
| T+20min | _____ | _____ | _____ | _____ |
| T+25min | _____ | _____ | _____ | _____ |
| T+30min | _____ | _____ | _____ | _____ |

### Critères de Succès

- [ ] Lag stable (pas d'accumulation)
- [ ] Lag max < 60 secondes de données
- [ ] Aucune erreur de réplication
- [ ] 100% des messages répliqués en fin de test

---

## 7.7 Test 7.6 - Topics avec Différentes Configurations

### Objectif

Valider la réplication pour différentes configurations de topics.

### Topics de Test

| Topic | Partitions | RF | Retention | Compaction |
|-------|------------|----|-----------|-----------| 
| e2e-standard | 6 | 3 | 7 jours | Non |
| e2e-compact | 3 | 3 | Infini | Oui |
| e2e-high-part | 24 | 3 | 7 jours | Non |
| e2e-single-part | 1 | 3 | 7 jours | Non |

### Création des Topics

```bash
# Topic standard
kafka-topics --create --topic e2e-standard \
  --partitions 6 --replication-factor 3 \
  --config retention.ms=604800000

# Topic compacté
kafka-topics --create --topic e2e-compact \
  --partitions 3 --replication-factor 3 \
  --config cleanup.policy=compact

# Topic haute partition
kafka-topics --create --topic e2e-high-part \
  --partitions 24 --replication-factor 3

# Topic single partition (ordre strict)
kafka-topics --create --topic e2e-single-part \
  --partitions 1 --replication-factor 3
```

### Grille de Résultats

| Topic | Messages Produits | Messages Répliqués | Intégrité | Ordre |
|-------|-------------------|-------------------|-----------|-------|
| e2e-standard | 10000 | _____ | ☐ OK | ☐ OK |
| e2e-compact | 5000 | _____ | ☐ OK | ☐ OK |
| e2e-high-part | 50000 | _____ | ☐ OK | ☐ OK |
| e2e-single-part | 5000 | _____ | ☐ OK | ☐ OK |

---

## 7.8 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 7.1 - Intégrité données
- [ ] Test 7.2 - Lag réplication
- [ ] Test 7.3 - Préservation ordre
- [ ] Test 7.4 - Sync offsets
- [ ] Test 7.5 - Réplication sous charge
- [ ] Test 7.6 - Différentes configurations

### Résultat Global Section 7

| Critère | Statut |
|---------|--------|
| Intégrité 100% | ☐ PASS ☐ FAIL |
| RPO < 1 minute | ☐ PASS ☐ FAIL |
| Ordre préservé | ☐ PASS ☐ FAIL |
| Offsets synchronisés | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests de Failover Multi-AZ](06-tests-failover-az.md)  
**Section suivante** : [Tests d'Endurance](08-tests-endurance.md)
