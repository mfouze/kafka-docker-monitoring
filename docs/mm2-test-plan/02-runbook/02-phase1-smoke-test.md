# Phase 1 : Smoke Test

**Durée** : 15 minutes  
**Objectif** : Valider que la chaîne de réplication fonctionne

---

## Étape 1.1 : Envoi de Messages Test

**Objectif** : Produire 100 messages et vérifier qu'ils traversent MM2

### Variante A - Python Bomber

```bash
cd kafka-consumer-producer/

python kafka_producer_bomber.py \
  --bootstrap-servers "$KAFKA_SOURCE" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --security-protocol SASL_SSL \
  --topic-prefix "test-prometheus" \
  --num-topics 1 \
  --messages-per-second 10 \
  --num-threads 1 \
  --duration-minutes 1
```

### Variante B - kafka-producer-perf-test

```bash
kafka-producer-perf-test.sh \
  --topic "test-prometheus.generated-data-01.json" \
  --num-records 100 \
  --record-size 1024 \
  --throughput 10 \
  --producer-props \
    bootstrap.servers=$KAFKA_SOURCE \
    security.protocol=SASL_SSL \
    sasl.mechanism=PLAIN \
    sasl.jaas.config='org.apache.kafka.common.security.plain.PlainLoginModule required username="$KAFKA_USER" password="$KAFKA_PASS";' \
    acks=all
```

**Résultat attendu** : 100 messages envoyés sans erreur

---

## Étape 1.2 : Vérification Réplication via Grafana

**Dashboard** : `mm2-replication.json`

### Panels à Observer

| Panel | Métrique | Attendu |
|-------|----------|---------|
| **Total Records Polled** | `source_record_poll_total` | +100 après envoi |
| **Total Records Written** | `source_record_write_total` | ≈ poll_total |
| **Replication Ratio** | write/poll × 100 | > 99% |
| **Topics Replicated** | count topics | ≥ 1 |

### PromQL à Exécuter (optionnel)

```promql
# Records pollés
sum(kafka_connect_source_task_metrics_source_record_poll_total{connector=~".*MirrorSourceConnector.*"})

# Records écrits
sum(kafka_connect_source_task_metrics_source_record_write_total{connector=~".*MirrorSourceConnector.*"})
```

**GO** : write_total ≈ poll_total (ratio > 99%)  
**NOGO** : write_total = 0 après 30 secondes

---

## Étape 1.3 : Mesure Latence Baseline

**Dashboard** : `mm2-replication.json`

### Panels à Observer

| Panel | Métrique | Attendu Baseline |
|-------|----------|------------------|
| **Avg Replication Latency** | `replication_latency_ms` avg | < 100 ms |
| **Max Replication Latency** | `replication_latency_ms_max` | < 500 ms |

**Dashboard** : `mm2-detailed-metrics.json`

| Panel | Attendu |
|-------|---------|
| **Active Records (Lag)** | < 100 |
| **Offset Commit Max Time** | < 1000 ms |

### Noter les Valeurs Baseline

| Métrique | Valeur Baseline |
|----------|-----------------|
| Latence moyenne | _______ ms |
| Latence max | _______ ms |
| Lag (active_count) | _______ |

Ces valeurs serviront de référence pour les tests suivants.

**GO** : Latence < 100ms, lag stable  
**NOGO** : Latence > 500ms ou lag croissant

---

## Étape 1.4 : Vérification Consommation sur Target

### Via CLI

```bash
# Compter les messages sur le topic répliqué
kafka-console-consumer.sh \
  --bootstrap-server $KAFKA_TARGET $SECURITY_OPTS \
  --topic "source.test-prometheus.generated-data-01.json" \
  --from-beginning \
  --timeout-ms 30000 \
  2>/dev/null | wc -l

# Attendu : ≈ 100
```

### Via Python Consumer Bomber

```bash
python kafka_consumer_bomber.py \
  --bootstrap-servers "$KAFKA_TARGET" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --topic-prefix "source.test-prometheus" \
  --num-topics 1 \
  --num-consumers 1 \
  --duration-minutes 1 \
  --auto-offset-reset earliest
```

**GO** : Nombre de messages ≈ 100  
**NOGO** : 0 messages ou erreur

---

## Checklist Phase 1

| Étape | Résultat | Notes |
|-------|----------|-------|
| 1.1 Messages produits | ☐ 100 OK ☐ Erreurs | |
| 1.2 poll_total augmente | ☐ GO ☐ NOGO | Valeur: _____ |
| 1.2 write_total ≈ poll | ☐ GO ☐ NOGO | Ratio: ___% |
| 1.3 Latence baseline | ☐ GO ☐ NOGO | Avg: ___ms |
| 1.4 Messages sur target | ☐ GO ☐ NOGO | Count: _____ |

**Phase 1 terminée** : ☐ GO pour Phase 2 ☐ NOGO - diagnostic requis

---

## Si NOGO : Diagnostic

| Symptôme | Cause Probable | Action |
|----------|----------------|--------|
| poll_total = 0 | MM2 ne lit pas le topic | Vérifier config `topics` |
| write = 0, poll > 0 | Erreur écriture target | Vérifier ACL target, logs Connect |
| Latence > 500ms | Réseau lent ou backpressure | Vérifier ping, quotas |
| 0 msg sur target | Topic non créé sur target | Vérifier auto.create ou créer manuellement |
