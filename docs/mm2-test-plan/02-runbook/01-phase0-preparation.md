# Phase 0 : Préparation

**Durée** : 1 heure  
**Objectif** : Valider que l'environnement est prêt pour les tests

---

## Étape 0.1 : Vérification Brokers Source

**Commandes** :
```bash
# Vérifier que tous les brokers sont UP
kafka-broker-api-versions.sh --bootstrap-server $KAFKA_SOURCE 2>&1 | grep -c "id:"
# Attendu : 3 (ou le nombre de brokers)

# Vérifier les topics existants
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE --list | wc -l
```

**Dashboard Grafana** : `kafka-cluster.json`  
**Panels à vérifier** :
- "Online Brokers" = nombre attendu
- "Under Replicated Partitions" = 0
- "Offline Partitions" = 0

**GO** : Tous les brokers UP, 0 URP  
**NOGO** : Broker down ou URP > 0

---

## Étape 0.2 : Vérification Brokers Target

**Commandes** :
```bash
kafka-broker-api-versions.sh --bootstrap-server $KAFKA_TARGET 2>&1 | grep -c "id:"
```

**Dashboard Grafana** : `kafka-cluster.json` (sélectionner cluster target)  
**GO** : Tous les brokers UP

---

## Étape 0.3 : Vérification Workers Kafka Connect

**Commandes** :
```bash
# Vérifier chaque worker
for worker in kafka-connect-1 kafka-connect-2; do
  echo "=== $worker ==="
  curl -s "http://$worker:8083/" | jq -r '.version'
  curl -s "http://$worker:8083/connectors" | jq .
done
```

**Dashboard Grafana** : `kafka-connect-cluster.json`  
**Panels à vérifier** :
- "Workers Online" = nombre attendu (typiquement 2+)
- "Connector Count" > 0
- "Task Count" > 0

**GO** : Tous les workers répondent  
**NOGO** : Worker inaccessible

---

## Étape 0.4 : Vérification État Connecteurs MM2

**Commandes** :
```bash
# Lister les connecteurs
curl -s http://kafka-connect-1:8083/connectors | jq .

# Vérifier l'état de chaque connecteur MM2
for connector in $(curl -s http://kafka-connect-1:8083/connectors | jq -r '.[]' | grep -i mirror); do
  echo "=== $connector ==="
  curl -s "http://kafka-connect-1:8083/connectors/$connector/status" | jq '.connector.state, .tasks[].state'
done
```

**États attendus** :
- `MirrorSourceConnector` : RUNNING
- `MirrorCheckpointConnector` : RUNNING (si configuré)
- `MirrorHeartbeatConnector` : RUNNING (si configuré)
- Toutes les tasks : RUNNING

**Dashboard Grafana** : `kafka-connect-cluster.json`  
**Panels à vérifier** :
- "Connector Status" = tous verts
- "Failed Tasks" = 0

**GO** : Tous RUNNING  
**NOGO** : FAILED ou PAUSED

---

## Étape 0.5 : Créer Topics de Test

Voir `00-prerequis/03-preparation-topics.md` pour les commandes détaillées.

**Résumé** :
```bash
# Créer 10 topics avec RF=3, min.isr=2
for i in $(seq 1 10); do
  kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
    --create --if-not-exists \
    --topic "test-prometheus.generated-data-$(printf '%02d' $i).json" \
    --partitions 12 \
    --replication-factor 3 \
    --config min.insync.replicas=2
done
```

**GO** : Topics créés sans erreur  
**NOGO** : Erreur de création

---

## Étape 0.6 : Configurer MM2 pour Topics de Test

**Commandes** :
```bash
# Vérifier que le pattern inclut test-prometheus
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/config | jq '.topics'

# Si besoin, mettre à jour
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/config \
  -H "Content-Type: application/json" \
  -d @mm2-config.json

# Restart tasks
curl -X POST http://kafka-connect-1:8083/connectors/mm2-source-connector/restart?includeTasks=true
```

**Dashboard Grafana** : `mm2-replication.json`  
**Panels à vérifier** : Après restart, "Topics Replicated" doit augmenter

**GO** : Connector RUNNING après restart  
**NOGO** : FAILED après modification

---

## Checklist Phase 0

| Étape | Résultat | Notes |
|-------|----------|-------|
| 0.1 Brokers source | ☐ GO ☐ NOGO | |
| 0.2 Brokers target | ☐ GO ☐ NOGO | |
| 0.3 Workers Connect | ☐ GO ☐ NOGO | |
| 0.4 Connecteurs MM2 | ☐ GO ☐ NOGO | |
| 0.5 Topics créés | ☐ GO ☐ NOGO | |
| 0.6 MM2 configuré | ☐ GO ☐ NOGO | |

**Phase 0 terminée** : ☐ GO pour Phase 1 ☐ NOGO - corriger d'abord
