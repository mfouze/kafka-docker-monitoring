# Checklist Environnement

## Cluster Source

| Élément | Valeur | Vérifié |
|---------|--------|---------|
| Version Kafka | _____________ (min: 2.8+, recommandé: 3.x) | ☐ |
| Nombre de brokers | ___ (min: 3 pour production) | ☐ |
| Connectivité depuis MM2 | ☐ Oui ☐ Non | ☐ |
| Latence réseau vers workers | ___ ms | ☐ |

**Commande de vérification** :
```bash
kafka-broker-api-versions.sh --bootstrap-server $KAFKA_SOURCE | head -5
```

---

## Cluster Target

| Élément | Valeur | Vérifié |
|---------|--------|---------|
| Version Kafka | _____________ (doit être >= Source) | ☐ |
| Nombre de brokers | ___ | ☐ |
| Connectivité depuis MM2 | ☐ Oui ☐ Non | ☐ |
| Latence réseau vers workers | ___ ms | ☐ |

---

## Workers Kafka Connect (MM2)

| Élément | Valeur Actuelle | Recommandé | Vérifié |
|---------|-----------------|------------|---------|
| Nombre de workers | ___ | min: 2 pour HA | ☐ |
| RAM par worker | ___ GB | min: 4GB, reco: 8GB+ | ☐ |
| CPU par worker | ___ cores | min: 2, reco: 4+ | ☐ |
| Heap size (KAFKA_HEAP_OPTS) | ___ | "-Xms4G -Xmx4G" | ☐ |
| Version Kafka Connect | ___ | Même que brokers | ☐ |

**Commande de vérification** :
```bash
# Vérifier les workers
curl -s http://kafka-connect-1:8083/ | jq '.version, .commit'
curl -s http://kafka-connect-2:8083/ | jq '.version, .commit'
```

---

## Sécurité

| Élément | Valeur | Vérifié |
|---------|--------|---------|
| Protocole | ☐ SASL_SSL ☐ SASL_PLAINTEXT ☐ SSL ☐ PLAINTEXT | ☐ |
| Mécanisme SASL | ☐ PLAIN ☐ SCRAM-SHA-256 ☐ SCRAM-SHA-512 | ☐ |
| ACL lecture sur Source | ☐ Configurées pour user MM2 | ☐ |
| ACL écriture sur Target | ☐ Configurées pour user MM2 | ☐ |
| Certificats SSL valides | Jusqu'au ___________ | ☐ |

---

## Connecteurs MM2

| Élément | Valeur | Vérifié |
|---------|--------|---------|
| MirrorSourceConnector présent | ☐ Oui ☐ Non | ☐ |
| MirrorCheckpointConnector présent | ☐ Oui ☐ Non | ☐ |
| MirrorHeartbeatConnector présent | ☐ Oui ☐ Non | ☐ |
| Tous les connectors RUNNING | ☐ Oui ☐ Non | ☐ |

**Commande de vérification** :
```bash
# Lister les connecteurs
curl -s http://kafka-connect-1:8083/connectors | jq .

# Vérifier l'état de chaque connecteur
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/status | jq '.connector.state, .tasks[].state'
```

---

## Monitoring

| Élément | URL/Valeur | Vérifié |
|---------|------------|---------|
| Prometheus accessible | http://____________:9090 | ☐ |
| Grafana accessible | http://____________:3000 | ☐ |
| JMX Exporter sur brokers | Port 7070 | ☐ |
| JMX Exporter sur Connect | Port 7072 | ☐ |
| Node Exporter sur workers | Port 9100 | ☐ |
| Dashboards MM2 importés | ☐ mm2-replication ☐ mm2-detailed | ☐ |

**Commande de vérification** :
```bash
# Vérifier que Prometheus scrappe les targets
curl -s http://prometheus:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="kafka-connect") | .health'
```

---

## Résultat Checklist

| Section | Statut |
|---------|--------|
| Cluster Source | ☐ OK ☐ NOK |
| Cluster Target | ☐ OK ☐ NOK |
| Workers Connect | ☐ OK ☐ NOK |
| Sécurité | ☐ OK ☐ NOK |
| Connecteurs MM2 | ☐ OK ☐ NOK |
| Monitoring | ☐ OK ☐ NOK |

**GO pour tests** : ☐ Oui ☐ Non

**Si NOK, points bloquants** :
1. _________________________________________________
2. _________________________________________________
