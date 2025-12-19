# Phase 2 : Charge Nominale

**Durée** : 30 minutes  
**Objectif** : Valider le comportement sous charge normale (1000 msg/s)

---

## Étape 2.1 : Lancer la Charge

### Variante A - Python Bomber

```bash
python kafka_producer_bomber.py \
  --bootstrap-servers "$KAFKA_SOURCE" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --topic-prefix "test-prometheus" \
  --num-topics 10 \
  --messages-per-second 1000 \
  --num-threads 5 \
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
    security.protocol=SASL_SSL \
    sasl.mechanism=PLAIN \
    acks=all \
    compression.type=gzip \
    linger.ms=10
```

---

## Étape 2.2 : Surveillance Continue via Grafana

### Dashboard Principal : `mm2-replication.json`

Ouvrir et garder visible pendant toute la durée du test.

| Panel | Seuil GO | Seuil NOGO |
|-------|----------|------------|
| **Avg Replication Latency** | < 500 ms | > 1000 ms |
| **Max Replication Latency** | < 2000 ms | > 5000 ms |
| **Total Record Rate** | ≈ 1000/s | < 800/s |
| **Total Byte Rate** | ≈ 1 MB/s | < 0.5 MB/s |

### Dashboard Secondaire : `mm2-detailed-metrics.json`

| Panel | Seuil GO | Seuil NOGO |
|-------|----------|------------|
| **Active Records (Lag)** | < 5000 | > 10000 |
| **Replication Ratio** | > 99% | < 95% |
| **Offset Commit Failure %** | < 1% | > 5% |
| **Buffer Utilization %** | < 70% | > 90% |

### Dashboard Infra : `Node-Eporter.json`

| Panel | Seuil GO | Seuil NOGO |
|-------|----------|------------|
| **CPU Usage** (workers) | < 70% | > 85% |
| **Memory Usage** | < 80% | > 90% |
| **Network I/O** | Stable | Drops |

---

## Étape 2.3 : Points de Contrôle

### T+5 min

| Métrique | Valeur | GO/NOGO |
|----------|--------|---------|
| Latence avg | _____ ms | ☐ GO ☐ NOGO |
| Lag | _____ | ☐ GO ☐ NOGO |
| Ratio réplication | _____ % | ☐ GO ☐ NOGO |

### T+15 min

| Métrique | Valeur | GO/NOGO |
|----------|--------|---------|
| Latence avg | _____ ms | ☐ GO ☐ NOGO |
| Lag | _____ | ☐ GO ☐ NOGO |
| CPU workers | _____ % | ☐ GO ☐ NOGO |

### T+30 min (Fin)

| Métrique | Valeur | GO/NOGO |
|----------|--------|---------|
| Latence avg | _____ ms | ☐ GO ☐ NOGO |
| Latence p99 | _____ ms | ☐ GO ☐ NOGO |
| Lag final | _____ | ☐ GO ☐ NOGO |
| Total messages | _____ | ☐ GO ☐ NOGO |

---

## Étape 2.4 : Vérifier Stabilité du Lag

Le lag doit être **stable** (pas croissant) pendant tout le test.

**Grafana Panel** : `mm2-detailed-metrics.json` → "Active Records (Lag)"

```
Tendance attendue :
                     ┌──────────────────────────────┐
Lag                  │                              │ ← Stable
                     │      ╭─────────────────────╮ │
                     │     ╱                       │ │
                     │    ╱                        │ │
                     │───╱                         │ │
                     │                              │
                     └──────────────────────────────┘
                     T0    T+5min    T+15min   T+30min

Tendance NOGO (lag croissant) :
                     ┌──────────────────────────────┐
Lag                  │                         ╱╱╱╱ │ ← NOGO
                     │                      ╱╱╱     │
                     │                   ╱╱╱        │
                     │                ╱╱╱           │
                     │             ╱╱╱              │
                     │          ╱╱╱                 │
                     │       ╱╱╱                    │
                     │───────                       │
                     └──────────────────────────────┘
```

---

## Checklist Phase 2

| Critère | Résultat | Notes |
|---------|----------|-------|
| Latence p99 < 1s | ☐ GO ☐ NOGO | p99: ___ms |
| Lag stable < 5000 | ☐ GO ☐ NOGO | Max lag: _____ |
| Ratio > 99% | ☐ GO ☐ NOGO | Ratio: ___% |
| CPU < 80% | ☐ GO ☐ NOGO | Max CPU: ___% |
| Pas d'erreurs | ☐ GO ☐ NOGO | |

**Phase 2 terminée** : ☐ GO pour Phase 3 ☐ NOGO - voir section optimisation
