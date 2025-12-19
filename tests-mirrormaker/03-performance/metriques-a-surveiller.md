# Métriques à Surveiller - Tests de Performance MirrorMaker 2 Transactis

## Objectif

Définir l'ensemble des métriques à monitorer pendant les tests de performance, avec les seuils d'alerte et l'interprétation des valeurs. Toutes les métriques sont visualisables dans les dashboards Grafana existants.

---

## Pré-requis

- [x] Prometheus collectant les métriques Kafka, MM2, JVM, système
- [x] Dashboards Grafana configurés (voir section Dashboards)
- [ ] Baseline établie (`02-baseline/`)

---

## Dashboards Grafana Disponibles

| Dashboard | UID | Usage Principal |
|-----------|-----|-----------------|
| **MM2 Replication Metrics** | `mm2-replication` | Latence, Record Age, Throughput |
| **MM2 Detailed Metrics** | `mm2-detailed-metrics` | Tasks, Errors, Buffer |
| **Kafka Cluster** | `kafka-cluster` | Brokers, Partitions, ISR |
| **Kafka Connect Cluster** | `kafka-connect-cluster` | Workers, Connectors |
| **Kafka Consumer** | `kafka-consumer` | Lag, Throughput |
| **Kafka Topics** | `kafka-topics` | Messages, Bytes |
| **ZooKeeper Cluster** | `zookeeper-cluster` | Latence, Sessions |
| **Node Exporter** | `node-exporter` | CPU, RAM, Disk, Network |

---

## 1. Métriques Critiques MM2 (NIVEAU 1 - SLA)

### 1.1 Latence de Réplication

**Dashboard : MM2 Replication Metrics (mm2-replication)**

| Métrique | Requête Prometheus | Seuil SLA |
|----------|-------------------|-----------|
| **Latence moyenne** | `avg(kafka_connect_mirror_source_connector_replication_latency_ms)` | **≤ 1000 ms** |
| **Latence max** | `max(kafka_connect_mirror_source_connector_replication_latency_ms_max)` | **≤ 5000 ms** |
| **Latence par topic** | `kafka_connect_mirror_source_connector_replication_latency_ms{topic=~"$topic"}` | - |

**Interprétation (seuils dashboard) :**

| Latence Avg | État | Action |
|-------------|------|--------|
| < 100 ms | Vert - Normal | Aucune |
| 100-500 ms | Jaune - Attention | Surveiller |
| 500-1000 ms | Orange - Alerte | Investiguer |
| > 1000 ms | Rouge - **CRITIQUE SLA** | Intervention immédiate |

### 1.2 Age des Records (Fraîcheur)

**Dashboard : MM2 Replication Metrics (mm2-replication)**

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **Age moyen** | `avg(kafka_connect_mirror_source_connector_record_age_ms_avg)` | ≤ 5000 ms |
| **Age max** | `max(kafka_connect_mirror_source_connector_record_age_ms_max)` | ≤ 30000 ms |
| **Age min** | `min(kafka_connect_mirror_source_connector_record_age_ms_min)` | - |

**Interprétation :**

| Age Avg | État | Signification |
|---------|------|---------------|
| < 1000 ms | Vert | Réplication quasi temps réel |
| 1000-5000 ms | Jaune | Léger retard acceptable |
| > 5000 ms | Rouge | Retard significatif |

### 1.3 Lag de Réplication (Active Records)

**Dashboard : MM2 Detailed Metrics (mm2-detailed-metrics)**

| Métrique | Requête Prometheus | Seuil SLA |
|----------|-------------------|-----------|
| **Active Records (Lag)** | `sum(kafka_connect_source_task_metrics_source_record_active_count)` | **≤ 10000** |
| **Ratio réplication** | `100 * sum(source_record_write_total) / sum(source_record_poll_total)` | **≥ 99%** |

**Interprétation :**

| Active Records | État | Action |
|----------------|------|--------|
| < 1000 | Vert | Normal |
| 1000-10000 | Jaune | Surveiller tendance |
| > 10000 | Rouge - **CRITIQUE SLA** | Intervention immédiate |

### 1.4 Throughput Réplication

**Dashboard : MM2 Replication Metrics (mm2-replication)**

| Métrique | Requête Prometheus |
|----------|-------------------|
| **Records/sec total** | `sum(kafka_connect_mirror_source_connector_record_rate)` |
| **Bytes/sec total** | `sum(kafka_connect_mirror_source_connector_byte_rate)` |
| **Records/sec par topic** | `sum by(topic) (kafka_connect_mirror_source_connector_record_rate)` |
| **Total records répliqués** | `sum(kafka_connect_mirror_source_connector_record_count)` |

