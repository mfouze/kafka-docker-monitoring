# Métriques Producer & Consumer - Monitoring Performance Kafka

## Objectif

Documenter les métriques clés disponibles pour le suivi de la performance des producers et consumers Kafka sur les clusters NEMO et Applicatif de Transactis.

---

## Pré-requis

- [x] Dashboards Grafana déployés (`kafka-producer`, `kafka-consumer`)
- [x] JMX Exporter configuré sur les clients Kafka
- [x] Prometheus collectant les métriques
- [x] Observabilité validée (J2)

---

## 1. Dashboards Disponibles

| Dashboard | UID | Description | Usage |
|-----------|-----|-------------|-------|
| Kafka Producer | `kafka-producer` | Métriques Java client producer | Suivi production MM2/Applications |
| Kafka Consumer | `-C-IEldWk2` | Métriques Java client consumer | Suivi consommation MM2/Applications |

**Variables de filtrage disponibles :**
- `env` : Environnement (prod, preprod, test)
- `client_id` : Identifiant du client Kafka
- `instance` : Instance du client
- `topic` : Topic Kafka
- `consumer_group` : Groupe de consommateurs

---

## 2. Métriques Producer - Référentiel Complet

### 2.1 Métriques Clés (Key Metrics)

| Métrique | Description | Seuil Warning | Seuil Critical | Action |
|----------|-------------|---------------|----------------|--------|
| `kafka_producer_producer_metrics_record_retry_rate` | Taux de retry par seconde | > 10/s | > 50/s | Vérifier connectivité brokers |
| `kafka_producer_producer_metrics_record_error` | Taux d'erreurs d'envoi | > 0 | > 1/s | Analyser logs producer |
| `kafka_producer_producer_metrics_buffer_available_bytes` | Buffer mémoire disponible | < 10 MB | < 5 MB | Augmenter buffer.memory |
| `kafka_producer_producer_metrics_produce_throttle_time_avg` | Temps de throttling moyen (ms) | > 0 | > 100 ms | Augmenter quotas broker |
| `kafka_producer_producer_metrics_failed_authentication` | Échecs authentification SASL | > 0 | > 1 | Vérifier credentials |

### 2.2 Métriques de Latence

| Métrique | Description | SLA Transactis | Seuil Critical |
|----------|-------------|----------------|----------------|
| `kafka_producer_producer_metrics_request_latency_avg` | Latence moyenne requête (ms) | < 50 ms | > 200 ms |
| `kafka_producer_producer_metrics_record_queue_time_avg` | Temps en queue (ms) | < 100 ms | > 500 ms |
| `kafka_producer_producer_metrics_bufferpool_wait_ratio` | Ratio d'attente buffer | < 0.1 | > 0.5 |

### 2.3 Métriques de Débit

| Métrique | Description | Nominal | Burst |
|----------|-------------|---------|-------|
| `kafka_producer_producer_metrics_outgoing_byte` | Bytes sortants (rate) | Variable | - |
| `kafka_producer_producer_topic_metrics_byte` | Bytes par topic (rate) | Variable | - |
| `kafka_producer_producer_metrics_record_send` | Records envoyés (rate) | 1000 msg/s | 3000 msg/s |
| `kafka_producer_producer_topic_metrics_record_send_rate` | Records par topic (rate) | Variable | - |
| `kafka_producer_producer_metrics_compression_rate_avg` | Ratio compression | < 0.5 (LZ4) | - |

### 2.4 Métriques de Batching

| Métrique | Description | Optimal | Notes |
|----------|-------------|---------|-------|
| `kafka_producer_producer_metrics_batch_size_avg` | Taille moyenne batch (bytes) | 16-64 KB | Ajuster batch.size |
| `kafka_producer_producer_metrics_record_size_avg` | Taille moyenne record (bytes) | ~1 KB | Selon use case |
| `kafka_producer_producer_metrics_requests_in_flight` | Requêtes en vol | < 5 | Paramètre max.in.flight.requests.per.connection |

### 2.5 Métriques Réseau/IO

