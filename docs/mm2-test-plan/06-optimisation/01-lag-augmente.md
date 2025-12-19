# Symptôme : Lag Augmente

## Diagnostic

### Dashboard à Consulter

**`mm2-detailed-metrics.json`** → Panel "Active Records (Lag)"

### Vérifier Poll vs Write Rate

```promql
# Poll rate (lecture source)
sum(rate(kafka_connect_source_task_metrics_source_record_poll_total[1m]))

# Write rate (écriture target)
sum(rate(kafka_connect_source_task_metrics_source_record_write_total[1m]))
```

### Interprétation

| Situation | Cause Probable |
|-----------|----------------|
| Poll >> Write | Problème écriture target |
| Poll faible | Problème lecture source |
| Poll = Write mais lag ↑ | Charge > capacité |

---

## Actions Correctives

### Priorité P0 (Immédiat)

| Action | Paramètre | Commande | Risque |
|--------|-----------|----------|--------|
| **Augmenter tasks.max** | +50% | `curl -X PUT .../config -d '{"tasks.max": "8"}'` | Rebalance court |
| **Scale out workers** | Ajouter worker | Déploiement infra | Rebalance |

### Priorité P1 (Court terme)

| Action | Paramètre | Impact |
|--------|-----------|--------|
| **Augmenter partitions source** | `kafka-topics --alter --partitions` | Plus de parallélisme |
| **Optimiser batch producer** | `producer.batch.size=65536` | Meilleur throughput |
| **Réduire linger.ms** | `producer.linger.ms=5` | Moins de buffering |

### Priorité P2 (Moyen terme)

| Action | Paramètre | Impact |
|--------|-----------|--------|
| **Augmenter buffer producer** | `producer.buffer.memory=67108864` | Plus de headroom |
| **Compression plus efficace** | `compression.type=lz4` | Moins de I/O |

---

## Vérifications Complémentaires

### Côté Source

```bash
# Vérifier que le topic source n'a pas de problème
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE --describe --topic YOUR_TOPIC

# Vérifier consumer lag du consumer MM2
kafka-consumer-groups.sh --bootstrap-server $KAFKA_SOURCE \
  --group connect-mm2-source-connector --describe
```

### Côté Target

```bash
# Vérifier les quotas
kafka-configs.sh --bootstrap-server $KAFKA_TARGET --describe \
  --entity-type users --entity-name mm2-user

# Vérifier l'état des brokers target
kafka-broker-api-versions.sh --bootstrap-server $KAFKA_TARGET
```

### Côté Workers

**Dashboard** : `Node-Eporter.json`

| Métrique | Seuil | Action si dépassé |
|----------|-------|-------------------|
| CPU > 85% | Saturation | Scale out |
| Memory > 90% | Near OOM | Augmenter heap |
| Network saturation | Bottleneck | Vérifier NIC |

---

## Procédure de Résolution

```
1. Identifier la cause (Poll vs Write)
   │
   ├─► Poll faible
   │   └─► Vérifier source, ACLs, partitions
   │
   └─► Write faible
       │
       ├─► Quotas target → Augmenter quota
       ├─► CPU saturé → Scale out workers
       ├─► Buffer full → Augmenter buffer
       └─► Tasks insuffisantes → Augmenter tasks.max
```
