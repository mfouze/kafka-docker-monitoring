# Préparation des Topics de Test

## Configuration Recommandée

| Paramètre | Valeur Test | Valeur Prod | Justification |
|-----------|-------------|-------------|---------------|
| `partitions` | 12 | **À calibrer** | Parallélisme = min(tasks MM2, partitions) |
| `replication.factor` | 3 | 3 | Tolérance 1 broker down |
| `min.insync.replicas` | 2 | 2 | Garantit durabilité avec acks=all |
| `retention.ms` | 86400000 (1j) | Selon besoin | Fenêtre de replay |
| `cleanup.policy` | delete | delete/compact | Selon use case |

---

## Création des Topics de Test

### Variables à Définir

```bash
export KAFKA_SOURCE="kafka-source-1:9092,kafka-source-2:9092,kafka-source-3:9092"
export SECURITY_OPTS="--command-config /path/to/client.properties"
```

### Commandes de Création

```bash
# Créer 10 topics de test
for i in $(seq 1 10); do
  kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
    --create --if-not-exists \
    --topic "test-prometheus.generated-data-$(printf '%02d' $i).json" \
    --partitions 12 \
    --replication-factor 3 \
    --config min.insync.replicas=2 \
    --config retention.ms=86400000 \
    --config cleanup.policy=delete
done
```

### Vérification

```bash
# Vérifier un topic
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --describe --topic "test-prometheus.generated-data-01.json"

# Attendu :
# Topic: test-prometheus.generated-data-01.json
# PartitionCount: 12
# ReplicationFactor: 3
# Configs: min.insync.replicas=2,retention.ms=86400000
```

---

## Configuration MM2 pour Répliquer les Topics de Test

### Vérifier la Configuration Actuelle

```bash
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/config | jq '.["topics"], .["topics.regex"]'
```

### Mettre à Jour si Nécessaire

```bash
# Ajouter le pattern test-prometheus.* au connector
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/config \
  -H "Content-Type: application/json" \
  -d '{
    "connector.class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
    "source.cluster.alias": "source",
    "target.cluster.alias": "target",
    "topics": "test-prometheus.*",
    "tasks.max": "4",
    "replication.factor": "3",
    ... (autres configs existantes)
  }'
```

### Redémarrer les Tasks après Modification

```bash
curl -X POST http://kafka-connect-1:8083/connectors/mm2-source-connector/restart?includeTasks=true
```

---

## Vérification sur le Cluster Target

Après quelques minutes, vérifier que les topics sont créés sur le target :

```bash
kafka-topics.sh --bootstrap-server $KAFKA_TARGET $SECURITY_OPTS \
  --list | grep "source.test-prometheus"

# Attendu : topics préfixés par l'alias source (ex: "source.test-prometheus.generated-data-01.json")
```

---

## Checklist Topics

| Action | Commande | Vérifié |
|--------|----------|---------|
| Topics créés sur source | `kafka-topics.sh --list` | ☐ |
| RF=3, min.isr=2 | `kafka-topics.sh --describe` | ☐ |
| MM2 configuré pour pattern | `curl .../config` | ☐ |
| Topics répliqués sur target | `kafka-topics.sh --list` (target) | ☐ |