| Métrique | Description | Notes |
|----------|-------------|-------|
| `kafka_producer_producer_metrics_request` | Nombre de requêtes (rate) | - |
| `kafka_producer_producer_metrics_request_size_avg` | Taille moyenne requête | - |
| `kafka_producer_producer_metrics_response` | Nombre de réponses (rate) | - |
| `kafka_producer_producer_metrics_connection_count` | Nombre de connexions | - |
| `kafka_producer_producer_metrics_connection_creation_rate` | Taux création connexions | Élevé = problème |
| `kafka_producer_producer_metrics_connection_close_rate` | Taux fermeture connexions | Élevé = problème |
| `kafka_producer_producer_metrics_io_ratio` | Ratio temps IO | - |
| `kafka_producer_producer_metrics_io_wait_ratio` | Ratio attente IO | Élevé = saturation |
| `kafka_producer_producer_metrics_select_rate` | Taux select NIO | - |

### 2.6 Métriques Metadata

| Métrique | Description | Notes |
|----------|-------------|-------|
| `kafka_producer_app_info` | Informations client (version) | Pour inventaire |
| `kafka_producer_producer_metrics_metadata_age` | Âge des métadonnées (s) | < metadata.max.age.ms |

---

## 3. Métriques Consumer - Référentiel Complet

### 3.1 Métriques Clés (Key Metrics)

| Métrique | Description | Seuil Warning | Seuil Critical | Action |
|----------|-------------|---------------|----------------|--------|
| `kafka_consumer_consumer_coordinator_metrics_commit_rate` | Taux de commit offsets | < 0.1/s | 0 | Vérifier auto.commit |
| `kafka_consumer_consumer_fetch_manager_metrics_fetch_throttle_time_avg` | Temps throttling (ms) | > 0 | > 100 ms | Augmenter quotas |
| `kafka_consumer_consumer_metrics_failed_authentication_rate` | Échecs auth SASL | > 0 | > 1 | Vérifier credentials |
| `kafka_consumer_consumer_coordinator_metrics_rebalance_rate_per_hour` | Taux rebalance/heure | > 1 | > 5 | Stabiliser consumers |

### 3.2 Métriques de Lag - CRITIQUES

| Métrique | Description | SLA Transactis | Seuil Critical |
|----------|-------------|----------------|----------------|
| `kafka_server_tenant_metrics_consumer_lag_offsets` | Lag en nombre d'offsets | < 1000 | > 10000 |
| `kafka_consumer_consumer_fetch_manager_records_lag` | Lag records (par partition) | < 100 | > 1000 |
| `kafka_consumer_consumer_fetch_manager_records_lag_max` | Lag max records | < 500 | > 5000 |

### 3.3 Métriques de Débit

| Métrique | Description | Nominal | Notes |
|----------|-------------|---------|-------|
| `kafka_consumer_consumer_fetch_manager_metrics_bytes_consumed` | Bytes consommés (rate) | Variable | - |
| `kafka_consumer_consumer_fetch_manager_metrics_records_consumed` | Records consommés (rate) | >= production | Doit suivre production |

### 3.4 Métriques de Fetch

| Métrique | Description | Optimal | Seuil Critical |
|----------|-------------|---------|----------------|
| `kafka_consumer_consumer_fetch_manager_metrics_fetch_latency_avg` | Latence fetch moyenne (ms) | < 100 ms | > 500 ms |
| `kafka_consumer_consumer_fetch_manager_metrics_fetch_latency_max` | Latence fetch max (ms) | < 500 ms | > 2000 ms |
| `kafka_consumer_consumer_fetch_manager_metrics_fetch_rate` | Taux de fetch | Selon load | - |
| `kafka_consumer_consumer_fetch_manager_metrics_fetch_size_avg` | Taille moyenne fetch | 1-10 MB | - |

### 3.5 Métriques de Poll

| Métrique | Description | Optimal | Action si Dégradé |
|----------|-------------|---------|-------------------|
| `kafka_consumer_consumer_metrics_time_between_poll_avg` | Temps entre polls (ms) | < 500 ms | Optimiser traitement |
| `kafka_consumer_consumer_metrics_poll_idle_ratio_avg` | Ratio idle du poll | > 0.5 | Si < 0.3 = surcharge |