---

## 2. Métriques Connect/MM2 (NIVEAU 2)

### 2.1 État des Connecteurs

**Dashboard : MM2 Detailed Metrics (mm2-detailed-metrics)**

| Métrique | Requête Prometheus |
|----------|-------------------|
| **Connecteurs actifs** | `count(kafka_connect_connector_status{status="running"})` |
| **Tâches actives** | `kafka_connect_connect_worker_metrics_task_count` |
| **Tâches en échec** | `count(kafka_connect_connector_task_status{status="failed"})` |
| **Startup Success %** | `kafka_connect_connect_worker_metrics_connector_startup_success_percentage * 100` |

**Seuils critiques :**

| Métrique | Attendu | Critique |
|----------|---------|----------|
| Connecteurs RUNNING | 3 | < 3 |
| Tâches FAILED | 0 | > 0 |
| Startup Success % | 100% | < 99% |

### 2.2 Performance Tâches

**Dashboard : MM2 Detailed Metrics (mm2-detailed-metrics)**

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **Offset commit time max** | `kafka_connect_connector_task_metrics_offset_commit_max_time_ms` | < 5000 ms |
| **Offset commit failure %** | `kafka_connect_connector_task_metrics_offset_commit_failure_percentage * 100` | < 10% |
| **Task pause ratio** | `kafka_connect_connector_task_metrics_pause_ratio` | < 0.1 |

### 2.3 Producer MM2 (Backpressure)

**Dashboard : MM2 Detailed Metrics (mm2-detailed-metrics)**

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **Buffer utilization %** | `100 * (1 - buffer_available_bytes / buffer_total_bytes)` | < 70% |
| **Buffer exhausted** | `kafka_producer_producer_metrics_buffer_exhausted_total` | **0** |
| **Waiting threads** | `kafka_producer_producer_metrics_waiting_threads` | 0 |
| **Record errors** | `kafka_producer_producer_metrics_record_error_total` | **0** |
| **Record retries** | `kafka_producer_producer_metrics_record_retry_total` | < 100 |
| **Throttle time max** | `kafka_producer_producer_metrics_produce_throttle_time_max` | < 1000 ms |

---

## 3. Métriques Kafka Brokers (NIVEAU 2)

### 3.1 Santé Cluster

**Dashboard : Kafka Cluster (kafka-cluster)**

| Métrique | Requête Prometheus | Seuil SLA |
|----------|-------------------|-----------|
| **Under-replicated partitions** | `kafka_server_ReplicaManager_UnderReplicatedPartitions` | **0** |
| **Offline partitions** | `kafka_controller_KafkaController_OfflinePartitionsCount` | **0** |
| **Active controller** | `kafka_controller_KafkaController_ActiveControllerCount` | **1** |
| **Brokers UP** | `count(up{job="kafka"} == 1)` | **3** |
| **ISR Shrinks/sec** | `rate(kafka_server_ReplicaManager_IsrShrinksPerSec[5m])` | 0 |

### 3.2 Throughput Brokers

**Dashboard : Kafka Cluster (kafka-cluster)**

| Métrique | Requête Prometheus |
|----------|-------------------|
| **Messages In/sec** | `sum(rate(kafka_server_BrokerTopicMetrics_MessagesInPerSec[1m]))` |
| **Bytes In/sec** | `sum(rate(kafka_server_BrokerTopicMetrics_BytesInPerSec[1m]))` |
| **Bytes Out/sec** | `sum(rate(kafka_server_BrokerTopicMetrics_BytesOutPerSec[1m]))` |

### 3.3 Latence Requêtes

**Dashboard : Kafka Cluster (kafka-cluster)**

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **Produce Latency P99** | `histogram_quantile(0.99, kafka_network_RequestMetrics_TotalTimeMs{request="Produce"})` | < 100 ms |
| **Fetch Latency P99** | `histogram_quantile(0.99, kafka_network_RequestMetrics_TotalTimeMs{request="FetchConsumer"})` | < 100 ms |
| **Request Queue Size** | `kafka_network_RequestChannel_RequestQueueSize` | < 100 |

---

## 4. Métriques ZooKeeper (NIVEAU 3)

**Dashboard : ZooKeeper Cluster (zookeeper-cluster)**

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **Avg latency** | `zk_avg_latency` | < 10 ms |
| **Outstanding requests** | `zk_outstanding_requests` | < 10 |
| **Connections** | `zk_num_alive_connections` | stable |
| **Nodes UP** | `count(up{job="zookeeper"} == 1)` | **3** |

