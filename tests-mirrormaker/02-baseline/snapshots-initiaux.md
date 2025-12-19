# Snapshots Initiaux - Tests MirrorMaker 2 Transactis

## Objectif

Capturer et archiver l'état complet du système avant les tests pour permettre une comparaison avant/après et faciliter l'analyse en cas de dégradation.

---

## Pré-requis

- [x] Baseline observabilité capturée (`baseline-observabilite.md`)
- [x] Accès SSH aux serveurs validé (cf. `01-prerequis/inventaire-acces.md`)
- [ ] Système en état nominal

---

## 1. Snapshots via Dashboards Grafana

### 1.1 Captures d'Écran à Réaliser

| Dashboard | UID | Période | Fichier Attendu |
|-----------|-----|---------|-----------------|
| MM2 Replication Metrics | mm2-replication | 24h | `baseline-mm2-replication-24h.png` |
| MM2 Detailed Metrics | mm2-detailed-metrics | 24h | `baseline-mm2-detailed-24h.png` |
| Kafka Cluster | kafka-cluster | 24h | `baseline-kafka-cluster-24h.png` |
| Node Exporter | node-exporter | 24h | `baseline-node-exporter-24h.png` |
| ZooKeeper Cluster | zookeeper-cluster | 24h | `baseline-zookeeper-24h.png` |

### 1.2 Annotations Grafana

Créer une annotation pour marquer le début des tests :

**URL Grafana :** `http://localhost:3000`

```bash
# Créer une annotation via API
curl -X POST "http://localhost:3000/api/annotations" \
    -H "Content-Type: application/json" \
    -u admin:admin \
    -d '{
        "dashboardUID": "mm2-replication",
        "time": '$(date +%s000)',
        "tags": ["baseline", "mm2-tests", "transactis"],
        "text": "Baseline capture - Début tests MM2 Transactis"
    }'
```

---

## 2. Inventaire des Configurations

### 2.1 Fichiers de Configuration Kafka

| Fichier | Cluster | Chemin Typique | Capturé |
|---------|---------|----------------|---------|
| server.properties | NEMO Broker 1 | /etc/kafka/server.properties | [ ] |
| server.properties | NEMO Broker 2 | /etc/kafka/server.properties | [ ] |
| server.properties | NEMO Broker 3 | /etc/kafka/server.properties | [ ] |
| server.properties | Applicatif Broker 1 | /etc/kafka/server.properties | [ ] |
| server.properties | Applicatif Broker 2 | /etc/kafka/server.properties | [ ] |
| server.properties | Applicatif Broker 3 | /etc/kafka/server.properties | [ ] |
| kafka_server_jaas.conf | Tous brokers | /etc/kafka/ | [ ] |

### 2.2 Fichiers de Configuration MirrorMaker 2

| Fichier | Worker | Chemin Typique | Capturé |
|---------|--------|----------------|---------|
| connect-distributed.properties | MM2 Worker 1 | /etc/kafka/connect-distributed.properties | [ ] |
| connect-distributed.properties | MM2 Worker 2 | /etc/kafka/connect-distributed.properties | [ ] |
| connect-distributed.properties | MM2 Worker 3 | /etc/kafka/connect-distributed.properties | [ ] |

---

## 3. État des Connecteurs MM2

### 3.1 Capture via API REST Connect

**URL Connect :** `http://<mm2-worker>:8083`

```bash
# Liste des connecteurs et leur état
curl -s http://localhost:8083/connectors?expand=info\&expand=status | jq '.'

# Configuration de chaque connecteur
curl -s http://localhost:8083/connectors/mm2-source-connector/config | jq '.'
curl -s http://localhost:8083/connectors/mm2-checkpoint-connector/config | jq '.'
curl -s http://localhost:8083/connectors/mm2-heartbeat-connector/config | jq '.'

# Plugins disponibles
curl -s http://localhost:8083/connector-plugins | jq '.[].class' | grep -i mirror
```

### 3.2 État Attendu des Connecteurs

| Connecteur | Classe | État | Tasks |
|------------|--------|------|-------|
| MirrorSourceConnector | `org.apache.kafka.connect.mirror.MirrorSourceConnector` | RUNNING | ___ |
| MirrorCheckpointConnector | `org.apache.kafka.connect.mirror.MirrorCheckpointConnector` | RUNNING | 1 |
| MirrorHeartbeatConnector | `org.apache.kafka.connect.mirror.MirrorHeartbeatConnector` | RUNNING | 1 |

---

## 4. État des Topics

### 4.1 Topics Cluster NEMO (Source)

```bash
# Liste des topics
/opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server <nemo-broker>:9093 \
    --command-config client.properties \
    --list

# Détails des topics
/opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server <nemo-broker>:9093 \
    --command-config client.properties \
    --describe
```

### 4.2 Topics Cluster Applicatif (Cible)

Topics répliqués préfixés : `nemo.<topic-source>`

```bash
# Liste des topics répliqués
/opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server <applicatif-broker>:9093 \
    --command-config client.properties \
    --list | grep "^nemo\."
```

### 4.3 Tableau Récapitulatif Topics

| Cluster | Nombre Topics | Topics Répliqués | Topics Internes MM2 |
|---------|---------------|------------------|---------------------|
| NEMO | ___ | N/A | - |
| Applicatif | ___ | ___ | heartbeats, checkpoints |

