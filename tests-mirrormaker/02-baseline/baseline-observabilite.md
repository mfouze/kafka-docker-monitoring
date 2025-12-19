# Baseline Observabilité - Tests MirrorMaker 2 Transactis

## Objectif

Établir une baseline de référence de toutes les métriques d'observabilité avant le démarrage des tests de charge et de résilience. Cette baseline servira de point de comparaison pour mesurer l'impact des tests.

---

## Pré-requis

- [x] Pré-requis techniques validés (`01-prerequis/prerequis-tests.md`)
- [x] Prometheus opérationnel et collectant les métriques (J2)
- [x] Grafana accessible avec les dashboards configurés (J2)
- [ ] Système en état nominal (pas de charge exceptionnelle)

---

## Dashboards Grafana de Référence

| Dashboard | UID | Usage |
|-----------|-----|-------|
| **MM2 Replication Metrics** | `mm2-replication` | Latence, Record Age, Throughput |
| **MM2 Detailed Metrics** | `mm2-detailed-metrics` | Tasks, Errors, Buffer |
| **Kafka Cluster** | `kafka-cluster` | Brokers, Partitions, ISR |
| **Kafka Connect Cluster** | `kafka-connect-cluster` | Workers, Connectors |
| **Node Exporter** | `node-exporter` | CPU, RAM, Disk, Network |
| **ZooKeeper Cluster** | `zookeeper-cluster` | Latence, Sessions |

---

## 1. Conditions de Capture de la Baseline

### 1.1 Fenêtre de Capture

| Paramètre | Valeur |
|-----------|--------|
| Date de début | ___ (à compléter) |
| Date de fin | ___ (à compléter) |
| Durée totale | 24 heures minimum (recommandé: 72h) |
| Période d'analyse | Heures ouvrées + heures creuses |
| Charge applicative | Nominale (production normale) |

### 1.2 État du Système - Vérification via Dashboards

**Dashboard : Kafka Cluster (`kafka-cluster`)**

| Vérification | Résultat Attendu | Résultat Obtenu | Conforme |
|--------------|------------------|-----------------|----------|
| Partitions under-replicated NEMO | 0 | - | [ ] |
| Partitions under-replicated Applicatif | 0 | - | [ ] |
| Brokers UP NEMO | 3 | - | [ ] |
| Brokers UP Applicatif | 3 | - | [ ] |

**Dashboard : MM2 Detailed Metrics (`mm2-detailed-metrics`)**

| Vérification | Résultat Attendu | Résultat Obtenu | Conforme |
|--------------|------------------|-----------------|----------|
| Connecteurs MM2 état | RUNNING | - | [ ] |
| Tâches MM2 état | RUNNING | - | [ ] |
| Tâches FAILED | 0 | - | [ ] |

---

## 2. Métriques Kafka Brokers

### 2.1 Requêtes Prometheus - Cluster NEMO (Source)

```promql
# Messages entrants par seconde (rate sur 5 min)
sum(rate(kafka_server_brokertopicmetrics_messagesinpersec{job="kafka"}[5m]))

# Bytes entrants par seconde
sum(rate(kafka_server_brokertopicmetrics_bytesinpersec{job="kafka"}[5m]))

# Bytes sortants par seconde
sum(rate(kafka_server_brokertopicmetrics_bytesoutpersec{job="kafka"}[5m]))

# Partitions actives par broker
kafka_server_replicamanager_partitioncount{job="kafka"}

# Leaders par broker
kafka_server_replicamanager_leadercount{job="kafka"}

# ISR shrinks (indicateur de problème)
sum(rate(kafka_server_replicamanager_isrshrinkspersec{job="kafka"}[5m]))

# Under-replicated partitions
sum(kafka_server_replicamanager_underreplicatedpartitions{job="kafka"})
```

### 2.2 Tableau Baseline Brokers NEMO (Source)

**Dashboard : Kafka Cluster (`kafka-cluster`)**

| Métrique | Unité | Min | Moyenne | P95 | P99 | Max |
|----------|-------|-----|---------|-----|-----|-----|
| Messages In/sec | msg/s | - | - | - | - | - |
| Bytes In/sec | MB/s | - | - | - | - | - |
| Bytes Out/sec | MB/s | - | - | - | - | - |
| Partitions Count (total) | count | - | - | - | - | - |
| Leader Count (par broker) | count | - | - | - | - | - |
| ISR Shrinks/sec | count/s | - | - | - | - | - |
| Under-replicated Partitions | count | 0 | 0 | 0 | 0 | 0 |

### 2.3 Tableau Baseline Brokers Applicatif (Cible)

| Métrique | Unité | Min | Moyenne | P95 | P99 | Max |
|----------|-------|-----|---------|-----|-----|-----|
| Messages In/sec | msg/s | - | - | - | - | - |
| Bytes In/sec | MB/s | - | - | - | - | - |
| Bytes Out/sec | MB/s | - | - | - | - | - |
| Partitions Count (total) | count | - | - | - | - | - |
| Under-replicated Partitions | count | 0 | 0 | 0 | 0 | 0 |

