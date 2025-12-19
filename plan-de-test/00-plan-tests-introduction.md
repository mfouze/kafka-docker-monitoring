# Plan de Tests - Validation SLA Kafka MirrorMaker 2

**Client** : Transactis  
**Mission** : Audit Kafka MirrorMaker 2  
**Objectif SLA** : Downtime annuel < 1 heure (disponibilité > 99.989%)  
**Date** : Décembre 2025  
**Auteur** : Mafouze Koto - Octamis

---

## Table des Matières

1. [Contexte et Objectifs](#1-contexte-et-objectifs)
2. [Critères de Succès SLA](#2-critères-de-succès-sla)
3. [Architecture de Test](#3-architecture-de-test)
4. [Plan de Tests - Vue d'Ensemble](#4-plan-de-tests---vue-densemble)

---

## 1. Contexte et Objectifs

### 1.1 Rappel de la Mission

L'audit Kafka MirrorMaker 2 pour Transactis vise à valider que l'infrastructure répond aux exigences de production avec un SLA de disponibilité supérieur à 99.989% (moins d'1 heure de downtime par an).

### 1.2 Périmètre des Tests

| Composant | Scope |
|-----------|-------|
| Cluster Kafka Source (NEMO) | 3 brokers, 3 AZ |
| Cluster Kafka Target (Applicatif) | 3 brokers, 3 AZ |
| ZooKeeper | 3 nœuds par cluster |
| MirrorMaker 2 | 3 workers Connect distribué |
| Monitoring | Prometheus + Grafana |

### 1.3 Contrainte SLA

| Métrique | Valeur Cible | Calcul |
|----------|--------------|--------|
| Disponibilité annuelle | > 99.989% | 8760h × 0.00011 = 0.96h |
| Downtime maximal annuel | < 1 heure | 60 minutes |
| Downtime maximal mensuel | < 5 minutes | ~4.38 minutes |
| RTO (Recovery Time Objective) | < 5 minutes | Temps de récupération après incident |
| RPO (Recovery Point Objective) | < 1 minute | Perte de données maximale acceptable |

### 1.4 Environnement de Test

| Paramètre | Valeur |
|-----------|--------|
| Version Kafka | 7.7.3 (Confluent Platform) |
| Brokers | 3 par cluster |
| vCPU par broker | 4 |
| RAM par broker | 32 Go |
| Stockage | 250 Go |
| Sécurité | TLS + SASL/SCRAM-SHA-512 |

---

## 2. Critères de Succès SLA

### 2.1 Métriques de Performance

| Métrique | Seuil Acceptable | Seuil Critique |
|----------|------------------|----------------|
| Latence production P99 | < 100 ms | > 500 ms |
| Latence production P99.9 | < 200 ms | > 1000 ms |
| Throughput minimum | > 5000 msg/s | < 1000 msg/s |
| Lag réplication MM2 | < 1000 messages | > 10000 messages |
| Lag consommateur | < 5000 messages | > 50000 messages |

### 2.2 Métriques de Disponibilité

| Métrique | Seuil Acceptable | Seuil Critique |
|----------|------------------|----------------|
| Under-replicated partitions | 0 | > 0 pendant 2 min |
| Offline partitions | 0 | > 0 |
| ISR shrink rate | < 1/min | > 5/min |
| Active controller count | 1 | 0 ou > 1 |
| ZooKeeper latence | < 20 ms | > 100 ms |

### 2.3 Métriques de Résilience

| Scénario | Temps de Récupération Cible |
|----------|----------------------------|
| Perte d'un broker | < 30 secondes |
| Perte d'un nœud ZooKeeper | < 10 secondes |
| Perte d'un worker MM2 | < 60 secondes |
| Perte d'une AZ complète | < 2 minutes |
| Failover controller | < 30 secondes |

---

## 3. Architecture de Test

### 3.1 Topologie

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ENVIRONNEMENT DE TEST                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │    AZ 1      │    │    AZ 2      │    │    AZ 3      │           │
│  │  Paris 1     │    │  Paris 2     │    │  North 1     │           │
│  │  Marcoussis  │    │  Pantin      │    │  Seclin      │           │
│  ├──────────────┤    ├──────────────┤    ├──────────────┤           │
│  │ Broker 1     │    │ Broker 2     │    │ Broker 3     │           │
│  │ ZooKeeper 1  │    │ ZooKeeper 2  │    │ ZooKeeper 3  │           │
│  │ Connect W1   │    │ Connect W2   │    │ Connect W3   │           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐         │
│  │                   MirrorMaker 2                         │         │
│  │  • MirrorSourceConnector                                │         │
│  │  • MirrorCheckpointConnector                            │         │
│  │  • MirrorHeartbeatConnector                             │         │
│  └────────────────────────────────────────────────────────┘         │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐         │
│  │                   Monitoring Stack                       │         │
│  │  • Prometheus (scrape 15s)                              │         │
│  │  • Grafana (dashboards)                                 │         │
│  │  • JMX Exporters (tous composants)                      │         │
│  │  • Node Exporter (métriques OS)                         │         │
│  └────────────────────────────────────────────────────────┘         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Outils de Test

| Outil | Usage | Version |
|-------|-------|---------|
| kafka-producer-perf-test | Tests de charge production | Confluent 7.7.3 |
| kafka-consumer-perf-test | Tests de charge consommation | Confluent 7.7.3 |
| Producer Bomber | Charge continue avec TLS/SASL | Custom |
| Consumer Bomber | Charge continue consommation | Custom |
| chaos-monkey scripts | Tests de résilience | Custom |

---

## 4. Plan de Tests - Vue d'Ensemble

### 4.1 Catégories de Tests

| # | Catégorie | Fichier Détaillé | Durée Estimée |
|---|-----------|------------------|---------------|
| 1 | Tests de Performance Baseline | `01-tests-performance-baseline.md` | 4 heures |
| 2 | Tests de Charge et Stress | `02-tests-charge-stress.md` | 6 heures |
| 3 | Tests de Résilience Broker | `03-tests-resilience-broker.md` | 4 heures |
| 4 | Tests de Résilience ZooKeeper | `04-tests-resilience-zookeeper.md` | 3 heures |
| 5 | Tests de Résilience MirrorMaker 2 | `05-tests-resilience-mm2.md` | 4 heures |
| 6 | Tests de Failover Multi-AZ | `06-tests-failover-az.md` | 4 heures |
| 7 | Tests de Réplication Bout-en-Bout | `07-tests-replication-e2e.md` | 3 heures |
| 8 | Tests d'Endurance | `08-tests-endurance.md` | 24 heures |
| 9 | Tests de Monitoring et Alerting | `09-tests-monitoring-alerting.md` | 2 heures |
| 10 | Validation SLA Globale | `10-validation-sla-globale.md` | 2 heures |

### 4.2 Prérequis Communs

Avant chaque session de tests :

1. **Vérification de l'état initial**
   - Tous les brokers UP et synchronisés
   - Quorum ZooKeeper stable
   - Tous les connecteurs MM2 en état RUNNING
   - Dashboards Grafana accessibles
   - Prometheus scraping opérationnel

2. **Baseline métriques**
   - Capture des métriques initiales
   - Vérification absence d'alertes
   - Under-replicated partitions = 0

3. **Documentation**
   - Horodatage de début de test
   - Version des composants
   - Configuration appliquée

### 4.3 Critères d'Arrêt des Tests

Les tests doivent être interrompus si :

| Condition | Action |
|-----------|--------|
| Perte de données confirmée | STOP immédiat + investigation |
| Corruption de données | STOP immédiat + investigation |
| Cluster irrécupérable | STOP + procédure de restauration |
| Dépassement RTO × 3 | STOP + analyse root cause |

---

## Navigation

| Section | Lien |
|---------|------|
| Section 1 | [Tests de Performance Baseline](01-tests-performance-baseline.md) |
| Section 2 | [Tests de Charge et Stress](02-tests-charge-stress.md) |
| Section 3 | [Tests de Résilience Broker](03-tests-resilience-broker.md) |
| Section 4 | [Tests de Résilience ZooKeeper](04-tests-resilience-zookeeper.md) |
| Section 5 | [Tests de Résilience MirrorMaker 2](05-tests-resilience-mm2.md) |
| Section 6 | [Tests de Failover Multi-AZ](06-tests-failover-az.md) |
| Section 7 | [Tests de Réplication Bout-en-Bout](07-tests-replication-e2e.md) |
| Section 8 | [Tests d'Endurance](08-tests-endurance.md) |
| Section 9 | [Tests de Monitoring et Alerting](09-tests-monitoring-alerting.md) |
| Section 10 | [Validation SLA Globale](10-validation-sla-globale.md) |

---

**Document suivant** : [01-tests-performance-baseline.md](01-tests-performance-baseline.md)
