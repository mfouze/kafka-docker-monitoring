# Section 1 : Tests de Performance Baseline

**Objectif** : Établir les métriques de référence du cluster en conditions normales  
**Durée estimée** : 4 heures  
**Prérequis** : Cluster stable, tous composants opérationnels

---

## 1.1 Objectifs de cette Section

| Objectif | Description |
|----------|-------------|
| Baseline latence | Mesurer la latence de production/consommation en conditions normales |
| Baseline throughput | Déterminer le throughput maximal soutenable |
| Point d'équilibre | Identifier le throughput optimal (latence acceptable) |
| Référence SLA | Établir les valeurs de référence pour le monitoring |

---

## 1.2 Test 1.1 - Latence à Faible Charge

### Configuration

```bash
# Paramètres du test
TOPIC="perf-baseline-latency"
NUM_RECORDS=100000
RECORD_SIZE=1024
THROUGHPUT=100  # 100 msg/s - charge très faible
```

### Commande

```bash
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records ${NUM_RECORDS} \
  --record-size ${RECORD_SIZE} \
  --throughput ${THROUGHPUT} \
  --producer.config producer-tls.properties \
  --print-metrics
```

### Métriques à Collecter

| Métrique | Seuil Attendu | Seuil Critique |
|----------|---------------|----------------|
| Latence moyenne | < 10 ms | > 50 ms |
| Latence P50 | < 8 ms | > 30 ms |
| Latence P95 | < 15 ms | > 100 ms |
| Latence P99 | < 25 ms | > 200 ms |
| Latence P99.9 | < 50 ms | > 500 ms |

### Critères de Succès

- [ ] Latence moyenne < 10 ms
- [ ] Latence P99 < 25 ms
- [ ] Aucune erreur de production
- [ ] Throughput stable à 100 msg/s

### Grille de Résultats

| Métrique | Valeur Mesurée | Statut |
|----------|----------------|--------|
| Latence moyenne | _____ ms | ☐ OK ☐ KO |
| Latence P50 | _____ ms | ☐ OK ☐ KO |
| Latence P95 | _____ ms | ☐ OK ☐ KO |
| Latence P99 | _____ ms | ☐ OK ☐ KO |
| Latence P99.9 | _____ ms | ☐ OK ☐ KO |
| Throughput effectif | _____ msg/s | ☐ OK ☐ KO |

---

## 1.3 Test 1.2 - Latence à Charge Modérée

### Configuration

```bash
# Paramètres du test
TOPIC="perf-baseline-latency"
NUM_RECORDS=500000
RECORD_SIZE=1024
THROUGHPUT=1000  # 1000 msg/s - charge modérée
```

### Commande

```bash
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records ${NUM_RECORDS} \
  --record-size ${RECORD_SIZE} \
  --throughput ${THROUGHPUT} \
  --producer.config producer-tls.properties \
  --print-metrics
```

### Métriques à Collecter

| Métrique | Seuil Attendu | Seuil Critique |
|----------|---------------|----------------|
| Latence moyenne | < 25 ms | > 100 ms |
| Latence P50 | < 20 ms | > 50 ms |
| Latence P95 | < 35 ms | > 150 ms |
| Latence P99 | < 50 ms | > 300 ms |
| Latence P99.9 | < 100 ms | > 500 ms |

### Référence Jour 3

Les résultats du Test 1 (Jour 3) à 1000 msg/s ont montré :
- Latence moyenne : 21.41 ms
- Latence P99 : 32 ms
- Latence P99.9 : 63 ms

### Grille de Résultats

| Métrique | Valeur Mesurée | Référence J3 | Écart |
|----------|----------------|--------------|-------|
| Latence moyenne | _____ ms | 21.41 ms | ___% |
| Latence P50 | _____ ms | 23 ms | ___% |
| Latence P95 | _____ ms | 28 ms | ___% |
| Latence P99 | _____ ms | 32 ms | ___% |
| Latence P99.9 | _____ ms | 63 ms | ___% |

---

## 1.4 Test 1.3 - Throughput Maximal

### Configuration

```bash
# Paramètres du test
TOPIC="perf-baseline-throughput"
NUM_RECORDS=1800000
RECORD_SIZE=1024
THROUGHPUT=-1  # Pas de limite
```

### Commande

```bash
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records ${NUM_RECORDS} \
  --record-size ${RECORD_SIZE} \
  --throughput ${THROUGHPUT} \
  --producer.config producer-tls.properties \
  --print-metrics
```

### Métriques à Collecter

| Métrique | Seuil Minimum | Observation |
|----------|---------------|-------------|
| Throughput maximal | > 5000 msg/s | Capacité brute |
| Débit | > 5 MB/s | Bande passante |
| CPU brokers | < 80% | Marge disponible |
| Latence moyenne | Documentée | Dégradation attendue |

### Référence Jour 3

Les résultats du Test 2 (Jour 3) en throughput max ont montré :
- Throughput : 9308 msg/s
- Débit : 9.09 MB/s
- Latence moyenne : 3247 ms (INACCEPTABLE pour production)

### Grille de Résultats

| Métrique | Valeur Mesurée | Référence J3 | Écart |
|----------|----------------|--------------|-------|
| Throughput | _____ msg/s | 9308 msg/s | ___% |
| Débit | _____ MB/s | 9.09 MB/s | ___% |
| Latence moyenne | _____ ms | 3247 ms | ___% |
| CPU brokers (max) | ____% | ~25% | ___% |

---

## 1.5 Test 1.4 - Recherche du Point d'Équilibre

### Objectif

Trouver le throughput maximal avec latence P99 < 100 ms.

### Méthodologie

Exécuter des tests avec throughput croissant par paliers :

