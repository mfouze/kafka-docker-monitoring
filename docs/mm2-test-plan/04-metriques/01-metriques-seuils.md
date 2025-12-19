# Métriques et Seuils

## Tableau Principal des Métriques

| Métrique | Source | Dashboard | Warning | Critical | Action |
|----------|--------|-----------|---------|----------|--------|
| **Latence Réplication** | MM2 | mm2-replication | > 1000ms | > 5000ms | Voir 06-optimisation |
| **Lag (Active Records)** | Connect | mm2-detailed | > 5000 | > 10000 | Scale out |
| **Poll Rate** | Connect | mm2-detailed | < 80% nominal | < 50% | Vérifier source |
| **Write Rate** | Connect | mm2-detailed | Ratio < 95% | < 90% | Vérifier target |
| **Task Failures** | Connect | kafka-connect-cluster | > 0 | > 0 sur 5min | Restart tasks |
| **Connector State** | Connect | kafka-connect-cluster | N/A | != RUNNING | Intervention |
| **Offset Commit Time** | Connect | mm2-detailed | > 5000ms | > 10000ms | Tuning |
| **Buffer Utilization** | Producer | mm2-detailed | > 70% | > 90% | Augmenter buffer |
| **Throttle Time** | Producer | mm2-detailed | > 100ms | > 1000ms | Vérifier quotas |
| **CPU Workers** | Node | Node-Exporter | > 70% | > 85% | Scale out |
| **Memory Workers** | Node | Node-Exporter | > 80% | > 90% | Augmenter heap |

---

## Métriques de Réplication (MM2)

### Dashboard : `mm2-replication.json`

| Panel | Métrique Prometheus | Interprétation |
|-------|---------------------|----------------|
| Avg Replication Latency | `kafka_connect_mirror_source_connector_replication_latency_ms` | Temps moyen source→target |
| Max Replication Latency | `kafka_connect_mirror_source_connector_replication_latency_ms_max` | Pire cas observé |
| Total Records Replicated | `kafka_connect_mirror_source_connector_record_count` | Compteur cumulé |
| Total Bytes Replicated | `kafka_connect_mirror_source_connector_byte_count` | Volume cumulé |
| Record Rate | `kafka_connect_mirror_source_connector_record_rate` | Throughput instantané |
| Byte Rate | `kafka_connect_mirror_source_connector_byte_rate` | Débit instantané |
| Record Age | `kafka_connect_mirror_source_connector_record_age_ms` | Âge des messages |

---

## Métriques Connect (Tasks/Workers)

### Dashboard : `mm2-detailed-metrics.json`

| Panel | Métrique Prometheus | Seuil |
|-------|---------------------|-------|
| Total Records Polled | `kafka_connect_source_task_metrics_source_record_poll_total` | Croissant |
| Total Records Written | `kafka_connect_source_task_metrics_source_record_write_total` | ≈ Polled |
| Active Records (Lag) | `kafka_connect_source_task_metrics_source_record_active_count` | < 10000 |
| Replication Ratio | `write_total / poll_total × 100` | > 99% |
| Offset Commit Max Time | `kafka_connect_connector_task_metrics_offset_commit_max_time_ms` | < 5000ms |
| Offset Commit Failure % | `kafka_connect_connector_task_metrics_offset_commit_failure_percentage` | < 1% |
| Task Pause Ratio | `kafka_connect_connector_task_metrics_pause_ratio` | < 0.1 |

---

## Métriques Producer (Buffer/Backpressure)

### Dashboard : `mm2-detailed-metrics.json`

| Panel | Métrique Prometheus | Seuil |
|-------|---------------------|-------|
| Buffer Total Bytes | `kafka_producer_producer_metrics_buffer_total_bytes` | Config |
| Buffer Available | `kafka_producer_producer_metrics_buffer_available_bytes` | > 30% |
| Buffer Utilization | `100 × (1 - available/total)` | < 70% |
| Buffer Exhausted | `kafka_producer_producer_metrics_buffer_exhausted_total` | 0 |
| Waiting Threads | `kafka_producer_producer_metrics_waiting_threads` | 0 |
| Throttle Time Max | `kafka_producer_producer_metrics_produce_throttle_time_max` | < 100ms |
| Record Error Total | `kafka_producer_producer_metrics_record_error_total` | 0 |
| Record Retry Total | `kafka_producer_producer_metrics_record_retry_total` | Minimal |

---

## Métriques Infrastructure

### Dashboard : `Node-Eporter.json`

| Panel | Métrique Prometheus | Seuil Warning | Seuil Critical |
|-------|---------------------|---------------|----------------|
| CPU Usage | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) × 100)` | > 70% | > 85% |
| Memory Usage | `(1 - node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes) × 100` | > 80% | > 90% |
| Disk Usage | `(1 - node_filesystem_avail_bytes/node_filesystem_size_bytes) × 100` | > 80% | > 90% |
| Network RX | `rate(node_network_receive_bytes_total[5m])` | Baseline +50% | Saturation |
| Network TX | `rate(node_network_transmit_bytes_total[5m])` | Baseline +50% | Saturation |

---

## Méthode de Calibrage des Seuils

### Étape 1 : Mesurer Baseline (S1)

Exécuter le scénario S1 (100 msg/s) et noter :
- Latence moyenne
- Latence max
- CPU moyen

### Étape 2 : Mesurer Nominal (S2)

Exécuter le scénario S2 (1000 msg/s) et noter les mêmes métriques.

### Étape 3 : Calculer les Seuils

```
Seuil Warning = Nominal × 2
Seuil Critical = Warning × 2

Exemple :
  Latence nominale = 200ms
  → Warning = 500ms (arrondi)
  → Critical = 1000ms
```

### Étape 4 : Ajuster selon Contexte

| Facteur | Impact |
|---------|--------|
| Réseau lent (WAN) | Augmenter seuils latence |
| Petits messages | Diminuer seuil throughput records |
| Gros messages | Augmenter seuil throughput bytes |
| Beaucoup de partitions | Augmenter seuil lag |

---

## Requêtes PromQL Utiles

```promql
# Latence moyenne
avg(kafka_connect_mirror_source_connector_replication_latency_ms)

# Latence max
max(kafka_connect_mirror_source_connector_replication_latency_ms_max)

# Lag total
sum(kafka_connect_source_task_metrics_source_record_active_count{connector=~".*MirrorSourceConnector.*"})

# Ratio réplication
sum(kafka_connect_source_task_metrics_source_record_write_total) 
/ sum(kafka_connect_source_task_metrics_source_record_poll_total) * 100

# Throughput records/s
sum(rate(kafka_connect_source_task_metrics_source_record_write_total[1m]))

# Throughput bytes/s
sum(rate(kafka_connect_mirror_source_connector_byte_count[1m]))

# CPU workers
100 - avg(rate(node_cpu_seconds_total{mode="idle",instance=~"kafka-connect.*"}[5m])) * 100

# Buffer utilization
100 * (1 - kafka_producer_producer_metrics_buffer_available_bytes 
       / kafka_producer_producer_metrics_buffer_total_bytes)
```