---

## 5. État des Consumer Groups

### 5.1 Consumer Groups MM2

```bash
# Consumer groups sur NEMO
/opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server <nemo-broker>:9093 \
    --command-config client.properties \
    --list | grep -i mirror

# Détail du consumer group MM2
/opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server <nemo-broker>:9093 \
    --command-config client.properties \
    --describe --group "mirrormaker2-nemo-applicatif"
```

### 5.2 Tableau Consumer Groups Critiques

| Consumer Group | Cluster | State | Lag Total | Membres |
|----------------|---------|-------|-----------|---------|
| mirrormaker2-* | NEMO | ___ | ___ | ___ |
| connect-* | NEMO | ___ | ___ | ___ |
| connect-* | Applicatif | ___ | ___ | ___ |

---

## 6. État des ACLs

### 6.1 ACLs Actuelles

**Constat J1 :** ACLs non configurées (risque identifié)

```bash
# Lister les ACLs sur NEMO
/opt/kafka/bin/kafka-acls.sh \
    --bootstrap-server <nemo-broker>:9093 \
    --command-config admin.properties \
    --list
```

### 6.2 Statut ACLs

| Cluster | ACLs Configurées | Statut |
|---------|------------------|--------|
| NEMO | Non | ❌ À créer |
| Applicatif | Non | ❌ À créer |

**Action requise :** Créer les ACLs avant mise en production (P0)

---

## 7. Snapshot Prometheus

### 7.1 Export des Métriques

```bash
# Requêtes pour snapshot baseline
# Exécuter depuis l'interface Prometheus : http://localhost:9090

# État des targets
curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Alertes actives
curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts'
```

### 7.2 Targets Prometheus Attendus (Validés ✅)

| Job | Targets | Health |
|-----|---------|--------|
| kafka | kafka-broker-1:7070, kafka-broker-2:7070, kafka-broker-3:7070 | ✅ UP |
| kafka-connect | kafka-connect-1:7072, kafka-connect-2:7072, kafka-connect-3:7072 | ✅ UP |
| zookeeper | zookeeper-1:7071, zookeeper-2:7071, zookeeper-3:7071 | ✅ UP |
| schema-registry | schema-registry-1:7073, schema-registry-2:7073, schema-registry-3:7073 | ✅ UP |
| node-exporter | Tous serveurs :9100 | ✅ UP |

---

## 8. Snapshot Système

### 8.1 Informations à Capturer

| Information | Commande | Capturée |
|-------------|----------|----------|
| Hostname | `hostname -f` | [ ] |
| Date/Heure | `date -Iseconds` | [ ] |
| Uptime | `uptime` | [ ] |
| Kernel | `uname -a` | [ ] |
| Mémoire | `free -h` | [ ] |
| Disque | `df -h` | [ ] |
| Processus Java | `ps aux | grep java` | [ ] |
| Ports écoute | `ss -tlnp | grep -E "9092|9093|8083"` | [ ] |

### 8.2 Spécifications Système Transactis (Validées ✅)

| Paramètre | Valeur | Statut |
|-----------|--------|--------|
| **vCPU par instance** | 4 | ✅ Validé |
| **RAM par instance** | 32 Go | ✅ Validé |
| **Disque par instance** | 250 Go | ✅ Validé |
| **Java** | OpenJDK 17 | ✅ Validé |
| **Confluent Platform** | 7.7.3 | ✅ Validé |
| **Architecture** | Collocalisée (Broker + ZK + Connect + SR) | ✅ Validé |
| **JMX Exporters** | Tous fonctionnels | ✅ Validé |
| **Dashboards Grafana** | Tous opérationnels | ✅ Validé |

---

## 9. Validation du Snapshot

### 9.1 Checklist de Validation

| Catégorie | Fichiers Attendus | Capturés | Valides |
|-----------|-------------------|----------|---------|
| Screenshots Grafana | 5 dashboards | [ ] | [ ] |
| Config Kafka NEMO | 3 x server.properties | [ ] | [ ] |
| Config Kafka Applicatif | 3 x server.properties | [ ] | [ ] |
| Config MM2 | connect-distributed.properties | [ ] | [ ] |
| État connecteurs | connectors-state.json | [ ] | [ ] |
| Topics NEMO | topics-describe.txt | [ ] | [ ] |
| Topics Applicatif | topics-describe.txt | [ ] | [ ] |
| Consumer Groups | describe, state | [ ] | [ ] |
| Prometheus targets | targets.json | [ ] | [ ] |

### 9.2 Archivage

| Type de Snapshot | Rétention | Emplacement |
|------------------|-----------|-------------|
| Pre-test | Durée du projet + 6 mois | snapshots/pre-test/ |
| Post-test | Durée du projet + 6 mois | snapshots/post-test/ |

---

## Artifacts Produits

- [ ] Archive snapshot complète (`snapshot-YYYYMMDD-HHMMSS.tar.gz`)
- [ ] Screenshots dashboards Grafana
- [ ] Métadonnées (`metadata.json`)
- [ ] Ce document avec checklist validée

---

**Client** : Transactis
**Confluent Platform** : 7.7.3
**Version** : 2.0
