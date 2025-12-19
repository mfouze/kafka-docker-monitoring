# Section 2 : Tests de Charge et Stress

**Objectif** : Valider le comportement du cluster sous charge élevée et stress  
**Durée estimée** : 6 heures  
**Prérequis** : Section 1 complétée, baseline établie

---

## 2.1 Objectifs de cette Section

| Objectif | Description |
|----------|-------------|
| Charge soutenue | Valider la stabilité sous charge continue |
| Pic de charge | Mesurer le comportement lors de pics soudains |
| Stress test | Identifier les limites et points de rupture |
| Backpressure | Valider les mécanismes de backpressure |

---

## 2.2 Test 2.1 - Charge Soutenue (1 heure)

### Objectif

Valider la stabilité du cluster sous charge modérée pendant 1 heure continue.

### Configuration

```bash
# Paramètres
TOPIC="stress-sustained"
RECORD_SIZE=1024
THROUGHPUT=3000  # Throughput sous le point d'équilibre
DURATION=3600    # 1 heure
NUM_RECORDS=$((THROUGHPUT * DURATION))  # 10.8M messages
```

### Commande

```bash
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records ${NUM_RECORDS} \
  --record-size ${RECORD_SIZE} \
  --throughput ${THROUGHPUT} \
  --producer.config producer-tls.properties
```

### Métriques à Surveiller (Toutes les 5 min)

| Temps | Throughput | Latence P99 | CPU | Under-Rep | ZK Latency |
|-------|------------|-------------|-----|-----------|------------|
| T+5min | _____ | _____ ms | ___% | _____ | _____ ms |
| T+10min | _____ | _____ ms | ___% | _____ | _____ ms |
| T+15min | _____ | _____ ms | ___% | _____ | _____ ms |
| T+20min | _____ | _____ ms | ___% | _____ | _____ ms |
| T+30min | _____ | _____ ms | ___% | _____ | _____ ms |
| T+45min | _____ | _____ ms | ___% | _____ | _____ ms |
| T+60min | _____ | _____ ms | ___% | _____ | _____ ms |

### Critères de Succès

- [ ] Latence P99 stable (< 20% variation)
- [ ] Aucune under-replicated partition
- [ ] Throughput maintenu à ±5%
- [ ] CPU brokers < 70%
- [ ] Aucune erreur de production

### Grille de Résultats

| Métrique | Valeur Début | Valeur Fin | Variation |
|----------|--------------|------------|-----------|
| Latence P99 | _____ ms | _____ ms | ___% |
| Throughput | _____ msg/s | _____ msg/s | ___% |
| Messages produits | 0 | _____ | _____ |
| Erreurs | 0 | _____ | _____ |

---

## 2.3 Test 2.2 - Pics de Charge (Burst)

### Objectif

Valider la réaction du cluster à des pics soudains de charge.

### Scénario

```
Charge normale (2000 msg/s) → Pic (8000 msg/s) → Retour normal
Durée: 5 min normale → 2 min pic → 5 min normale → 2 min pic → 5 min normale
```

### Script de Test

```bash
#!/bin/bash
TOPIC="stress-burst"
RECORD_SIZE=1024

echo "=== Phase 1: Charge normale (5 min) ==="
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records 600000 \
  --record-size ${RECORD_SIZE} \
  --throughput 2000 \
  --producer.config producer-tls.properties

echo "=== Phase 2: Pic de charge (2 min) ==="
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records 960000 \
  --record-size ${RECORD_SIZE} \
  --throughput 8000 \
  --producer.config producer-tls.properties

echo "=== Phase 3: Retour normal (5 min) ==="
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records 600000 \
  --record-size ${RECORD_SIZE} \
  --throughput 2000 \
  --producer.config producer-tls.properties

echo "=== Phase 4: Second pic (2 min) ==="
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records 960000 \
  --record-size ${RECORD_SIZE} \
  --throughput 8000 \
  --producer.config producer-tls.properties

echo "=== Phase 5: Stabilisation (5 min) ==="
kafka-producer-perf-test \
  --topic "${TOPIC}" \
  --num-records 600000 \
  --record-size ${RECORD_SIZE} \
  --throughput 2000 \
  --producer.config producer-tls.properties
```

### Métriques par Phase

| Phase | Throughput Cible | Latence P99 | Erreurs | Statut |
|-------|------------------|-------------|---------|--------|
| 1 - Normal | 2000 msg/s | _____ ms | _____ | ☐ OK |
| 2 - Pic | 8000 msg/s | _____ ms | _____ | ☐ OK |
| 3 - Normal | 2000 msg/s | _____ ms | _____ | ☐ OK |
| 4 - Pic | 8000 msg/s | _____ ms | _____ | ☐ OK |
| 5 - Normal | 2000 msg/s | _____ ms | _____ | ☐ OK |