---

## 3. Métriques MirrorMaker 2

### 3.1 Requêtes Prometheus - MM2

**Dashboard : MM2 Replication Metrics (`mm2-replication`)**

```promql
# Latence de réplication
avg(kafka_connect_mirror_source_connector_replication_latency_ms)

# Age des records
avg(kafka_connect_mirror_source_connector_record_age_ms_avg)

# Throughput records
sum(kafka_connect_mirror_source_connector_record_rate)

# Throughput bytes
sum(kafka_connect_mirror_source_connector_byte_rate)
```

**Dashboard : MM2 Detailed Metrics (`mm2-detailed-metrics`)**

```promql
# Active Records (Lag)
sum(kafka_connect_source_task_metrics_source_record_active_count)

# Tâches actives
kafka_connect_connect_worker_metrics_task_count

# Connecteurs actifs
kafka_connect_connect_worker_metrics_connector_count

# Erreurs
sum(rate(kafka_connect_task_error_metrics_total_errors_logged[5m]))
```

### 3.2 Tableau Baseline MirrorMaker 2

| Métrique | Unité | Min | Moyenne | P95 | P99 | Max | Seuil SLA |
|----------|-------|-----|---------|-----|-----|-----|-----------|
| Replication Latency | ms | - | - | - | - | - | **≤ 1000** |
| Record Age Avg | ms | - | - | - | - | - | **≤ 5000** |
| Active Records (Lag) | records | - | - | - | - | - | **≤ 10000** |
| Record Rate | records/s | - | - | - | - | - | - |
| Byte Rate | MB/s | - | - | - | - | - | - |
| Active Tasks | count | - | - | - | - | - | 3 |
| Active Connectors | count | - | - | - | - | - | 3 |
| Errors Logged/sec | errors/s | 0 | 0 | 0 | 0 | 0 | **0** |

---

## 4. Métriques JVM

### 4.1 Requêtes Prometheus - JVM

```promql
# Heap utilisée
jvm_memory_bytes_used{job="kafka",area="heap"}

# Heap max
jvm_memory_bytes_max{job="kafka",area="heap"}

# Ratio heap utilisée
jvm_memory_bytes_used{area="heap"} / jvm_memory_bytes_max{area="heap"}

# GC time
rate(jvm_gc_collection_seconds_sum[5m])

# GC count
rate(jvm_gc_collection_seconds_count[5m])

# Threads actifs
jvm_threads_current
```

### 4.2 Tableau Baseline JVM - Instances Collocalisées

**Spécifications validées : 4 vCPU / 32 Go RAM / 250 Go Disk / Java 17**
**Architecture : Broker + ZK + Connect + SR collocalisés par instance**

| Instance | Heap Used (GB) | Heap Max (GB) | Heap % | GC Time/min | GC Count/min | Threads |
|----------|----------------|---------------|--------|-------------|--------------|---------|
| NEMO Instance 1 | - | 8 | - | - | - | - |
| NEMO Instance 2 | - | 8 | - | - | - | - |
| NEMO Instance 3 | - | 8 | - | - | - | - |
| Applicatif Instance 1 | - | 8 | - | - | - | - |
| Applicatif Instance 2 | - | 8 | - | - | - | - |
| Applicatif Instance 3 | - | 8 | - | - | - | - |

### 4.3 Répartition Mémoire Recommandée (Instances Collocalisées)

| Composant | Heap Recommandé | Note |
|-----------|-----------------|------|
| Kafka Broker | 8 Go | Principal consommateur |
| Kafka Connect (MM2) | 4 Go | - |
| Schema Registry | 1 Go | - |
| ZooKeeper | 1 Go | - |
| OS + Buffer | ~18 Go | Page cache disque |
| **Total** | **32 Go** | ✅ Validé |

---

## 5. Métriques Système (Node Exporter)

### 5.1 Requêtes Prometheus - Système

**Dashboard : Node Exporter (`node-exporter`)**

```promql
# CPU utilisation
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100)

# Mémoire utilisée %
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disque utilisé %
(1 - (node_filesystem_avail_bytes{mountpoint="/data"} / node_filesystem_size_bytes{mountpoint="/data"})) * 100

# I/O disque (reads)
rate(node_disk_read_bytes_total[5m])

# I/O disque (writes)
rate(node_disk_written_bytes_total[5m])

# Network in
rate(node_network_receive_bytes_total[5m])

# Network out
rate(node_network_transmit_bytes_total[5m])

# Load average
node_load5
```

### 5.2 Tableau Baseline Système - Instances Collocalisées

**Spécifications validées : 4 vCPU / 32 Go RAM / 250 Go Disk / Java 17**
**Architecture : Broker + ZK + Connect + SR collocalisés**

