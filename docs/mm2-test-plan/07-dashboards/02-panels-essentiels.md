# Panels Essentiels à Surveiller

## Top 10 des Panels Critiques

| # | Panel | Dashboard | Pourquoi |
|---|-------|-----------|----------|
| 1 | **Avg Replication Latency** | mm2-replication | SLO principal |
| 2 | **Active Records (Lag)** | mm2-detailed | Santé réplication |
| 3 | **Replication Ratio** | mm2-detailed | Détection perte |
| 4 | **Workers Online** | kafka-connect-cluster | Disponibilité |
| 5 | **Failed Tasks** | kafka-connect-cluster | Erreurs critiques |
| 6 | **Buffer Utilization %** | mm2-detailed | Backpressure |
| 7 | **CPU Usage** | Node-Exporter | Capacité |
| 8 | **Memory Usage** | Node-Exporter | Stabilité |
| 9 | **Under Replicated Partitions** | kafka-cluster | Durabilité |
| 10 | **Producer Throttle Time** | mm2-detailed | Quotas |

---

## Panel 1 : Avg Replication Latency

**Dashboard** : `mm2-replication.json`

### PromQL

```promql
avg(kafka_connect_mirror_source_connector_replication_latency_ms{topic=~"$topic"})
```

### Interprétation

| Valeur | Signification | Action |
|--------|---------------|--------|
| < 100ms | Excellent | - |
| 100-500ms | Normal | - |
| 500-1000ms | Élevé | Surveiller |
| 1000-5000ms | Warning | Analyser |
| > 5000ms | **Hors SLO** | Intervention |

### Ce qui Fait Augmenter

- Latence réseau
- Charge élevée
- Quotas/throttling
- GC pauses

---

## Panel 2 : Active Records (Lag)

**Dashboard** : `mm2-detailed-metrics.json`

### PromQL

```promql
sum(kafka_connect_source_task_metrics_source_record_active_count{connector=~"$connector"})
```

### Interprétation

| Valeur | Signification |
|--------|---------------|
| < 1000 | Normal |
| 1000-5000 | Charge élevée |
| 5000-10000 | **Warning** |
| > 10000 | **Critical** |

### Tendances à Observer

```
Stable (OK) :          Croissant (NOGO) :
                       
      ────────             ╱╱╱╱
                          ╱╱╱
                        ╱╱
```

---

## Panel 3 : Replication Ratio

**Dashboard** : `mm2-detailed-metrics.json`

### PromQL

```promql
100 * sum(kafka_connect_source_task_metrics_source_record_write_total)
    / sum(kafka_connect_source_task_metrics_source_record_poll_total)
```

### Interprétation

| Valeur | Signification |
|--------|---------------|
| > 99.9% | Parfait |
| 99-99.9% | Acceptable |
| 95-99% | **Warning** - perte possible |
| < 95% | **Critical** - perte avérée |

---

## Panel 4 : Workers Online

**Dashboard** : `kafka-connect-cluster.json`

### Ce qu'il Montre

Nombre de workers Kafka Connect actifs.

### Attendu

= Nombre déployé (typiquement 2+)

### Si < Attendu

1. Worker down → Vérifier systemctl/container
2. Network partition → Vérifier connectivité
3. OOM kill → Vérifier logs système

---

## Panel 5 : Failed Tasks

**Dashboard** : `kafka-connect-cluster.json`

### Attendu

**Toujours 0**

### Si > 0

1. Identifier le connector/task
2. Lire les logs
3. Corriger la cause
4. Restart si nécessaire

```bash
# Identifier
curl -s http://connect:8083/connectors/mm2-source-connector/status | jq '.tasks[] | select(.state != "RUNNING")'

# Restart task spécifique
curl -X POST http://connect:8083/connectors/mm2-source-connector/tasks/0/restart
```

---

## Panel 6 : Buffer Utilization %

**Dashboard** : `mm2-detailed-metrics.json`

### PromQL

```promql
100 * (1 - kafka_producer_producer_metrics_buffer_available_bytes 
       / kafka_producer_producer_metrics_buffer_total_bytes)
```

### Interprétation

| Valeur | Signification |
|--------|---------------|
| < 50% | Healthy |
| 50-70% | Normal sous charge |
| 70-90% | **Warning** - backpressure |
| > 90% | **Critical** - risque perte |

### Actions si Élevé

1. Augmenter `buffer.memory`
2. Augmenter throughput target (quotas)
3. Scale out workers

---

## Panel 7 : CPU Usage (Workers)

**Dashboard** : `Node-Eporter.json`

### PromQL

```promql
100 - avg(rate(node_cpu_seconds_total{mode="idle",instance=~"kafka-connect.*"}[5m])) * 100
```

### Interprétation

| Valeur | Signification |
|--------|---------------|
| < 50% | Healthy |
| 50-70% | Normal sous charge |
| 70-85% | **Warning** - proche limite |
| > 85% | **Critical** - saturation |

---

## Panel 8 : Memory Usage (Workers)

**Dashboard** : `Node-Eporter.json`

### PromQL

```promql
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
```

### Tendance Long Run

**Stable** = OK  
**Croissante** = Memory leak potentiel

---

## Panel 9 : Under Replicated Partitions

**Dashboard** : `kafka-cluster.json`

### Attendu

**Toujours 0**

### Si > 0

- Broker down ou lent
- Disque plein
- Réseau saturé

---

## Panel 10 : Producer Throttle Time

**Dashboard** : `mm2-detailed-metrics.json`

### PromQL

```promql
kafka_producer_producer_metrics_produce_throttle_time_max
```

### Interprétation

| Valeur | Signification |
|--------|---------------|
| 0 | Pas de throttling |
| 1-100ms | Léger throttling |
| 100-1000ms | **Warning** |
| > 1000ms | **Critical** - quota atteint |

### Action

Augmenter le quota sur le cluster target.

---

## Configuration Écran Multi-Dashboard

### Layout Recommandé (2 écrans)

**Écran 1 - Vue Principale** :
```
┌─────────────────────────────────────────────┐
│           mm2-replication.json              │
│  ┌─────────────┐  ┌─────────────┐           │
│  │ Latency Avg │  │ Record Rate │           │
│  └─────────────┘  └─────────────┘           │
│  ┌─────────────────────────────────┐        │
│  │   Latency by Topic/Partition    │        │
│  └─────────────────────────────────┘        │
└─────────────────────────────────────────────┘
```

**Écran 2 - Détails** :
```
┌─────────────────────────────────────────────┐
│          mm2-detailed-metrics.json          │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ Lag  │ │Ratio │ │Buffer│ │ CPU  │       │
│  └──────┘ └──────┘ └──────┘ └──────┘       │
│  ┌─────────────────────────────────┐        │
│  │      Node-Exporter.json         │        │
│  └─────────────────────────────────┘        │
└─────────────────────────────────────────────┘
```