### Critères de Succès

- [ ] Récupération latence < 30s après pic
- [ ] Aucune perte de message
- [ ] Under-replicated partitions = 0 après stabilisation
- [ ] Pas d'OOM ou crash

---

## 2.4 Test 2.3 - Stress Progressif jusqu'à Saturation

### Objectif

Identifier le point de saturation et le comportement au-delà.

### Méthodologie

Augmentation progressive du throughput jusqu'à dégradation significative.

### Script de Test

```bash
#!/bin/bash
TOPIC="stress-progressive"
RECORD_SIZE=1024
RECORDS_PER_STEP=180000  # 3 min par palier

for THROUGHPUT in 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000 12000 15000; do
  echo "=========================================="
  echo "=== Palier: ${THROUGHPUT} msg/s ==="
  echo "=========================================="
  
  kafka-producer-perf-test \
    --topic "${TOPIC}" \
    --num-records ${RECORDS_PER_STEP} \
    --record-size ${RECORD_SIZE} \
    --throughput ${THROUGHPUT} \
    --producer.config producer-tls.properties
  
  echo ""
  echo "Pause 30s pour stabilisation..."
  sleep 30
done
```

### Grille de Résultats

| Throughput Cible | Throughput Réel | Latence P99 | CPU | Saturation |
|------------------|-----------------|-------------|-----|------------|
| 1000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 2000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 3000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 4000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 5000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 6000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 7000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 8000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Non |
| 9000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Début |
| 10000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Oui |
| 12000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Oui |
| 15000 msg/s | _____ msg/s | _____ ms | ___% | ☐ Oui |

### Point de Saturation Identifié

| Métrique | Valeur |
|----------|--------|
| Throughput de saturation | _____ msg/s |
| Latence P99 à saturation | _____ ms |
| CPU à saturation | _____ % |
| Facteur de sécurité recommandé | _____ % du max |

---

## 2.5 Test 2.4 - Multi-Producteurs Concurrents

### Objectif

Valider le comportement avec plusieurs producteurs simultanés.

### Configuration

```bash
# 5 producteurs simultanés, 1000 msg/s chacun = 5000 msg/s total
NUM_PRODUCERS=5
THROUGHPUT_PER_PRODUCER=1000
RECORDS_PER_PRODUCER=600000
```

### Script de Test

```bash
#!/bin/bash
TOPIC="stress-multi-producer"

# Lancer 5 producteurs en parallèle
for i in $(seq 1 5); do
  kafka-producer-perf-test \
    --topic "${TOPIC}" \
    --num-records 600000 \
    --record-size 1024 \
    --throughput 1000 \
    --producer.config producer-tls.properties &
  echo "Producteur $i lancé (PID: $!)"
done

# Attendre la fin de tous les producteurs
wait
echo "Tous les producteurs terminés"
```

### Métriques à Collecter

| Métrique | Valeur Attendue | Valeur Mesurée |
|----------|-----------------|----------------|
| Throughput total agrégé | ~5000 msg/s | _____ msg/s |
| Latence P99 moyenne | < 100 ms | _____ ms |
| Messages totaux | 3M | _____ |
| Erreurs totales | 0 | _____ |

### Critères de Succès

- [ ] Throughput agrégé proche de la somme des throughputs individuels
- [ ] Pas de contention excessive (latence stable)
- [ ] Répartition équitable sur les partitions
- [ ] Aucune erreur de production

---

## 2.6 Test 2.5 - Messages de Grande Taille

### Objectif

Valider le comportement avec des messages plus volumineux.

### Configuration

| Test | Taille Message | Throughput | Volume/s |
|------|----------------|------------|----------|
| A | 1 KB | 1000 msg/s | 1 MB/s |
| B | 10 KB | 1000 msg/s | 10 MB/s |
| C | 100 KB | 100 msg/s | 10 MB/s |
| D | 500 KB | 20 msg/s | 10 MB/s |

### Commandes

