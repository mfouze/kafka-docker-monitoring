# Autres Symptômes et Résolutions

## Symptôme : Erreurs Connect Tasks

### Dashboard

**`kafka-connect-cluster.json`** → "Failed Tasks"  
**`mm2-detailed-metrics.json`** → "Last Error Timestamp"

### Diagnostic

```bash
# Voir les logs d'erreur
grep -E "ERROR|Exception" /var/log/kafka-connect/connect.log | tail -50

# État des tasks
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/status | jq '.tasks[] | select(.state != "RUNNING")'

# Trace d'une task failed
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/tasks/0/status | jq '.trace'
```

### Actions par Type d'Erreur

| Erreur | Cause | Action |
|--------|-------|--------|
| `AuthorizationException` | ACL manquantes | Corriger ACLs |
| `TimeoutException` | Réseau/broker lent | Augmenter timeouts |
| `RecordTooLargeException` | Message > max.request.size | Augmenter limite |
| `OutOfMemoryError` | Heap insuffisante | Augmenter KAFKA_HEAP_OPTS |
| `RebalanceInProgress` (fréquent) | Instabilité | Augmenter session.timeout.ms |
| `UnknownTopicOrPartition` | Topic absent | Vérifier existence |

---

## Symptôme : Under-Replicated Partitions (URP)

### Dashboard

**`kafka-cluster.json`** → "Under Replicated Partitions"

### Diagnostic

```bash
# Lister URP
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE \
  --describe --under-replicated-partitions

# Vérifier état brokers
for broker in kafka-broker-{1,2,3}; do
  echo "=== $broker ==="
  ssh $broker "df -h /var/kafka-logs; free -m"
done
```

### Actions

| Priorité | Action | Commande |
|----------|--------|----------|
| **P0** | Vérifier espace disque | `df -h` |
| **P0** | Redémarrer broker lent | `systemctl restart kafka` |
| **P1** | Réassigner partitions | `kafka-reassign-partitions.sh` |

---

## Symptôme : GC Pauses Longues

### Dashboard

**`Node-Eporter.json`** ou JMX Exporter pour GC

### Diagnostic

```bash
# Analyser GC logs
grep "GC pause" /var/log/kafka-connect/gc.log | tail -20

# Vérifier heap usage
jstat -gc $(pgrep -f kafka-connect) 1000 5
```

### Actions

| Priorité | Action | Paramètre |
|----------|--------|-----------|
| **P0** | Augmenter heap | `KAFKA_HEAP_OPTS="-Xms8G -Xmx8G"` |
| **P1** | Tuning G1GC | `-XX:MaxGCPauseMillis=200` |
| **P1** | Réduire batch si trop gros | `batch.size=32768` |

---

## Symptôme : I/O Disque Saturée

### Dashboard

**`Node-Eporter.json`** → Panels Disk I/O

### Diagnostic

```bash
# I/O wait
iostat -x 1 5 | grep -E "Device|sd"

# Espace utilisé
du -sh /var/kafka-logs/*
```

### Actions

| Priorité | Action |
|----------|--------|
| **P0** | Identifier topic/partition hot |
| **P0** | Ajouter stockage ou SSD |
| **P1** | Activer compression |
| **P1** | Réduire retention |

---

## Symptôme : Rebalances Fréquents

### Dashboard

**`kafka-connect-cluster.json`** → "Rebalance Count"

### Diagnostic

```bash
# Logs de rebalance
grep -i "rebalance" /var/log/kafka-connect/connect.log | tail -20
```

### Causes et Actions

| Cause | Symptôme | Action |
|-------|----------|--------|
| Session timeout | Tasks timeout | Augmenter `session.timeout.ms` |
| Heartbeat lent | Network issues | Vérifier réseau |
| GC pause | Long GC | Tuning JVM |
| Worker instable | Crash/restart | Vérifier ressources |

```bash
# Augmenter timeouts
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/config \
  -d '{
    "consumer.session.timeout.ms": "60000",
    "consumer.heartbeat.interval.ms": "10000",
    ...
  }'
```

---

## Tableau de Priorités

| Symptôme | Impact | Priorité |
|----------|--------|----------|
| Tasks FAILED | Réplication arrêtée | **P0** |
| Lag croissant rapide | Risque perte | **P0** |
| URP | Durabilité compromise | **P0** |
| Latence > SLO | Impact métier | **P0** |
| Lag croissant lent | Dégradation | **P1** |
| GC pauses | Latence spikes | **P1** |
| Rebalances fréquents | Perturbations | **P1** |
| CPU élevé | Limite proche | **P2** |
| Memory élevée | Limite proche | **P2** |