| Instance | CPU % | RAM % | Disk % | Disk Read MB/s | Disk Write MB/s | Net In MB/s | Net Out MB/s | Load 5m |
|----------|-------|-------|--------|----------------|-----------------|-------------|--------------|---------|
| NEMO Instance 1 | - | - | - | - | - | - | - | - |
| NEMO Instance 2 | - | - | - | - | - | - | - | - |
| NEMO Instance 3 | - | - | - | - | - | - | - | - |
| Applicatif Instance 1 | - | - | - | - | - | - | - | - |
| Applicatif Instance 2 | - | - | - | - | - | - | - | - |
| Applicatif Instance 3 | - | - | - | - | - | - | - | - |

**Seuils de référence (instances collocalisées - attention accrue) :**
- CPU : Warning > 60%, Critical > 75% (collocation = charge cumulée)
- RAM : Warning > 75%, Critical > 85% (plusieurs JVM)
- Disk : Warning > 70%, Critical > 85%

---

## 6. Métriques ZooKeeper

### 6.1 Requêtes Prometheus - ZooKeeper

**Dashboard : ZooKeeper Cluster (`zookeeper-cluster`)**

```promql
# Latence moyenne
zk_avg_latency

# Connexions actives
zk_num_alive_connections

# Watchers
zk_numwatches

# Znodes
zk_znodescount

# Outstanding requests
zk_outstanding_requests
```

### 6.2 Tableau Baseline ZooKeeper

| Nœud | Role | Avg Latency (ms) | Connections | Watchers | Znodes | Outstanding Req |
|------|------|------------------|-------------|----------|--------|-----------------|
| ZK NEMO 1 | - | - | - | - | - | - |
| ZK NEMO 2 | - | - | - | - | - | - |
| ZK NEMO 3 | - | - | - | - | - | - |
| ZK Applicatif 1 | - | - | - | - | - | - |
| ZK Applicatif 2 | - | - | - | - | - | - |
| ZK Applicatif 3 | - | - | - | - | - | - |

**Seuil SLA ZooKeeper :** Avg Latency < 10 ms

---

## 7. Valeurs de Référence SLA

### 7.1 Seuils Impératifs (Ne Pas Dépasser)

| Métrique | Seuil MAX SLA | Dashboard | Panel |
|----------|---------------|-----------|-------|
| Latence réplication avg | **≤ 1000 ms** | mm2-replication | Replication Latency |
| Latence réplication max | **≤ 5000 ms** | mm2-replication | Replication Latency Max |
| Active Records (Lag) | **≤ 10000** | mm2-detailed-metrics | Active Records |
| Record Age avg | **≤ 5000 ms** | mm2-replication | Record Age |
| Under-replicated partitions | **0** | kafka-cluster | Under Replicated |
| Offline partitions | **0** | kafka-cluster | Offline Partitions |
| Failed tasks MM2 | **0** | mm2-detailed-metrics | Task Status |
| Producer errors | **0** | mm2-detailed-metrics | Errors |

### 7.2 Calcul Disponibilité Cible

| SLA Cible | Downtime Annuel Max | MTTR Max/incident | Incidents Max/an |
|-----------|---------------------|-------------------|------------------|
| 99.9886% | < 1 heure | ≤ 10 minutes | 6 |

---

## 8. Critères OK / KO

| Critère | Condition OK | Condition KO |
|---------|--------------|--------------|
| Baseline capturée | Données sur 24h minimum | < 24h de données |
| Métriques complètes | Toutes métriques présentes | Métriques manquantes |
| État nominal | URP = 0, Erreurs = 0 | URP > 0 ou erreurs |
| Cohérence données | Pas de gaps > 5 min | Gaps significatifs |

---

## 9. Synthèse Baseline

### 9.1 Résumé Exécutif

| Catégorie | État Nominal Confirmé | Dashboard de Validation | Observations |
|-----------|----------------------|-------------------------|--------------|
| Kafka NEMO | [ ] | kafka-cluster | - |
| Kafka Applicatif | [ ] | kafka-cluster | - |
| MirrorMaker 2 | [ ] | mm2-replication, mm2-detailed-metrics | - |
| JVM | [ ] | (métriques JMX) | - |
| Système | [ ] | node-exporter | - |
| ZooKeeper | [ ] | zookeeper-cluster | - |

### 9.2 Valeurs de Référence pour Comparaison Tests

| Métrique Clé | Baseline | Seuil Warning | Seuil SLA | Dashboard |
|--------------|----------|---------------|-----------|-----------|
| Messages In/sec (NEMO) | - | +50% | +100% | kafka-cluster |
| MM2 Latency avg (ms) | - | > 500 | **> 1000** | mm2-replication |
| MM2 Lag (records) | - | > 5000 | **> 10000** | mm2-detailed-metrics |
| CPU % Brokers | - | > 70% | > 85% | node-exporter |
| Heap % | - | > 80% | > 95% | - |

---

## Artifacts Produits

- [ ] Captures d'écran dashboards Grafana (baseline)
- [ ] Export métriques Prometheus (baseline-YYYYMMDD/)
- [ ] Ce document complété avec les valeurs mesurées

---

**Client** : Transactis
**Confluent Platform** : 7.7.3
**Version** : 2.0
