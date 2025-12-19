# Scénarios de Charge

## Vue d'Ensemble

| Scénario | Débit | Durée | Objectif |
|----------|-------|-------|----------|
| S1 - Faible | 100 msg/s | 10 min | Baseline |
| S2 - Nominal | 1000 msg/s | 30 min | Validation normale |
| S3 - Pic | 5000 msg/s | 15 min | Tenue aux pics |
| S4 - Burst | 10000 msg/s | 1 min | Absorption rafale |
| S5 - Long Run | 3500 msg/s | 24h | Stabilité |
| S6 - Taille variable | Variable | 10 min chaque | Impact payload |
| S7 - Partitions | Variable | 10 min chaque | Parallélisme |

---

## S1 : Faible Charge (Baseline)

**Objectif** : Établir les métriques de référence sans stress

| Paramètre | Valeur |
|-----------|--------|
| Throughput | 100 msg/s |
| Durée | 10 min |
| Record size | ~1 KB |
| Topics | 1 |

### Variante A - Python Bomber

```bash
python kafka_producer_bomber.py \
  --bootstrap-servers "$KAFKA_SOURCE" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --messages-per-second 100 \
  --num-threads 1 \
  --num-topics 1 \
  --duration-minutes 10
```

### Variante B - kafka-producer-perf-test

```bash
kafka-producer-perf-test.sh \
  --topic "test-prometheus.generated-data-01.json" \
  --num-records 60000 \
  --record-size 1024 \
  --throughput 100 \
  --producer-props \
    bootstrap.servers=$KAFKA_SOURCE \
    security.protocol=SASL_SSL \
    sasl.mechanism=PLAIN \
    acks=all
```

### Dashboard : `mm2-replication.json`

| Métrique | Valeur Baseline |
|----------|-----------------|
| Latence avg | _______ ms |
| Latence max | _______ ms |
| Lag | _______ |

---

## S2 : Charge Nominale

**Objectif** : Valider le fonctionnement normal

| Paramètre | Valeur |
|-----------|--------|
| Throughput | 1000 msg/s |
| Durée | 30 min |
| Record size | ~1 KB |
| Topics | 10 |

### Variante A - Python Bomber

```bash
python kafka_producer_bomber.py \
  --bootstrap-servers "$KAFKA_SOURCE" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --messages-per-second 1000 \
  --num-threads 5 \
  --num-topics 10 \
  --duration-minutes 30
```

### Variante B - kafka-producer-perf-test

```bash
kafka-producer-perf-test.sh \
  --topic "test-prometheus.generated-data-01.json" \
  --num-records 1800000 \
  --record-size 1024 \
  --throughput 1000 \
  --producer-props \
    bootstrap.servers=$KAFKA_SOURCE \
    acks=all \
    compression.type=gzip \
    linger.ms=10
```

---

## S3 : Pic de Charge

**Objectif** : Valider la tenue aux pics

| Paramètre | Valeur |
|-----------|--------|
| Throughput | 5000 msg/s |
| Durée | 15 min |
| Topics | 10 |

### Variante A - Python Bomber

```bash
python kafka_producer_bomber.py \
  --messages-per-second 5000 \
  --num-threads 10 \
  --num-topics 10 \
  --duration-minutes 15 \
  ...
```

### Variante B - kafka-producer-perf-test

```bash
kafka-producer-perf-test.sh \
  --topic "test-prometheus.generated-data-01.json" \
  --num-records 4500000 \
  --record-size 1024 \
  --throughput 5000 \
  --producer-props \
    bootstrap.servers=$KAFKA_SOURCE \
    acks=all \
    batch.size=32768 \
    linger.ms=5
```

---

## S4 : Burst (Rafale)

**Objectif** : Valider l'absorption d'une rafale et le rattrapage

| Paramètre | Valeur |
|-----------|--------|
| Throughput | 10000 msg/s |
| Durée burst | 1 min |
| Observation récupération | 5 min |

### Exécution

```bash
# Burst 1 minute
timeout 60 python kafka_producer_bomber.py \
  --messages-per-second 10000 \
  --num-threads 20 \
  --num-topics 10 \
  --duration-minutes 2 \
  ...

# Puis observer dans Grafana la récupération du lag
```

### Dashboard : `mm2-detailed-metrics.json`

Observer "Active Records (Lag)" qui doit :
1. Monter pendant le burst
2. Redescendre après l'arrêt
3. Revenir < 1000 en < 5 min

---

## S5 : Long Run (Endurance)

**Objectif** : Stabilité sur 24h

| Paramètre | Valeur |
|-----------|--------|
| Throughput | 70% capacité max |
| Durée | 24h |
| Topics | 10 |

### Exécution (background)

```bash
nohup python kafka_producer_bomber.py \
  --messages-per-second 3500 \
  --num-threads 7 \
  --num-topics 10 \
  --duration-minutes 1440 \
  > longrun.log 2>&1 &
```

---

## S6 : Variation Taille Message

**Objectif** : Impact de la taille du payload

| Sous-scénario | Record Size | Throughput |
|---------------|-------------|------------|
| S6a - Petit | 100 bytes | 5000 msg/s |
| S6b - Moyen | 1 KB | 2000 msg/s |
| S6c - Gros | 10 KB | 500 msg/s |
| S6d - Très gros | 100 KB | 50 msg/s |

### Variante B - perf-test (permet de contrôler la taille)

```bash
# S6a - 100 bytes
kafka-producer-perf-test.sh \
  --num-records 300000 \
  --record-size 100 \
  --throughput 5000 ...

# S6c - 10 KB
kafka-producer-perf-test.sh \
  --num-records 30000 \
  --record-size 10240 \
  --throughput 500 ...
```

---

## S7 : Variation Partitions

**Objectif** : Impact du parallélisme

| Config | Partitions | Tasks MM2 |
|--------|------------|-----------|
| S7a | 3 | 3 |
| S7b | 12 | 8 |
| S7c | 48 | 16 |

### Préparation

```bash
# Créer topics avec différents nombres de partitions
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --create --topic "test-partition-3" --partitions 3 --replication-factor 3

kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --create --topic "test-partition-48" --partitions 48 --replication-factor 3
```

### Ajuster tasks.max

```bash
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/config \
  -H "Content-Type: application/json" \
  -d '{"tasks.max": "16", ...}'
```

---

## Grille de Résultats

| Scénario | Latence Avg | Latence Max | Lag Max | CPU % | Résultat |
|----------|-------------|-------------|---------|-------|----------|
| S1 | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S2 | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S3 | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S4 | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S5 | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S6a | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S6b | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S6c | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S6d | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S7a | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S7b | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
| S7c | ___ms | ___ms | ___ | ___% | ☐GO ☐NOGO |
