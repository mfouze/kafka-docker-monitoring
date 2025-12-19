# Contexte et Hypothèses - Tests MirrorMaker 2 Transactis

## Objectif

Documenter le contexte technique, les contraintes projet et les hypothèses de travail servant de base à l'ensemble du plan de tests MirrorMaker 2 pour **Transactis**.

---

## 1. Contexte Projet

### 1.1 Mission d'Audit

| Lot | Description | Durée |
|-----|-------------|-------|
| Lot 1 | Validation de l'architecture Kafka MirrorMaker | 0.5 jour |
| Lot 2 | Audit de l'implémentation MirrorMaker 2 | 0.5 jour |
| Lot 3 | Tests de performance et de résilience | 1 jour |
| Lot 4 | Documentation et recommandations | 1 jour |

**Contrainte SLA cible** : Moins de 1 heure de downtime annuel (disponibilité > 99.989%)

### 1.2 Description de l'Architecture

| Composant | Description |
|-----------|-------------|
| **Cluster Source** | Kafka NEMO - Échanges inter-applicatifs |
| **Cluster Cible** | Kafka Applicatif - Échanges intra-applicatifs |
| **Mode de réplication** | MirrorMaker 2 (Connect-based) - **MODE CIBLE** |
| **Mode actuel** | MirrorMaker 2 Standalone (connect-mirror-maker.sh) - **SPOF identifié** |
| **Coordination** | ZooKeeper (1 ensemble de 3 nœuds par cluster) |
| **Sécurité** | TLS + SASL (SCRAM-SHA-512) |
| **Plateforme** | VM RedHat Enterprise Linux 8.x |
| **Version Kafka** | Confluent Platform 7.7.3 |

### 1.3 Spécifications Matérielles par Instance (Validées ✅)

| Paramètre | Valeur | Statut |
|-----------|--------|--------|
| Nombre de brokers | 3 par cluster | ✅ Validé |
| RAM par instance | **32 Go** | ✅ Validé |
| vCPU par instance | **4** | ✅ Validé |
| Espace disque | **250 Go** | ✅ Validé |
| Java | **OpenJDK 17** | ✅ Validé |
| Déploiement | **Collocalisé** (Broker + ZK + Connect + SR) | ✅ Validé |

### 1.4 Topologie Réseau

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLUSTER SOURCE - KAFKA NEMO                               │
│                    (Échanges inter-applicatifs)                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                          │
│  │  Broker 1   │  │  Broker 2   │  │  Broker 3   │   (3 brokers)            │
│  │  :9092/9093 │  │  :9092/9093 │  │  :9092/9093 │                          │
│  └─────────────┘  └─────────────┘  └─────────────┘                          │
│         │               │               │                                    │
│  ┌──────┴───────────────┴───────────────┴──────┐                            │
│  │      ZooKeeper Ensemble (3 nœuds)           │                            │
│  │              :2181 / :2888 / :3888          │                            │
│  └──────────────────────────────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Réseau : Interne Transactis
                                    │ Répartition : 3 AZ (Paris1, Paris2, North1)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MIRRORMAKER 2 CONNECT CLUSTER                             │
│                    (Déployé côté Target - Best Practice)                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │  MM2 Worker 1   │  │  MM2 Worker 2   │  │  MM2 Worker 3   │              │
│  │    :8083        │  │    :8083        │  │    :8083        │              │
│  │  JMX :7072      │  │  JMX :7072      │  │  JMX :7072      │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
│                                                                              │
│  Connecteurs MM2 :                                                           │
│  ├── MirrorSourceConnector (réplication données)                            │
│  ├── MirrorCheckpointConnector (sync offsets consumer groups)               │
│  └── MirrorHeartbeatConnector (détection vivacité)                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 CLUSTER CIBLE - KAFKA APPLICATIF                             │
│                 (Échanges intra-applicatifs)                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                          │
│  │  Broker 1   │  │  Broker 2   │  │  Broker 3   │   (3 brokers)            │
│  │  :9092/9093 │  │  :9092/9093 │  │  :9092/9093 │                          │
│  └─────────────┘  └─────────────┘  └─────────────┘                          │
│         │               │               │                                    │
│  ┌──────┴───────────────┴───────────────┴──────┐                            │
│  │      ZooKeeper Ensemble (3 nœuds)           │                            │
│  │              :2181 / :2888 / :3888          │                            │
│  └──────────────────────────────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.5 Composants Observabilité Déployés (Validés ✅)