### 3.6 Métriques de Commit

| Métrique | Description | Notes |
|----------|-------------|-------|
| `kafka_consumer_consumer_coordinator_metrics_commit_latency_avg` | Latence commit moyenne | < 100 ms idéal |
| `kafka_consumer_consumer_coordinator_metrics_commit_latency_max` | Latence commit max | - |

---

## 4. Requêtes Prometheus - Transactis

### 4.1 Alertes Producer Recommandées

```yaml
# prometheus/alerts/kafka-producer.yml
groups:
  - name: kafka_producer_alerts
    rules:
      # Taux d'erreur producer élevé
      - alert: KafkaProducerHighErrorRate
        expr: rate(kafka_producer_producer_metrics_record_error[5m]) > 1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Producer {{ $labels.client_id }} - Taux d'erreur élevé"
          description: "Taux d'erreur: {{ $value }} errors/sec"

      # Buffer producer saturé
      - alert: KafkaProducerBufferLow
        expr: kafka_producer_producer_metrics_buffer_available_bytes < 5242880
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Producer {{ $labels.client_id }} - Buffer bas"
          description: "Buffer disponible: {{ $value | humanize1024 }}"

      # Latence producer élevée
      - alert: KafkaProducerHighLatency
        expr: kafka_producer_producer_metrics_request_latency_avg > 200
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Producer {{ $labels.client_id }} - Latence élevée"
          description: "Latence moyenne: {{ $value }}ms"

      # Throttling producer
      - alert: KafkaProducerThrottled
        expr: kafka_producer_producer_metrics_produce_throttle_time_avg > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Producer {{ $labels.client_id }} - Throttling détecté"
          description: "Temps throttle: {{ $value }}ms"
```

### 4.2 Alertes Consumer Recommandées

```yaml
# prometheus/alerts/kafka-consumer.yml
groups:
  - name: kafka_consumer_alerts
    rules:
      # Lag consumer critique
      - alert: KafkaConsumerLagCritical
        expr: sum by (consumer_group, topic) (kafka_consumer_consumer_fetch_manager_records_lag) > 10000
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Consumer {{ $labels.consumer_group }} - Lag critique"
          description: "Lag: {{ $value }} records sur {{ $labels.topic }}"

      # Lag consumer warning
      - alert: KafkaConsumerLagWarning
        expr: sum by (consumer_group, topic) (kafka_consumer_consumer_fetch_manager_records_lag) > 1000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Consumer {{ $labels.consumer_group }} - Lag élevé"
          description: "Lag: {{ $value }} records sur {{ $labels.topic }}"

      # Rebalance fréquent
      - alert: KafkaConsumerFrequentRebalance
        expr: kafka_consumer_consumer_coordinator_metrics_rebalance_rate_per_hour > 5
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Consumer {{ $labels.consumer_group }} - Rebalances fréquents"
          description: "{{ $value }} rebalances/heure"

      # Échec authentication
      - alert: KafkaConsumerAuthFailure
        expr: rate(kafka_consumer_consumer_metrics_failed_authentication_rate[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Consumer {{ $labels.client_id }} - Échec authentification"
```

### 4.3 Requêtes Dashboard Personnalisées

```promql
# Throughput total producers (msg/sec)
sum(rate(kafka_producer_producer_metrics_record_send[1m]))

# Throughput total consumers (msg/sec)
sum(rate(kafka_consumer_consumer_fetch_manager_metrics_records_consumed[1m]))

# Lag total MM2
sum(kafka_consumer_consumer_fetch_manager_records_lag{client_id=~".*mirrormaker.*"})

# Latence end-to-end estimée (producer + consumer)
avg(kafka_producer_producer_metrics_request_latency_avg) +
avg(kafka_consumer_consumer_fetch_manager_metrics_fetch_latency_avg)

# Ratio production/consommation (doit être ~1)
sum(rate(kafka_producer_producer_metrics_record_send[5m])) /
sum(rate(kafka_consumer_consumer_fetch_manager_metrics_records_consumed[5m]))

# Santé globale producers (% sans erreur)
(count(kafka_producer_producer_metrics_record_error == 0) /
 count(kafka_producer_producer_metrics_record_error)) * 100

# Utilisation buffer producers (%)
(1 - (kafka_producer_producer_metrics_buffer_available_bytes / 67108864)) * 100
```