```bash
# Test A - 1 KB
kafka-producer-perf-test --topic stress-size-1k \
  --num-records 300000 --record-size 1024 --throughput 1000 \
  --producer.config producer-tls.properties

# Test B - 10 KB
kafka-producer-perf-test --topic stress-size-10k \
  --num-records 300000 --record-size 10240 --throughput 1000 \
  --producer.config producer-tls.properties

# Test C - 100 KB
kafka-producer-perf-test --topic stress-size-100k \
  --num-records 30000 --record-size 102400 --throughput 100 \
  --producer.config producer-tls.properties

# Test D - 500 KB
kafka-producer-perf-test --topic stress-size-500k \
  --num-records 6000 --record-size 512000 --throughput 20 \
  --producer.config producer-tls.properties
```

### Grille de Résultats

| Taille | Latence Avg | Latence P99 | Throughput | Débit MB/s |
|--------|-------------|-------------|------------|------------|
| 1 KB | _____ ms | _____ ms | _____ msg/s | _____ MB/s |
| 10 KB | _____ ms | _____ ms | _____ msg/s | _____ MB/s |
| 100 KB | _____ ms | _____ ms | _____ msg/s | _____ MB/s |
| 500 KB | _____ ms | _____ ms | _____ msg/s | _____ MB/s |

---

## 2.7 Test 2.6 - Backpressure et Retry

### Objectif

Valider le comportement du producteur sous backpressure.

### Configuration Producteur

```properties
# producer-backpressure.properties
bootstrap.servers=${BOOTSTRAP_SERVERS}
security.protocol=SASL_SSL
# ...

# Backpressure settings
buffer.memory=33554432  # 32 MB
max.block.ms=60000      # 60s max block
retries=3
retry.backoff.ms=100
delivery.timeout.ms=120000
```

### Scénario

1. Lancer une charge supérieure à la capacité (15000 msg/s)
2. Observer le comportement du producteur
3. Mesurer les retries et le temps de blocage

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| buffer-available-bytes (min) | _____ |
| buffer-exhausted-rate | _____ |
| record-retry-rate | _____ |
| record-error-rate | _____ |
| produce-throttle-time-avg | _____ ms |

### Critères de Succès

- [ ] Pas de perte de message malgré backpressure
- [ ] Retries fonctionnels
- [ ] Récupération après retour à charge normale

---

## 2.8 Test 2.7 - Charge Mixte Production/Consommation

### Objectif

Valider le comportement sous charge simultanée de production et consommation.

### Scénario

- 3 producteurs à 2000 msg/s chacun = 6000 msg/s entrant
- 3 consommateurs en parallèle

### Script de Test

```bash
#!/bin/bash
TOPIC="stress-mixed"

# Créer le topic avec 12 partitions
kafka-topics --create --topic ${TOPIC} \
  --partitions 12 --replication-factor 3 \
  --bootstrap-server ${BOOTSTRAP_SERVERS}

# Lancer les producteurs
for i in 1 2 3; do
  kafka-producer-perf-test --topic ${TOPIC} \
    --num-records 1200000 --record-size 1024 --throughput 2000 \
    --producer.config producer-tls.properties &
done

# Lancer les consommateurs (après un délai pour avoir des données)
sleep 30
for i in 1 2 3; do
  kafka-consumer-perf-test --topic ${TOPIC} \
    --messages 1200000 --group stress-consumer-$i \
    --bootstrap-server ${BOOTSTRAP_SERVERS} \
    --consumer.config consumer-tls.properties &
done

wait
```

### Métriques à Collecter

| Métrique | Production | Consommation |
|----------|------------|--------------|
| Throughput total | _____ msg/s | _____ msg/s |
| Latence P99 | _____ ms | N/A |
| Lag max | N/A | _____ |
| CPU brokers | _____ % | _____ % |

---

## 2.9 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 2.1 - Charge soutenue 1h
- [ ] Test 2.2 - Pics de charge (burst)
- [ ] Test 2.3 - Stress progressif
- [ ] Test 2.4 - Multi-producteurs
- [ ] Test 2.5 - Messages grande taille
- [ ] Test 2.6 - Backpressure
- [ ] Test 2.7 - Charge mixte

### Points Clés Identifiés

| Point | Valeur |
|-------|--------|
| Throughput soutenable 1h | _____ msg/s |
| Point de saturation | _____ msg/s |
| Temps récupération après pic | _____ s |
| Taille message max recommandée | _____ KB |

### Résultat Global Section 2

| Critère | Statut |
|---------|--------|
| Stabilité sous charge soutenue | ☐ PASS ☐ FAIL |
| Récupération après pics | ☐ PASS ☐ FAIL |
| Point de saturation documenté | ☐ PASS ☐ FAIL |
| Backpressure fonctionnel | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests de Performance Baseline](01-tests-performance-baseline.md)  
**Section suivante** : [Tests de Résilience Broker](03-tests-resilience-broker.md)
