# Section 9 : Tests de Monitoring et Alerting

**Objectif** : Valider que le système de monitoring détecte et alerte sur les incidents  
**Durée estimée** : 2 heures  
**Prérequis** : Stack Prometheus/Grafana opérationnelle, alertes configurées  
**SLA cible** : Détection d'incident < 2 minutes, alerte < 5 minutes

---

## 9.1 Objectifs de cette Section

| Objectif | Description | SLA |
|----------|-------------|-----|
| Détection | Identifier les anomalies rapidement | < 2 min |
| Alerting | Déclencher les alertes appropriées | < 5 min |
| Escalade | Notifier les bonnes équipes | Immédiat |
| Documentation | Contexte suffisant pour diagnostic | Complet |

---

## 9.2 Architecture de Monitoring

### Stack Déployée (Jour 2)

```
┌─────────────────────────────────────────────────────────────┐
│                    MONITORING STACK                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │ JMX Exporter │    │ JMX Exporter │    │ JMX Exporter │   │
│  │ Kafka :9090  │    │ ZK :9090     │    │ Connect :9090│   │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘   │
│         │                   │                   │            │
│         └─────────────┬─────┴───────────────────┘            │
│                       ▼                                      │
│              ┌────────────────┐                              │
│              │   Prometheus   │◄── Scrape 15s                │
│              │   :9090        │                              │
│              └────────┬───────┘                              │
│                       │                                      │
│         ┌─────────────┼─────────────┐                        │
│         ▼             ▼             ▼                        │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐               │
│  │  Grafana   │ │Alertmanager│ │   Logs     │               │
│  │  :3000     │ │  :9093     │ │ (Loki/ELK) │               │
│  └────────────┘ └────────────┘ └────────────┘               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Dashboards Grafana

| Dashboard | Contenu | Refresh |
|-----------|---------|---------|
| Kafka Cluster Overview | Throughput, partitions, ISR | 15s |
| Broker Metrics | CPU, mémoire, I/O par broker | 15s |
| ZooKeeper Metrics | Latence, sessions, quorum | 15s |
| Kafka Connect / MM2 | Lag, tasks, throughput | 15s |
| Infrastructure | Node metrics (CPU, RAM, disk) | 30s |

---

## 9.3 Règles d'Alerte à Valider

### Alertes Critiques (Page Immédiate)

| Alerte | Condition | Seuil | For |
|--------|-----------|-------|-----|
| KafkaBrokerDown | up{job="kafka"} == 0 | 1 broker | 1m |
| KafkaOfflinePartitions | kafka_controller_offlinepartitionscount > 0 | > 0 | 1m |
| KafkaUnderReplicatedPartitions | kafka_server_replicamanager_underreplicatedpartitions > 0 | > 0 | 5m |
| ZookeeperDown | up{job="zookeeper"} == 0 | 1 nœud | 1m |
| ZookeeperQuorumLost | count(up{job="zookeeper"} == 1) < 2 | < 2 | 30s |
| MM2ConnectorFailed | kafka_connect_connector_status != 1 | FAILED | 2m |
| MM2TaskFailed | kafka_connect_task_status{status="failed"} > 0 | > 0 | 2m |

### Alertes Warning (Notification)

| Alerte | Condition | Seuil | For |
|--------|-----------|-------|-----|
| KafkaHighLatency | kafka_network_requestmetrics_totaltimems_p99 > 100 | > 100ms | 5m |
| ZookeeperHighLatency | zk_avg_latency > 50 | > 50ms | 5m |
| MM2HighLag | kafka_connect_mirror_source_replication_latency_ms > 30000 | > 30s | 5m |
| DiskSpaceWarning | node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.2 | < 20% | 10m |
| HighCPU | 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80 | > 80% | 10m |
| ConsumerLagHigh | kafka_consumer_group_lag > 10000 | > 10000 | 5m |

---

## 9.4 Test 9.1 - Validation Détection Broker Down

### Objectif

Vérifier que l'arrêt d'un broker déclenche une alerte en moins de 2 minutes.

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier absence d'alertes actives | ___:___ |
| 2 | Noter l'heure de début | T0: ___:___:___ |
| 3 | Arrêter un broker | ___:___:___ |
| 4 | Observer Prometheus targets | ___:___:___ |
| 5 | Observer déclenchement alerte Alertmanager | ___:___:___ |
| 6 | Vérifier réception notification | ___:___:___ |
| 7 | Redémarrer le broker | ___:___:___ |
| 8 | Vérifier résolution alerte | ___:___:___ |

### Commandes

```bash
# Vérifier alertes actives
curl -s http://alertmanager:9093/api/v1/alerts | jq '.data[] | {alertname, status}'

# Arrêter broker
ssh broker1 "systemctl stop kafka"
T0=$(date +%s)

