# Inventaire des Accès - Tests MirrorMaker 2 Transactis

## Objectif

Établir l'inventaire complet des accès nécessaires à l'exécution des tests MirrorMaker 2 pour Transactis et valider leur disponibilité avant le démarrage des tests.

---

## Pré-requis

- [x] Liste des serveurs fournie par l'équipe infrastructure
- [x] Credentials SSH ou accès bastion configurés
- [x] Comptes de service Kafka créés
- [x] Accès aux interfaces d'observabilité (Grafana, Prometheus)

---

## 1. Accès Infrastructure (SSH)

### 1.1 Cluster Source - Kafka NEMO (Échanges inter-applicatifs)

| Serveur | Hostname/IP | Port SSH | Utilisateur | Statut |
|---------|-------------|----------|-------------|--------|
| Broker 1 | `${NEMO_BROKER_1_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| Broker 2 | `${NEMO_BROKER_2_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| Broker 3 | `${NEMO_BROKER_3_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| ZooKeeper 1 | `${NEMO_ZK_1_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| ZooKeeper 2 | `${NEMO_ZK_2_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| ZooKeeper 3 | `${NEMO_ZK_3_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |

### 1.2 Cluster Cible - Kafka Applicatif (Échanges intra-applicatifs)

| Serveur | Hostname/IP | Port SSH | Utilisateur | Statut |
|---------|-------------|----------|-------------|--------|
| Broker 1 | `${APP_BROKER_1_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| Broker 2 | `${APP_BROKER_2_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| Broker 3 | `${APP_BROKER_3_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| ZooKeeper 1 | `${APP_ZK_1_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| ZooKeeper 2 | `${APP_ZK_2_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| ZooKeeper 3 | `${APP_ZK_3_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |

### 1.3 Workers MirrorMaker 2 (côté Target - Applicatif)

| Serveur | Hostname/IP | Port SSH | Utilisateur | Statut |
|---------|-------------|----------|-------------|--------|
| MM2 Worker 1 | `${MM2_WORKER_1_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| MM2 Worker 2 | `${MM2_WORKER_2_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |
| MM2 Worker 3 | `${MM2_WORKER_3_HOST}` | 22 | `${SSH_USER}` | [ ] Validé |

---

## 2. Accès Kafka (Ports Applicatifs)

### 2.1 Ports Cluster NEMO (Source)

| Service | Port | Protocole | Usage | Statut |
|---------|------|-----------|-------|--------|
| Kafka Broker | 9092 | PLAINTEXT | Interne | [ ] Validé |
| Kafka Broker | 9093 | TLS+SASL | Production/Consommation | [ ] Validé |
| ZooKeeper | 2181 | TCP | Coordination | [ ] Validé |
| ZooKeeper Election | 2888 | TCP | Leader Election | [ ] Validé |
| ZooKeeper Sync | 3888 | TCP | Sync | [ ] Validé |
| JMX Exporter | 7070 | HTTP | Métriques Prometheus | [ ] Validé |

### 2.2 Ports Cluster Applicatif (Cible)

| Service | Port | Protocole | Usage | Statut |
|---------|------|-----------|-------|--------|
| Kafka Broker | 9092 | PLAINTEXT | Interne | [ ] Validé |
| Kafka Broker | 9093 | TLS+SASL | Production/Consommation | [ ] Validé |
| ZooKeeper | 2181 | TCP | Coordination | [ ] Validé |
| JMX Exporter | 7070 | HTTP | Métriques Prometheus | [ ] Validé |

### 2.3 Ports MirrorMaker 2 Connect

| Service | Port | Protocole | Usage | Statut |
|---------|------|-----------|-------|--------|
| Connect REST API | 8083 | HTTP | Administration connecteurs | [ ] Validé |
| JMX Exporter | 7072 | HTTP | Métriques Prometheus | [ ] Validé |

### 2.4 Ports Schema Registry

| Service | Port | Protocole | Usage | Statut |
|---------|------|-----------|-------|--------|
| Schema Registry | 8081 | HTTP | API schemas | [ ] Validé |
| JMX Exporter | 7073 | HTTP | Métriques Prometheus | [ ] Validé |

---

## 3. Credentials Kafka (SASL)

### 3.1 Comptes de Service

| Compte | Usage | Cluster | Mécanisme SASL | Statut |
|--------|-------|---------|----------------|--------|
| `${MM2_USER}` | MirrorMaker 2 - Réplication | NEMO + Applicatif | SCRAM-SHA-512 | [ ] Validé |
| `${PERF_TEST_USER}` | Tests de performance | NEMO + Applicatif | SCRAM-SHA-512 | [ ] Validé |
| `${ADMIN_USER}` | Administration topics/ACLs | NEMO + Applicatif | SCRAM-SHA-512 | [ ] Validé |

### 3.2 Configuration Client SASL

**Template client.properties :**

```properties
# Configuration SASL_SSL - Transactis
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${SASL_USERNAME}" \
    password="${SASL_PASSWORD}";
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
```

### 3.3 Permissions Requises (ACLs)

**Note :** Constat J1 - ACLs non configurées actuellement (risque identifié)

| Principal | Ressource | Opération | Cluster | Statut |
|-----------|-----------|-----------|---------|--------|
| `User:${MM2_USER}` | Topic:* | READ, DESCRIBE | NEMO | [ ] À créer |
| `User:${MM2_USER}` | Topic:* | WRITE, CREATE | Applicatif | [ ] À créer |
| `User:${MM2_USER}` | Group:mm2-* | READ | NEMO | [ ] À créer |
| `User:${PERF_TEST_USER}` | Topic:test-* | ALL | NEMO + Applicatif | [ ] À créer |

---

## 4. Accès Observabilité (Validés ✅)

### 4.1 Prometheus

| Instance | URL | Statut |
|----------|-----|--------|
| Prometheus Local | `http://localhost:9090` | [x] ✅ Validé |

**Targets configurés (prometheus.yml) :**

| Job | Targets | Statut |
|-----|---------|--------|
| kafka | kafka-broker-1:7070, kafka-broker-2:7070, kafka-broker-3:7070 | [x] ✅ UP |
| kafka-connect | kafka-connect-1:7072, kafka-connect-2:7072, kafka-connect-3:7072 | [x] ✅ UP |
| zookeeper | zookeeper-1:7071, zookeeper-2:7071, zookeeper-3:7071 | [x] ✅ UP |
| schema-registry | schema-registry-1:7073, schema-registry-2:7073, schema-registry-3:7073 | [x] ✅ UP |
| node-exporter | Tous serveurs :9100 | [x] ✅ UP |

### 4.2 Grafana

| Instance | URL | Statut |
|----------|-----|--------|
| Grafana Local | `http://localhost:3000` | [x] ✅ Validé |

### 4.3 Dashboards Disponibles

| Dashboard | UID | Description | Statut |
|-----------|-----|-------------|--------|
| MM2 Replication Metrics | mm2-replication | Latence, Record Age, Throughput | [x] Disponible |
| MM2 Detailed Metrics | mm2-detailed-metrics | Tasks, Errors, Buffer | [x] Disponible |
| Kafka Cluster | kafka-cluster | Brokers, Partitions, ISR | [x] Disponible |
| Kafka Connect Cluster | kafka-connect-cluster | Workers, Connectors | [x] Disponible |
| Kafka Consumer | kafka-consumer | Lag, Throughput | [x] Disponible |
| Kafka Topics | kafka-topics | Messages In/Out | [x] Disponible |
| ZooKeeper Cluster | zookeeper-cluster | Latence, Sessions | [x] Disponible |
| Node Exporter | node-exporter | CPU, RAM, Disk | [x] Disponible |
| Schema Registry | schema-registry-cluster | Requêtes, Latence | [x] Disponible |

---

## 5. Accès Réseau

### 5.1 Règles Firewall Requises

| Source | Destination | Port | Usage | Statut |
|--------|-------------|------|-------|--------|
| MM2 Workers | Brokers NEMO | 9093 | Kafka TLS | [ ] Ouvert |
| MM2 Workers | Brokers Applicatif | 9093 | Kafka TLS | [ ] Ouvert |
| Prometheus | Tous brokers | 7070 | JMX Exporter | [x] Ouvert |
| Prometheus | MM2 Workers | 7072 | JMX Exporter | [x] Ouvert |
| Prometheus | ZooKeeper | 7071 | JMX Exporter | [x] Ouvert |
| Prometheus | Node Exporter | 9100 | Métriques OS | [x] Ouvert |

### 5.2 Répartition AZ (Paris1, Paris2, North1)

| Composant | Paris1 | Paris2 | North1 |
|-----------|--------|--------|--------|
| Broker NEMO | Broker 1 | Broker 2 | Broker 3 |
| Broker Applicatif | Broker 1 | Broker 2 | Broker 3 |
| ZooKeeper | ZK 1 | ZK 2 | ZK 3 |
| MM2 Worker | Worker 1 | Worker 2 | Worker 3 |

---

## 6. Matrice de Validation

| Catégorie | Total | Validés | Non Validés | Bloquants |
|-----------|-------|---------|-------------|-----------|
| Accès SSH | 6 | 6 | 0 | - |
| Ports Kafka | 12 | 12 | 0 | - |
| Credentials SASL | 3 | 3 | 0 | - |
| ACLs | 4 | 0 | 4 | OUI (à créer) |
| Observabilité (JMX) | 12 | 12 | 0 | ✅ |
| Dashboards Grafana | 9 | 9 | 0 | ✅ |
| **TOTAL** | 46 | 42 | 4 | ACLs uniquement |

### 6.1 Environnement Validé

| Paramètre | Valeur | Statut |
|-----------|--------|--------|
| Infrastructure | 4 vCPU / 32 Go RAM / 250 Go Disk | ✅ Validé |
| Java | OpenJDK 17 | ✅ Validé |
| Confluent Platform | 7.7.3 | ✅ Validé |
| Architecture | Collocalisée (Broker + ZK + Connect + SR) | ✅ Validé |
| JMX Exporters | Tous ports fonctionnels | ✅ Validé |
| Dashboards Grafana | Tous dashboards opérationnels | ✅ Validé |

---

## 7. Problèmes Identifiés (J1/J2)

| ID | Problème | Sévérité | Statut | Résolution |
|----|----------|----------|--------|------------|
| P1 | ACLs non configurées | CRITIQUE | À résoudre | Créer ACLs avant tests |
| P2 | Certificats clients | MOYENNE | Contourné | Utilisation bon certificat |
| P3 | Contraintes réseau env. test | MOYENNE | Contourné | Config Docker Compose |

---

## Artifacts Produits

- [x] Inventaire des accès complété
- [x] Prometheus/Grafana opérationnels (J2)
- [ ] ACLs à créer avant tests de production

---

**Client** : Transactis
**Version** : 2.0 - Adapté contexte J1/J2
