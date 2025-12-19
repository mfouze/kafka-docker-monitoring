# Phase 7 : Tests de Comportement en Erreur

**Durée** : 30 minutes  
**Objectif** : Documenter le comportement de MM2 face aux erreurs

---

## Test 7.1 : Droits Insuffisants (ACL)

**Objectif** : Vérifier que MM2 gère correctement les erreurs d'autorisation

### Préparation

```bash
# Créer un topic SANS donner les droits à mm2-user
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --create --topic "restricted-topic-test" \
  --partitions 3 --replication-factor 3

# NE PAS ajouter d'ACL pour mm2-user sur ce topic
```

### Exécution

```bash
# Modifier MM2 pour inclure ce topic
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/config \
  -H "Content-Type: application/json" \
  -d '{
    ...
    "topics": "test-prometheus.*|restricted-topic-test",
    ...
  }'
```

### Dashboard : `mm2-detailed-metrics.json`

| Panel | Attendu |
|-------|---------|
| Last Error Timestamp | Récent |
| Task state | RUNNING ou FAILED |

### Vérifier les Logs

```bash
# Chercher l'erreur ACL
kubectl logs -l app=kafka-connect --tail=100 | grep -i "authorization\|denied\|acl"
# OU
grep -i "authorization\|denied" /var/log/kafka-connect/connect.log | tail -10
```

### Comportement Attendu

| Aspect | Attendu | Observé |
|--------|---------|---------|
| Erreur dans logs | Oui, claire | ☐ Oui ☐ Non |
| Autres topics impactés | Non | ☐ Non ☐ Oui |
| Task state | RUNNING | ☐ RUNNING ☐ FAILED |

### Nettoyage

```bash
# Retirer le topic du pattern ou supprimer le topic
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --delete --topic "restricted-topic-test"
```

**GO** : Erreur claire, autres topics non impactés  
**NOGO** : Crash connector ou impact généralisé

---

## Test 7.2 : Topic Absent sur Target

**Objectif** : Vérifier l'auto-création ou la gestion d'erreur

### Préparation

Produire sur un nouveau topic qui n'existe pas encore sur target.

```bash
# Créer un nouveau topic source
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --create --topic "new-topic-autocreate-test" \
  --partitions 6 --replication-factor 3

# Produire un message
echo '{"test":"autocreate"}' | kafka-console-producer.sh \
  --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --topic "new-topic-autocreate-test"
```

### Observation

```bash
# Attendre 1-2 minutes puis vérifier sur target
kafka-topics.sh --bootstrap-server $KAFKA_TARGET $SECURITY_OPTS \
  --describe --topic "source.new-topic-autocreate-test"
```

### Dashboard : `mm2-replication.json`

| Panel | Attendu |
|-------|---------|
| Topics Replicated | +1 |
| Partitions Replicated | +6 |

### Résultat

| Comportement | Observé |
|--------------|---------|
| Topic auto-créé sur target | ☐ Oui ☐ Non |
| RF du topic créé | _____ (devrait = config MM2) |
| Partitions du topic créé | _____ (devrait = source) |
| Message répliqué | ☐ Oui ☐ Non |

### Nettoyage

```bash
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --delete --topic "new-topic-autocreate-test"
kafka-topics.sh --bootstrap-server $KAFKA_TARGET $SECURITY_OPTS \
  --delete --topic "source.new-topic-autocreate-test"
```

**GO** : Topic créé automatiquement avec bonne config  
**NOGO** : Erreur ou mauvaise configuration

---

## Test 7.3 : Ajout de Partitions Dynamique

**Objectif** : Vérifier que MM2 détecte et réplique les nouvelles partitions

### Préparation

```bash
# Noter le nombre actuel de partitions
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --describe --topic "test-prometheus.generated-data-01.json" | grep PartitionCount
```

### Exécution

```bash
# Doubler les partitions
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --alter --topic "test-prometheus.generated-data-01.json" \
  --partitions 24
```

### Dashboard : `kafka-connect-cluster.json`

Observer si un rebalance se produit (nouveaux assignments).

### Dashboard : `mm2-replication.json`

| Panel | Avant | Après (5 min) |
|-------|-------|---------------|
| Partitions Replicated | 12 | 24 |

### Vérification

```bash
# Vérifier sur target après 5 min
kafka-topics.sh --bootstrap-server $KAFKA_TARGET $SECURITY_OPTS \
  --describe --topic "source.test-prometheus.generated-data-01.json" | grep PartitionCount
```

### Résultat

| Métrique | Valeur | Seuil GO |
|----------|--------|----------|
| Temps détection | _____ min | < 5 min |
| Nouvelles partitions sur target | ☐ Oui ☐ Non | Oui |
| Données répliquées | ☐ Oui ☐ Non | Oui |

**GO** : Nouvelles partitions détectées et répliquées < 5 min  
**NOGO** : Partitions ignorées

---

## Checklist Phase 7

| Test | Comportement | Résultat |
|------|--------------|----------|
| 7.1 ACL insuffisantes | ☐ Erreur claire ☐ Crash ☐ Silent | ☐GO ☐NOGO |
| 7.2 Topic absent target | ☐ Auto-créé ☐ Erreur ☐ Autre | ☐GO ☐NOGO |
| 7.3 Ajout partitions | ☐ Détecté <5min ☐ Non détecté | ☐GO ☐NOGO |

**Phase 7 terminée** : ☐ GO pour Phase 8