# Surveiller les alertes
watch -n 5 'curl -s http://alertmanager:9093/api/v1/alerts | jq ".data[] | {alertname, status, startsAt}"'

# Calculer délai
T_ALERT=$(date +%s)
DELAY=$((T_ALERT - T0))
echo "Délai détection: ${DELAY} secondes"
```

### Grille de Résultats

| Métrique | Valeur | SLA | Statut |
|----------|--------|-----|--------|
| Temps détection Prometheus | _____ s | < 30s | ☐ OK |
| Temps déclenchement alerte | _____ s | < 120s | ☐ OK |
| Temps notification reçue | _____ s | < 180s | ☐ OK |
| Temps résolution après restart | _____ s | < 60s | ☐ OK |

### Critères de Succès

- [ ] Alerte KafkaBrokerDown déclenchée < 2 minutes
- [ ] Notification reçue (email/Slack/PagerDuty)
- [ ] Alerte résolue après redémarrage
- [ ] Dashboard Grafana reflète l'état

---

## 9.5 Test 9.2 - Validation Détection ZooKeeper Down

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Arrêter un nœud ZooKeeper follower | T0: ___:___:___ |
| 2 | Observer alerte ZookeeperDown | ___:___:___ |
| 3 | Arrêter un second nœud (perte quorum) | ___:___:___ |
| 4 | Observer alerte ZookeeperQuorumLost | ___:___:___ |
| 5 | Restaurer les nœuds | ___:___:___ |
| 6 | Vérifier résolution alertes | ___:___:___ |

### Grille de Résultats

| Alerte | Temps Déclenchement | SLA | Statut |
|--------|---------------------|-----|--------|
| ZookeeperDown (1 nœud) | _____ s | < 120s | ☐ OK |
| ZookeeperQuorumLost | _____ s | < 60s | ☐ OK |
| Résolution après restauration | _____ s | < 60s | ☐ OK |

---

## 9.6 Test 9.3 - Validation Détection Latence Élevée

### Objectif

Vérifier que les alertes de latence se déclenchent lors de dégradation de performance.

### Procédure

| Étape | Action |
|-------|--------|
| 1 | Mesurer latence baseline |
| 2 | Injecter charge pour augmenter latence |
| 3 | Observer déclenchement alerte KafkaHighLatency |
| 4 | Réduire la charge |
| 5 | Vérifier résolution alerte |

### Script d'Injection de Charge

```bash
# Générer charge élevée pour provoquer latence > 100ms
kafka-producer-perf-test \
  --topic latency-stress \
  --num-records 5000000 \
  --record-size 1024 \
  --throughput -1 \
  --producer.config producer-tls.properties &

# Surveiller latence
watch -n 5 'curl -s "http://prometheus:9090/api/v1/query?query=kafka_network_requestmetrics_totaltimems_p99" | jq ".data.result[0].value[1]"'
```

### Grille de Résultats

| Métrique | Baseline | Sous Charge | Après Réduction |
|----------|----------|-------------|-----------------|
| Latence P99 | _____ ms | _____ ms | _____ ms |
| Alerte déclenchée | Non | ☐ Oui à ___:___ | Non |
| Temps déclenchement | N/A | _____ s | N/A |

---

## 9.7 Test 9.4 - Validation Détection MM2 Failed

### Objectif

Vérifier la détection d'échec des connecteurs MirrorMaker 2.

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier MM2 en état RUNNING | ___:___ |
| 2 | Provoquer échec (ex: pause connecteur + kill task) | ___:___ |
| 3 | Observer alerte MM2ConnectorFailed ou MM2TaskFailed | ___:___ |
| 4 | Restaurer le connecteur | ___:___ |
| 5 | Vérifier résolution | ___:___ |

### Commandes

```bash
# Pause connecteur
curl -X PUT http://connect:8083/connectors/mirror-source/pause

# Forcer échec task (alternative: couper accès source)
iptables -A OUTPUT -d source-broker1 -p tcp --dport 9092 -j DROP