| Composant | Instances | Port JMX/Metrics | Statut |
|-----------|-----------|------------------|--------|
| Kafka Brokers | 3 | :7070 | ✅ Opérationnel |
| ZooKeeper | 3 | :7071 | ✅ Opérationnel |
| Kafka Connect (MM2) | 3 | :7072 | ✅ Opérationnel |
| Schema Registry | 3 | :7073 | ✅ Opérationnel |
| Node Exporter | N | :9100 | ✅ Opérationnel |
| **Dashboards Grafana** | - | - | ✅ Opérationnel |

### 1.6 Stack Monitoring

| Outil | Rôle | Déploiement |
|-------|------|-------------|
| Prometheus | Collecte métriques | Docker Compose local (scrape distant) |
| Grafana | Visualisation | Docker Compose local |
| JMX Exporter | Exposition métriques JVM | Agent sur chaque composant |
| Node Exporter | Métriques OS | Déployé sur chaque VM |

---

## 2. Exigence SLA Client

### 2.1 Définition du SLA

| Métrique | Valeur Contractuelle | Calcul |
|----------|---------------------|--------|
| **Disponibilité annuelle** | > 99.989% | (525600 - 60) / 525600 |
| **Temps maximal d'indisponibilité** | < 60 minutes / an | Cumul tous incidents |
| **Budget mensuel** | < 5 minutes | 60 min / 12 mois |

### 2.2 Seuils Critiques - NE PAS DÉPASSER

Ces seuils sont **impératifs** pour respecter le SLA < 1h annuel :

| Métrique | Seuil MAXIMUM | Justification |
|----------|---------------|---------------|
| **MTTR par incident** | ≤ 10 minutes | Permet ~6 incidents/an |
| **RPO (perte données)** | ≤ 60 secondes | Transactions financières |
| **RTO (restauration)** | ≤ 5 minutes | Continuité service |
| **Lag réplication** | ≤ 30 secondes | Cohérence données |
| **Latence E2E MM2** | ≤ 1000 ms | Performance acceptable |
| **Latence E2E P99** | ≤ 5000 ms | Pic de charge |

### 2.3 Traduction en Objectifs de Test

| Scénario de Panne | MTTR Max | RPO Max | Validation |
|-------------------|----------|---------|------------|
| Panne 1 broker source | ≤ 30 sec | 0 msg | Auto-failover |
| Panne 1 worker MM2 | ≤ 60 sec | ≤ 1000 msg | Rebalancing Connect |
| Panne 1 broker cible | ≤ 30 sec | 0 msg | Reconnexion producer |
| Panne 1 ZK (quorum OK) | 0 sec | 0 msg | Continuité |
| Panne réseau 30 sec | ≤ 60 sec | ≤ 5000 msg | Reconnexion auto |
| Rolling restart brokers | ≤ 120 sec total | 0 msg | Maintenance planifiée |

### 2.4 Budget d'Indisponibilité Annuel

```
Budget annuel total : 60 minutes (3600 secondes)

Répartition recommandée :
├── Incidents non planifiés : 40 minutes
│   ├── Pannes broker (max 4 x 5min) : 20 min
│   ├── Pannes MM2 (max 4 x 3min) : 12 min
│   └── Incidents réseau (max 2 x 4min) : 8 min
└── Maintenances planifiées : 20 minutes
    ├── Rolling restart trimestriel (4 x 3min) : 12 min
    ├── Rotations certificats (2 x 2min) : 4 min
    └── Marge sécurité : 4 min
```

---

## 3. Constats Jour 1 & Jour 2

### 3.1 Écarts Identifiés (Criticité)

| # | Constat | Impact | Criticité | Statut |
|---|---------|--------|-----------|--------|
| 1 | **Pas de gestion des ACLs** | Accès non restreint aux topics | CRITIQUE | ⚠️ À créer |
| 2 | **Métriques JMX non exposées** | Diagnostic impossible | HAUTE | ✅ Corrigé |
| 3 | **MM2 en mode standalone** | SPOF - Pas de HA | CRITIQUE | ⚠️ À migrer |
| 4 | **Composants collocalisés** | Contention ressources potentielle | MOYENNE | ℹ️ Architecture validée |
| 5 | **Certificats clients** | Problèmes TLS identifiés | MOYENNE | [ ] À vérifier |