---

## 5. Métriques Système (NIVEAU 2)

**Dashboard : Node Exporter (node-exporter)**

### 5.1 CPU

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **CPU Utilization %** | `100 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100` | < 70% |
| **Load Average 5m** | `node_load5` | < nombre vCPU |

**Interprétation CPU :**

| Utilisation | État | Impact |
|-------------|------|--------|
| < 50% | Vert | Normal |
| 50-70% | Jaune | Acceptable |
| 70-85% | Orange | Latence possible |
| > 85% | Rouge | Saturation |

### 5.2 Mémoire

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **RAM Utilization %** | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` | < 80% |
| **Swap Used** | `node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes` | **0** |

### 5.3 Disque

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **Disk Utilization %** | `rate(node_disk_io_time_seconds_total[1m]) * 100` | < 70% |
| **Disk Await** | Calculé | < 10 ms |
| **Filesystem Available** | `node_filesystem_avail_bytes` | > 20% |

### 5.4 Réseau

| Métrique | Requête Prometheus | Seuil |
|----------|-------------------|-------|
| **Network In** | `rate(node_network_receive_bytes_total[1m])` | - |
| **Network Out** | `rate(node_network_transmit_bytes_total[1m])` | - |
| **Errors** | `rate(node_network_receive_errs_total[1m])` | **0** |
| **Drops** | `rate(node_network_receive_drop_total[1m])` | **0** |

---

## 6. Tableau de Synthèse SLA

### 6.1 Métriques Impératives (NE PAS DÉPASSER)

| Métrique | Seuil MAX SLA | Dashboard |
|----------|---------------|-----------|
| Latence réplication avg | **≤ 1000 ms** | mm2-replication |
| Latence réplication max | **≤ 5000 ms** | mm2-replication |
| Active Records (Lag) | **≤ 10000** | mm2-detailed-metrics |
| Record Age avg | **≤ 5000 ms** | mm2-replication |
| Under-replicated partitions | **0** | kafka-cluster |
| Offline partitions | **0** | kafka-cluster |
| Failed tasks MM2 | **0** | mm2-detailed-metrics |
| Producer errors | **0** | mm2-detailed-metrics |

### 6.2 Tableau de Suivi Tests

| Métrique | Baseline | Test Charge | Test Peak | Verdict |
|----------|----------|-------------|-----------|---------|
| Latence avg (ms) | ___ | ___ | ___ | ⬜ |
| Latence max (ms) | ___ | ___ | ___ | ⬜ |
| Active Records | ___ | ___ | ___ | ⬜ |
| Throughput (rec/s) | ___ | ___ | ___ | ⬜ |
| CPU Brokers % | ___ | ___ | ___ | ⬜ |
| CPU MM2 % | ___ | ___ | ___ | ⬜ |
| RAM % | ___ | ___ | ___ | ⬜ |
| Disk I/O % | ___ | ___ | ___ | ⬜ |

**Légende :** ✅ Conforme | ⚠️ Limite | ❌ Non conforme | ⬜ Non mesuré

---

## 7. Règles d'Alerte Recommandées

```yaml
# alerting_rules.yml
groups:
  - name: mm2-sla-critical
    rules:
      - alert: MM2LatencyCritical
        expr: avg(kafka_connect_mirror_source_connector_replication_latency_ms) > 1000
        for: 2m
        labels:
          severity: critical
          sla: impacted
        annotations:
          summary: "MM2 replication latency exceeds SLA (>1000ms)"

      - alert: MM2LagCritical
        expr: sum(kafka_connect_source_task_metrics_source_record_active_count) > 10000
        for: 1m
        labels:
          severity: critical
          sla: impacted
        annotations:
          summary: "MM2 lag exceeds SLA (>10000 records)"

      - alert: MM2TaskFailed
        expr: count(kafka_connect_connector_task_status{status="failed"}) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "MM2 task failed"

      - alert: KafkaUnderReplicated
        expr: kafka_server_ReplicaManager_UnderReplicatedPartitions > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Kafka has under-replicated partitions"

      - alert: KafkaOfflinePartitions
        expr: kafka_controller_KafkaController_OfflinePartitionsCount > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Kafka has offline partitions"
```

---

## Artifacts Produits

- [x] Dashboards Grafana existants documentés
- [ ] Configuration alerting Prometheus/Alertmanager
- [ ] Tableau de suivi complété par test

---

**Client** : Transactis
**SLA** : < 1h downtime annuel (> 99.989%)
**Version** : 2.0