# Surveiller alertes
watch -n 5 'curl -s http://alertmanager:9093/api/v1/alerts | jq ".data[] | select(.labels.alertname | startswith(\"MM2\"))"'
```

### Grille de Résultats

| Alerte | Temps Déclenchement | SLA | Statut |
|--------|---------------------|-----|--------|
| MM2ConnectorFailed | _____ s | < 180s | ☐ OK |
| MM2TaskFailed | _____ s | < 180s | ☐ OK |
| Résolution | _____ s | < 120s | ☐ OK |

---

## 9.8 Test 9.5 - Validation Dashboards Grafana

### Objectif

Vérifier que les dashboards reflètent correctement l'état du système.

### Checklist par Dashboard

#### Kafka Cluster Overview

| Panel | Donnée Affichée | Correct |
|-------|-----------------|---------|
| Messages In/Sec | _____ msg/s | ☐ Oui |
| Bytes In/Sec | _____ MB/s | ☐ Oui |
| Active Controllers | _____ | ☐ Oui |
| Under-Replicated Partitions | _____ | ☐ Oui |
| Offline Partitions | _____ | ☐ Oui |
| ISR Shrinks/Expands | _____ | ☐ Oui |

#### ZooKeeper Metrics

| Panel | Donnée Affichée | Correct |
|-------|-----------------|---------|
| Avg Latency | _____ ms | ☐ Oui |
| Outstanding Requests | _____ | ☐ Oui |
| Alive Connections | _____ | ☐ Oui |
| Leader/Follower Status | _____ | ☐ Oui |

#### Kafka Connect / MM2

| Panel | Donnée Affichée | Correct |
|-------|-----------------|---------|
| Connector Status | _____ | ☐ Oui |
| Task Status | _____ | ☐ Oui |
| Record Send Rate | _____ rec/s | ☐ Oui |
| Replication Lag | _____ ms | ☐ Oui |

#### Infrastructure

| Panel | Donnée Affichée | Correct |
|-------|-----------------|---------|
| CPU Usage per Host | _____% | ☐ Oui |
| Memory Usage | _____ GB | ☐ Oui |
| Disk Usage | _____ GB | ☐ Oui |
| Network I/O | _____ MB/s | ☐ Oui |

---

## 9.9 Test 9.6 - Validation Canaux de Notification

### Objectif

Vérifier que les notifications arrivent sur tous les canaux configurés.

### Canaux à Tester

| Canal | Configuré | Test Envoi | Reçu | Délai |
|-------|-----------|------------|------|-------|
| Email | ☐ Oui | ☐ | ☐ | _____ s |
| Slack | ☐ Oui | ☐ | ☐ | _____ s |
| PagerDuty | ☐ Oui | ☐ | _____ s |
| Webhook | ☐ Oui | ☐ | ☐ | _____ s |

### Test d'Envoi Manuel

```bash
# Envoyer alerte test via Alertmanager API
curl -X POST http://alertmanager:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "test"
    },
    "annotations": {
      "summary": "Test de notification",
      "description": "Ceci est un test du système dalerting"
    },
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d "+5 minutes" +%Y-%m-%dT%H:%M:%SZ)'"
  }]'
```

---

## 9.10 Test 9.7 - Validation Temps de Rétention Métriques

### Objectif

Vérifier que les métriques sont conservées selon la politique définie.

### Configuration Prometheus

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

storage:
  tsdb:
    retention.time: 15d
    retention.size: 50GB
```

### Vérification

```bash
# Vérifier rétention configurée
curl -s http://prometheus:9090/api/v1/status/flags | jq '.data["storage.tsdb.retention.time"]'

# Vérifier données historiques disponibles
curl -s "http://prometheus:9090/api/v1/query_range?query=up{job=\"kafka\"}&start=$(date -d '14 days ago' +%s)&end=$(date +%s)&step=3600" | jq '.data.result | length'
```

### Grille de Résultats

| Métrique | Valeur | Attendu |
|----------|--------|---------|
| Rétention configurée | _____ jours | 15 jours |
| Données disponibles depuis | _____ jours | ≥ 14 jours |
| Espace disque utilisé | _____ GB | < 50 GB |

---

## 9.11 Synthèse des SLOs Monitoring

### Objectifs de Niveau de Service Monitoring

| SLO | Objectif | Mesuré | Statut |
|-----|----------|--------|--------|
| Temps détection incident | < 2 min | _____ min | ☐ OK |
| Temps alerte déclenchée | < 5 min | _____ min | ☐ OK |
| Temps notification reçue | < 6 min | _____ min | ☐ OK |
| Disponibilité monitoring | 99.9% | _____% | ☐ OK |
| Dashboards à jour | < 30s delay | _____ s | ☐ OK |

---

## 9.12 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 9.1 - Détection Broker Down
- [ ] Test 9.2 - Détection ZooKeeper Down
- [ ] Test 9.3 - Détection Latence Élevée
- [ ] Test 9.4 - Détection MM2 Failed
- [ ] Test 9.5 - Dashboards Grafana
- [ ] Test 9.6 - Canaux de Notification
- [ ] Test 9.7 - Rétention Métriques

### Résultat Global Section 9

| Critère | Statut |
|---------|--------|
| Détection < 2 min | ☐ PASS ☐ FAIL |
| Alertes fonctionnelles | ☐ PASS ☐ FAIL |
| Notifications reçues | ☐ PASS ☐ FAIL |
| Dashboards corrects | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests d'Endurance](08-tests-endurance.md)  
**Section suivante** : [Validation SLA Globale](10-validation-sla-globale.md)