### 3.2 Configuration Brokers - Audit

| Paramètre | Valeur Actuelle | Éval. | Recommandation |
|-----------|-----------------|-------|----------------|
| num.network.threads | 3 | ⚠ | 8-12 |
| num.io.threads | 8 | ✓ | OK |
| default.replication.factor | 3 | ✓ | OK |
| min.insync.replicas | 2 | ✓ | OK |
| transaction.state.log.min.isr | 3 | ⚠ | 2 |
| num.recovery.threads.per.data.dir | 1 | ⚠ | 4 |
| group.initial.rebalance.delay.ms | 0 | ⚠ | 3000 |
| log.retention.hours | 168 | ✓ | OK (7 jours) |
| auto.create.topics.enable | false | ✓ | Best practice |

### 3.3 Observabilité Validée (Jour 2)

| Test | Statut |
|------|--------|
| Endpoints JMX accessibles (HTTP 200) | ✅ |
| Format Prometheus valide | ✅ |
| Scraping Prometheus actif | ✅ |
| Métriques clés présentes | ✅ |
| Cohérence séries temporelles | ✅ |

---

## 4. Dashboards Grafana Disponibles

Les dashboards suivants sont configurés et utilisables pour le monitoring :

| Dashboard | UID | Métriques Clés |
|-----------|-----|----------------|
| **MM2 Replication Metrics** | mm2-replication | Latence réplication, Record Age, Throughput |
| **MM2 Detailed Metrics** | mm2-detailed-metrics | Tasks, Errors, Producer Buffer |
| **Kafka Cluster** | kafka-cluster | Brokers, Partitions, ISR |
| **Kafka Connect Cluster** | kafka-connect-cluster | Workers, Connectors, Tasks |
| **Kafka Consumer** | kafka-consumer | Lag, Throughput |
| **Kafka Topics** | kafka-topics | Messages In/Out, Bytes |
| **ZooKeeper Cluster** | zookeeper-cluster | Latence, Sessions, Quorum |
| **Node Exporter** | node-exporter | CPU, RAM, Disk, Network |
| **Schema Registry** | schema-registry-cluster | Requêtes, Latence |

### 4.1 Métriques MM2 Principales (Dashboard mm2-replication)

```promql
# Latence moyenne réplication
avg(kafka_connect_mirror_source_connector_replication_latency_ms)

# Latence max réplication
max(kafka_connect_mirror_source_connector_replication_latency_ms_max)

# Age moyen des records
avg(kafka_connect_mirror_source_connector_record_age_ms_avg)

# Throughput records/sec
sum(kafka_connect_mirror_source_connector_record_rate)

# Throughput bytes/sec
sum(kafka_connect_mirror_source_connector_byte_rate)

# Total records répliqués
sum(kafka_connect_mirror_source_connector_record_count)
```

### 4.2 Seuils d'Alerte Configurés (Dashboard)

| Métrique | Vert | Jaune | Orange | Rouge |
|----------|------|-------|--------|-------|
| Avg Replication Latency | < 100ms | 100-500ms | 500-1000ms | > 1000ms |
| Max Replication Latency | < 500ms | 500-2000ms | 2000-5000ms | > 5000ms |
| Avg Record Age | < 1000ms | 1000-5000ms | - | > 5000ms |
| Max Record Age | < 5000ms | 5000-30000ms | - | > 30000ms |
| Active Records (Lag) | < 1000 | 1000-10000 | - | > 10000 |

---

## 5. Hypothèses de Travail

### 5.1 Hypothèses Techniques Validées