| Palier | Throughput | Durée | Validation |
|--------|------------|-------|------------|
| 1 | 1000 msg/s | 5 min | Baseline |
| 2 | 2000 msg/s | 5 min | +100% |
| 3 | 3000 msg/s | 5 min | +200% |
| 4 | 4000 msg/s | 5 min | +300% |
| 5 | 5000 msg/s | 5 min | +400% |
| 6 | 6000 msg/s | 5 min | +500% |
| 7 | 7000 msg/s | 5 min | +600% |
| 8 | 8000 msg/s | 5 min | +700% |

### Script de Test

```bash
#!/bin/bash
TOPIC="perf-equilibrium"
RECORD_SIZE=1024
DURATION_RECORDS=300000  # ~5 min à chaque palier

for THROUGHPUT in 1000 2000 3000 4000 5000 6000 7000 8000; do
  echo "=== Test palier ${THROUGHPUT} msg/s ==="
  kafka-producer-perf-test \
    --topic "${TOPIC}" \
    --num-records ${DURATION_RECORDS} \
    --record-size ${RECORD_SIZE} \
    --throughput ${THROUGHPUT} \
    --producer.config producer-tls.properties
  echo ""
  sleep 30  # Pause entre paliers
done
```

### Grille de Résultats

| Throughput | Latence Avg | Latence P99 | Statut SLA |
|------------|-------------|-------------|------------|
| 1000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |
| 2000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |
| 3000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |
| 4000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |
| 5000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |
| 6000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |
| 7000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |
| 8000 msg/s | _____ ms | _____ ms | ☐ OK ☐ KO |

### Point d'Équilibre Identifié

| Métrique | Valeur |
|----------|--------|
| Throughput optimal | _____ msg/s |
| Latence P99 à ce throughput | _____ ms |
| Marge vs SLA (100 ms) | _____ ms |

---

## 1.6 Test 1.5 - Performance Consommation

### Configuration

```bash
# Prérequis : Topic peuplé avec 1M+ messages
TOPIC="perf-baseline-consumer"
MESSAGES=1000000
```

### Commande

```bash
kafka-consumer-perf-test \
  --bootstrap-server ${BOOTSTRAP_SERVERS} \
  --topic ${TOPIC} \
  --messages ${MESSAGES} \
  --consumer.config consumer-tls.properties \
  --print-metrics
```

### Métriques à Collecter

| Métrique | Seuil Attendu | Seuil Critique |
|----------|---------------|----------------|
| Throughput consommation | > 10000 msg/s | < 5000 msg/s |
| Débit | > 10 MB/s | < 5 MB/s |
| Fetch latency avg | < 50 ms | > 200 ms |

### Grille de Résultats

| Métrique | Valeur Mesurée | Statut |
|----------|----------------|--------|
| Throughput consommation | _____ msg/s | ☐ OK ☐ KO |
| Débit | _____ MB/s | ☐ OK ☐ KO |
| Temps total | _____ s | ☐ OK ☐ KO |

---

## 1.7 Test 1.6 - Impact des Optimisations Jour 3

### Objectif

Comparer les performances avant/après application des optimisations brokers.

### Optimisations Appliquées (Rappel)

| Paramètre | Avant | Après |
|-----------|-------|-------|
| num.network.threads | 3 | 4 |
| num.replica.fetchers | 1 | 2 |
| num.recovery.threads.per.data.dir | 1 | 2 |
| socket.send.buffer.bytes | 102 KB | 1 MB |
| socket.receive.buffer.bytes | 102 KB | 1 MB |
| zookeeper.connection.timeout.ms | 6000 | 18000 |

### Test de Validation

Réexécuter le Test 1.2 (1000 msg/s) et comparer :

| Métrique | Avant Optim (J3) | Après Optim | Amélioration |
|----------|------------------|-------------|--------------|
| Latence moyenne | 21.41 ms | _____ ms | ___% |
| Latence P99 | 32 ms | _____ ms | ___% |
| Latence P99.9 | 63 ms | _____ ms | ___% |

---

## 1.8 Métriques Grafana à Capturer

### Pendant les Tests

| Dashboard | Métrique | Screenshot |
|-----------|----------|------------|
| Kafka Cluster | MessagesInPerSec | ☐ |
| Kafka Cluster | BytesInPerSec | ☐ |
| Kafka Cluster | RequestHandlerAvgIdlePercent | ☐ |
| Broker | NetworkProcessorAvgIdlePercent | ☐ |
| ZooKeeper | AvgRequestLatency | ☐ |
| ZooKeeper | OutstandingRequests | ☐ |
| Infrastructure | CPU Usage | ☐ |
| Infrastructure | Memory Usage | ☐ |
| Infrastructure | Disk I/O | ☐ |

---

## 1.9 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 1.1 - Latence faible charge exécuté
- [ ] Test 1.2 - Latence charge modérée exécuté
- [ ] Test 1.3 - Throughput maximal mesuré
- [ ] Test 1.4 - Point d'équilibre identifié
- [ ] Test 1.5 - Performance consommation validée
- [ ] Test 1.6 - Impact optimisations mesuré

### Documentation

- [ ] Tous les résultats documentés
- [ ] Screenshots Grafana capturés
- [ ] Anomalies identifiées et documentées
- [ ] Baseline de référence établie

### Résultat Global Section 1

| Critère | Statut |
|---------|--------|
| Latence P99 < 100 ms (charge modérée) | ☐ PASS ☐ FAIL |
| Throughput optimal identifié | ☐ PASS ☐ FAIL |
| Baseline établie | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Introduction](00-plan-tests-introduction.md)  
**Section suivante** : [Tests de Charge et Stress](02-tests-charge-stress.md)