---

## 5. Intégration Tests Performance MM2

### 5.1 Métriques à Capturer Pendant les Tests

| Phase Test | Métriques Producer | Métriques Consumer | Fréquence |
|------------|-------------------|-------------------|-----------|
| PERF-01 Nominal | record_send, request_latency_avg | records_consumed, lag | 15s |
| PERF-02 Montée | record_send, buffer_available | records_consumed, lag | 15s |
| PERF-03 Burst | record_retry_rate, throttle_time | lag, fetch_latency | 5s |
| PERF-04 Endurance | record_error, buffer_wait_ratio | lag_max, rebalance_rate | 60s |
| PERF-06 Latence | request_latency_avg, queue_time | fetch_latency_avg | 1s |

### 5.2 Script Export Métriques Test

```bash
#!/bin/bash
# export-producer-consumer-metrics.sh

PROMETHEUS_HOST="localhost"
PROMETHEUS_PORT="9090"
OUTPUT_DIR="metrics-$(date +%Y%m%d-%H%M%S)"
mkdir -p $OUTPUT_DIR

# Métriques Producer
PRODUCER_METRICS=(
    "kafka_producer_producer_metrics_record_send"
    "kafka_producer_producer_metrics_request_latency_avg"
    "kafka_producer_producer_metrics_record_retry_rate"
    "kafka_producer_producer_metrics_buffer_available_bytes"
    "kafka_producer_producer_metrics_produce_throttle_time_avg"
)

# Métriques Consumer
CONSUMER_METRICS=(
    "kafka_consumer_consumer_fetch_manager_metrics_records_consumed"
    "kafka_consumer_consumer_fetch_manager_records_lag"
    "kafka_consumer_consumer_fetch_manager_metrics_fetch_latency_avg"
    "kafka_consumer_consumer_coordinator_metrics_commit_rate"
)

for metric in "${PRODUCER_METRICS[@]}" "${CONSUMER_METRICS[@]}"; do
    echo "Exporting $metric..."
    curl -s -G "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query_range" \
        --data-urlencode "query=sum(rate(${metric}[1m]))" \
        --data-urlencode "start=$(date -d '-1 hour' +%s)" \
        --data-urlencode "end=$(date +%s)" \
        --data-urlencode "step=15s" \
        -o "$OUTPUT_DIR/${metric}.json"
done

echo "Métriques exportées dans $OUTPUT_DIR/"
```

---

## 6. Seuils SLA Transactis - Récapitulatif

### 6.1 Producer

| Métrique | SLA | Mesure |
|----------|-----|--------|
| Record Send Rate | >= 1000 msg/s nominal | rate(record_send[1m]) |
| Request Latency Avg | < 50 ms | request_latency_avg |
| Error Rate | < 0.1% | record_error / record_send |
| Throttle Time | 0 ms | produce_throttle_time_avg |

### 6.2 Consumer

| Métrique | SLA | Mesure |
|----------|-----|--------|
| Consumer Lag | < 1000 records | sum(records_lag) |
| Fetch Latency | < 100 ms avg | fetch_latency_avg |
| Commit Rate | > 0.1/s | commit_rate |
| Rebalance Rate | < 1/heure | rebalance_rate_per_hour |

### 6.3 End-to-End (MM2)

| Métrique | SLA | Mesure |
|----------|-----|--------|
| Replication Latency | < 500 ms P95 | record_age_ms |
| Throughput Match | >= 99% | consumer_rate / producer_rate |
| Zero Data Loss | 100% | source_count = target_count |

---

## Artifacts Produits

- [x] Référentiel métriques Producer documenté
- [x] Référentiel métriques Consumer documenté
- [x] Alertes Prometheus recommandées
- [x] Requêtes dashboard personnalisées
- [x] Script export métriques

---

**Client** : Transactis
**Dashboards** : kafka-producer, kafka-consumer
**Version** : 1.0
