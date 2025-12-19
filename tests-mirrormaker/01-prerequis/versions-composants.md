# Versions des Composants - Tests MirrorMaker 2 Transactis

## Objectif

Documenter les versions de tous les composants impliqués dans les tests MirrorMaker 2 pour garantir la compatibilité.

---

## Pré-requis

- [x] Accès SSH aux serveurs validé (cf. `inventaire-acces.md`)
- [x] Droits de lecture sur les fichiers de configuration

---

## 1. Versions Installées - Transactis

### 1.1 Composants Kafka

| Composant | Version Installée | Notes |
|-----------|-------------------|-------|
| **Confluent Platform** | 7.7.3 | Distribution Confluent |
| **Apache Kafka** | 3.7.x (inclus dans CP 7.7.3) | - |
| **Kafka Connect** | 3.7.x | Inclus dans CP |
| **MirrorMaker 2** | 3.7.x | Plugins MM2 intégrés |
| **Schema Registry** | 7.7.3 | 3 instances |

### 1.2 Infrastructure

| Composant | Version | Instances | Notes |
|-----------|---------|-----------|-------|
| **ZooKeeper** | 3.8.x | 3 par cluster | Mode quorum |
| **RedHat Enterprise Linux** | 8.x | Tous serveurs | - |
| **Java (JDK)** | **17** | Tous composants | ✅ OpenJDK 17 validé |

### 1.3 Spécifications Matérielles (Validées)

| Ressource | Valeur | Statut |
|-----------|--------|--------|
| **vCPU** | 4 | ✅ Validé |
| **RAM** | 32 Go | ✅ Validé |
| **Disque** | 250 Go | ✅ Validé |
| **Déploiement** | Collocalisé (Broker + ZK + Connect + SR) | ✅ Validé |

### 1.4 Observabilité

| Composant | Version | Déploiement |
|-----------|---------|-------------|
| **Prometheus** | 2.x | Docker Compose local |
| **Grafana** | 10.x | Docker Compose local |
| **JMX Exporter** | 0.19+ | Agent sur chaque JVM |
| **Node Exporter** | 1.x | Déployé sur chaque VM |

---

## 2. Matrice des Versions par Cluster

### 2.1 Cluster NEMO (Source) - Instances Collocalisées

| Serveur | Kafka | Java | RHEL | Conforme |
|---------|-------|------|------|----------|
| Instance 1 (Broker + ZK + Connect + SR) | 7.7.3 | 17 | 8.x | [x] ✅ |
| Instance 2 (Broker + ZK + Connect + SR) | 7.7.3 | 17 | 8.x | [x] ✅ |
| Instance 3 (Broker + ZK + Connect + SR) | 7.7.3 | 17 | 8.x | [x] ✅ |

### 2.2 Cluster Applicatif (Cible) - Instances Collocalisées

| Serveur | Kafka | Java | RHEL | Conforme |
|---------|-------|------|------|----------|
| Instance 1 (Broker + ZK + Connect + SR) | 7.7.3 | 17 | 8.x | [x] ✅ |
| Instance 2 (Broker + ZK + Connect + SR) | 7.7.3 | 17 | 8.x | [x] ✅ |
| Instance 3 (Broker + ZK + Connect + SR) | 7.7.3 | 17 | 8.x | [x] ✅ |

### 2.3 MirrorMaker 2 Workers (Collocalisés)

| Serveur | Kafka Connect | Java | RHEL | Conforme |
|---------|---------------|------|------|----------|
| MM2 Worker 1 (collocalisé) | 7.7.3 | 17 | 8.x | [x] ✅ |
| MM2 Worker 2 (collocalisé) | 7.7.3 | 17 | 8.x | [x] ✅ |
| MM2 Worker 3 (collocalisé) | 7.7.3 | 17 | 8.x | [x] ✅ |

---

## 3. Plugins MirrorMaker 2

### 3.1 Plugins Requis