| ID | Hypothèse | Statut |
|----|-----------|--------|
| H1 | Clusters source et cible opérationnels | ✅ Validé |
| H2 | MirrorMaker 2 déployé (mode standalone actuel) | ✅ Validé |
| H3 | Connectivité réseau stable | ✅ Validé |
| H4 | Certificats TLS déployés | ⚠ Problèmes identifiés |
| H5 | Credentials SASL provisionnés | ✅ Validé |
| H6 | Prometheus/Grafana opérationnels | ✅ Validé |
| H7 | JMX Exporters configurés | ✅ Validé |
| H8 | **Java 17 sur tous les composants** | ✅ Validé |
| H9 | **Confluent Platform 7.7.3** | ✅ Validé |
| H10 | **Infrastructure 4vCPU/32Go/250Go** | ✅ Validé |
| H11 | **Déploiement collocalisé** | ✅ Validé |
| H12 | **Dashboards Grafana fonctionnels** | ✅ Validé |

### 5.2 Hypothèses à Valider

| ID | Hypothèse | Validation |
|----|-----------|------------|
| HF1 | Débit nominal : à mesurer en baseline | Tests perf |
| HF2 | Taille messages : à mesurer | Baseline |
| HF3 | Nombre partitions par topic | Audit config |
| HF4 | Latence réseau inter-cluster | Mesure baseline |

---

## 6. Périmètre des Tests

### 6.1 In Scope

- [x] Tests de performance (throughput, latence E2E)
- [x] Tests de résilience (pannes simulées, failover)
- [x] Tests de sécurité (TLS, SASL, certificats)
- [x] Validation fonctionnelle (réplication, offsets, ordering)
- [x] Mesure et validation du SLA (< 1h annuel)
- [x] **Tuning brokers et MM2 pour conformité SLA**

### 6.2 Out of Scope

- [ ] Tests sur applications consommatrices aval
- [ ] DR inter-région
- [ ] Capacity planning long terme
- [ ] Audit code applications productrices

---

## 7. Risques Identifiés

| ID | Risque | Probabilité | Impact | Mitigation |
|----|--------|-------------|--------|------------|
| R1 | MM2 standalone = SPOF | Élevée | Critique | Migration vers Connect distribué |
| R2 | Collocation composants | Moyenne | Élevé | Séparation VMs MM2/Brokers |
| R3 | Absence ACLs | Élevée | Critique | Implémenter ACLs |
| R4 | Certificats clients | Moyenne | Moyen | Vérifier/renouveler certs |
| R5 | Config brokers sous-optimale | Moyenne | Moyen | Appliquer tuning |

---

## 8. Architecture Cible Recommandée

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ARCHITECTURE CIBLE                                 │
│                                                                              │
│  CLUSTER SOURCE (NEMO)          CLUSTER CIBLE (APPLICATIF)                  │
│  ┌─────────────────────┐        ┌─────────────────────┐                     │
│  │  3 Brokers          │        │  3 Brokers          │                     │
│  │  3 ZooKeeper        │        │  3 ZooKeeper        │                     │
│  └─────────────────────┘        └─────────────────────┘                     │
│            │                              │                                  │
│            │         ┌────────────────────┤                                  │
│            │         │                    │                                  │
│            └─────────┤  MM2 Connect       │                                  │
│                      │  Cluster (3 VMs    │                                  │
│                      │  dédiées)          │                                  │
│                      │  ┌──────────────┐  │                                  │
│                      │  │ Worker 1     │  │                                  │
│                      │  │ Worker 2     │  │                                  │
│                      │  │ Worker 3     │  │                                  │
│                      │  └──────────────┘  │                                  │
│                      └────────────────────┘                                  │
│                                                                              │
│  Principe : MM2 déployé côté TARGET (owner = cluster destination)           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Glossaire

| Terme | Définition |
|-------|------------|
| **MM2** | MirrorMaker 2 - Réplication Kafka basée sur Connect |
| **NEMO** | Cluster Kafka pour échanges inter-applicatifs |
| **Applicatif** | Cluster Kafka pour échanges intra-applicatifs |
| **SLA** | Service Level Agreement - < 1h downtime/an |
| **MTTR** | Mean Time To Recovery - ≤ 10 min par incident |
| **RPO** | Recovery Point Objective - ≤ 60 sec |
| **RTO** | Recovery Time Objective - ≤ 5 min |
| **SPOF** | Single Point of Failure |

---

## Artifacts Produits

- [x] `tests-mirrormaker/00-context/contexte-et-hypotheses.md` (ce fichier)

---

**Client** : Transactis
**Mission** : Audit Kafka MirrorMaker 2
**Date de création** : Jour 3
**Version** : 2.0 - Adapté contexte Transactis