| Plugin | Classe | Présent |
|--------|--------|---------|
| MirrorSourceConnector | `org.apache.kafka.connect.mirror.MirrorSourceConnector` | [x] |
| MirrorCheckpointConnector | `org.apache.kafka.connect.mirror.MirrorCheckpointConnector` | [x] |
| MirrorHeartbeatConnector | `org.apache.kafka.connect.mirror.MirrorHeartbeatConnector` | [x] |

### 3.2 Vérification via API REST

```bash
# Vérifier les plugins disponibles
curl -s http://localhost:8083/connector-plugins | jq '.[].class' | grep -i mirror
```

**Résultat attendu :**
```
"org.apache.kafka.connect.mirror.MirrorSourceConnector"
"org.apache.kafka.connect.mirror.MirrorCheckpointConnector"
"org.apache.kafka.connect.mirror.MirrorHeartbeatConnector"
```

---

## 4. Compatibilité Inter-versions

### 4.1 Points de Vigilance

| Vérification | Statut | Notes |
|--------------|--------|-------|
| Version Kafka NEMO = Applicatif | [x] ✅ OK | 7.7.3 partout |
| Version MM2 compatible clusters | [x] ✅ OK | Même distribution |
| Java version homogène | [x] ✅ OK | **Java 17** sur tous les composants |
| ZooKeeper version compatible | [x] ✅ OK | 3.8.x |

### 4.2 Paramètres de Protocole

| Paramètre | Cluster NEMO | Cluster Applicatif | Compatible |
|-----------|--------------|-------------------|------------|
| `inter.broker.protocol.version` | ___ | ___ | [ ] |
| `log.message.format.version` | ___ | ___ | [ ] |

---

## 5. Outils de Test Disponibles

| Outil | Chemin | Version | Disponible |
|-------|--------|---------|------------|
| kafka-producer-perf-test | /opt/kafka/bin/ | 7.7.3 | [x] |
| kafka-consumer-perf-test | /opt/kafka/bin/ | 7.7.3 | [x] |
| kafka-console-producer | /opt/kafka/bin/ | 7.7.3 | [x] |
| kafka-console-consumer | /opt/kafka/bin/ | 7.7.3 | [x] |
| kafka-topics | /opt/kafka/bin/ | 7.7.3 | [x] |
| kafka-consumer-groups | /opt/kafka/bin/ | 7.7.3 | [x] |
| kafka-acls | /opt/kafka/bin/ | 7.7.3 | [x] |

---

## 6. Résumé de Conformité

| Cluster/Composant | Serveurs | Conformes | Actions |
|-------------------|----------|-----------|---------|
| Kafka NEMO | 3 | [x] ✅ | - |
| Kafka Applicatif | 3 | [x] ✅ | - |
| ZooKeeper NEMO | 3 | [x] ✅ | Collocalisé |
| ZooKeeper Applicatif | 3 | [x] ✅ | Collocalisé |
| MirrorMaker 2 | 3 | [x] ✅ | Collocalisé |
| Schema Registry | 3 | [x] ✅ | Collocalisé |
| Observabilité (JMX) | - | [x] ✅ | Fonctionnel |
| Dashboards Grafana | - | [x] ✅ | Fonctionnel |

### 6.1 Architecture Déployée (Collocalisée)

```
┌─────────────────────────────────────────────────────────────────┐
│                    INSTANCE 1, 2, 3 (x6 total)                  │
│                    4 vCPU / 32 Go RAM / 250 Go Disk             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Kafka Broker     │  ZooKeeper   │  Kafka Connect (MM2) │   │
│  │  :9092/9093       │  :2181       │  :8083               │   │
│  │  JMX :7070        │  JMX :7071   │  JMX :7072           │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Schema Registry  │  Node Exporter                      │   │
│  │  :8081            │  :9100                              │   │
│  │  JMX :7073        │                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Artifacts Produits

- [x] Inventaire des versions complété
- [ ] Rapport de conformité signé

---

**Client** : Transactis
**Confluent Platform** : 7.7.3
**Version** : 2.0
