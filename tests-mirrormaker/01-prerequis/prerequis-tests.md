# Pré-requis des Tests - MirrorMaker 2 Transactis

## Objectif

Définir et valider l'ensemble des pré-requis nécessaires avant le démarrage des tests MirrorMaker 2.

---

## Pré-requis de ce Document

- [x] `inventaire-acces.md` complété
- [x] `versions-composants.md` complété
- [x] Contexte et hypothèses validés (`00-context/`)

---

## 1. État des Clusters - Validé J2

### 1.1 Cluster NEMO (Source)

| Vérification | Attendu | Statut |
|--------------|---------|--------|
| Brokers UP | 3 | [x] Validé |
| ZooKeeper quorum | 3/3 | [x] Validé |
| Under-replicated partitions | 0 | [x] Validé |
| Métriques JMX exposées | Oui | [x] Validé (J2) |

**Dashboard de validation :** `kafka-cluster`

### 1.2 Cluster Applicatif (Cible)

| Vérification | Attendu | Statut |
|--------------|---------|--------|
| Brokers UP | 3 | [x] Validé |
| ZooKeeper quorum | 3/3 | [x] Validé |
| Under-replicated partitions | 0 | [x] Validé |
| Métriques JMX exposées | Oui | [x] Validé (J2) |

**Dashboard de validation :** `kafka-cluster`

### 1.3 MirrorMaker 2

| Vérification | Attendu | Actuel | Statut |
|--------------|---------|--------|--------|
| Mode déploiement | Connect distribué | Standalone | ⚠️ SPOF |
| Workers UP | 3 | 3 | [x] ✅ Validé |
| Connecteurs RUNNING | 3 | 3 | [x] ✅ Validé |
| Métriques JMX exposées | Oui | Oui | [x] ✅ Validé |
| Déploiement | Collocalisé | Collocalisé | [x] ✅ Validé |

**Dashboard de validation :** `mm2-replication`, `mm2-detailed-metrics`

---

## 2. Observabilité - Validée J2

### 2.1 Prometheus

| Vérification | Statut |
|--------------|--------|
| Prometheus opérationnel | [x] |
| Scraping Kafka brokers | [x] |
| Scraping Kafka Connect | [x] |
| Scraping ZooKeeper | [x] |
| Scraping Node Exporter | [x] |
| Scraping Schema Registry | [x] |

### 2.2 Grafana

| Vérification | Statut |
|--------------|--------|
| Grafana opérationnel | [x] |
| Datasource Prometheus configuré | [x] |
| Dashboard MM2 Replication | [x] |
| Dashboard MM2 Detailed | [x] |
| Dashboard Kafka Cluster | [x] |
| Dashboard ZooKeeper | [x] |
| Dashboard Node Exporter | [x] |

### 2.3 Métriques Clés Disponibles

| Métrique | Dashboard | Présente |
|----------|-----------|----------|
| `kafka_connect_mirror_source_connector_replication_latency_ms` | mm2-replication | [x] |
| `kafka_connect_mirror_source_connector_record_age_ms_avg` | mm2-replication | [x] |
| `kafka_connect_mirror_source_connector_record_rate` | mm2-replication | [x] |
| `kafka_connect_source_task_metrics_source_record_active_count` | mm2-detailed-metrics | [x] |
| `kafka_server_ReplicaManager_UnderReplicatedPartitions` | kafka-cluster | [x] |
| `up{job="kafka"}` | kafka-cluster | [x] |

---

## 3. Sécurité

### 3.1 TLS/SSL

| Vérification | Statut | Notes |
|--------------|--------|-------|
| Certificats brokers valides | ⚠️ | Problème identifié J1 |
| Truststore configuré | [x] | - |
| Keystore configuré | [x] | - |
| TLS 1.2/1.3 activé | [ ] | À vérifier |

### 3.2 SASL

| Vérification | Statut |
|--------------|--------|
| Mécanisme SCRAM-SHA-512 | [x] |
| Comptes de service créés | [x] |
| Authentification fonctionnelle | [x] |

### 3.3 ACLs

| Vérification | Statut | Notes |
|--------------|--------|-------|
| ACLs configurées | ❌ | **Constat critique J1** |
| Accès restreints | ❌ | Tous accès ouverts |

**Action requise :** Créer les ACLs avant mise en production

---

## 4. Ressources Système

### 4.1 Spécifications Actuelles (Validées ✅)

| Ressource | Valeur | Statut |
|-----------|--------|--------|
| **vCPU** | 4 | ✅ Validé |
| **RAM** | 32 Go | ✅ Validé |
| **Disque** | 250 Go | ✅ Validé |
| **Java** | 17 | ✅ Validé |
| **Déploiement** | Collocalisé (Broker + ZK + Connect + SR) | ✅ Validé |

### 4.2 Seuils de Surveillance

| Métrique | Seuil Warning | Seuil Critical | Dashboard |
|----------|---------------|----------------|-----------|
| CPU % | > 70% | > 85% | node-exporter |
| RAM % | > 80% | > 90% | node-exporter |
| Disk % | > 70% | > 85% | node-exporter |

---

## 5. Checklist Go / No-Go

### 5.1 Pré-requis Bloquants (MUST)

| ID | Pré-requis | Statut |
|----|------------|--------|
| M1 | Cluster NEMO opérationnel | [x] GO |
| M2 | Cluster Applicatif opérationnel | [x] GO |
| M3 | MirrorMaker 2 actif | [x] GO |
| M4 | Authentification SASL fonctionnelle | [x] GO |
| M5 | Prometheus collecte les métriques | [x] GO |
| M6 | Dashboards Grafana fonctionnels | [x] GO |

### 5.2 Pré-requis Recommandés (SHOULD)

| ID | Pré-requis | Statut | Impact si Absent |
|----|------------|--------|------------------|
| S1 | ACLs configurées | ❌ NO-GO | Risque sécurité |
| S2 | MM2 en mode Connect distribué | ⚠️ | SPOF (mode standalone actuel) |
| S3 | 3 workers MM2 | [x] ✅ | - |
| S4 | Certificats > 30 jours | [ ] | À vérifier |
| S5 | JMX Exporters fonctionnels | [x] ✅ | - |
| S6 | Dashboards Grafana opérationnels | [x] ✅ | - |

### 5.3 Constats Critiques J1/J2

| Constat | Impact | Priorité | Statut |
|---------|--------|----------|--------|
| MM2 en mode standalone | SPOF - pas de HA | P0 | ⚠️ À migrer |
| Pas d'ACLs | Sécurité compromise | P0 | ⚠️ À créer |
| Composants collocalisés | Contention ressources | P1 | ℹ️ Architecture validée |
| Certificats clients | Problèmes connexion | P2 | [ ] À vérifier |

### 5.4 Environnement Validé

| Composant | Spécification | Statut |
|-----------|---------------|--------|
| Infrastructure | 4 vCPU / 32 Go RAM / 250 Go Disk | ✅ |
| Java | OpenJDK 17 | ✅ |
| Confluent Platform | 7.7.3 | ✅ |
| JMX Exporters | Fonctionnels | ✅ |
| Dashboards Grafana | Fonctionnels | ✅ |
| Déploiement | Collocalisé | ✅ |

---

## 6. Décision Go / No-Go

### 6.1 Pour Tests de Validation

| Critère | Résultat |
|---------|----------|
| Infrastructure opérationnelle | [x] GO |
| Observabilité fonctionnelle | [x] GO |
| Sécurité (auth) | [x] GO |

**Décision Tests :** ✅ **GO** pour tests de validation

### 6.2 Pour Production

| Critère | Résultat |
|---------|----------|
| ACLs configurées | ❌ NO-GO |
| MM2 mode distribué | ❌ NO-GO |
| 3 workers MM2 HA | ⚠️ À améliorer |

**Décision Production :** ❌ **NO-GO** - Actions correctives requises

---

## 7. Actions Requises Avant Production

| Priorité | Action | Responsable | Statut |
|----------|--------|-------------|--------|
| P0 | Migrer MM2 vers Connect distribué | - | [ ] |
| P0 | Implémenter ACLs | - | [ ] |
| P1 | Ajouter 3ème worker MM2 | - | [ ] |
| P1 | Séparer VMs MM2/Brokers | - | [ ] |
| P2 | Vérifier/renouveler certificats | - | [ ] |

---

## Artifacts Produits

- [x] Checklist Go/No-Go complétée
- [x] Liste des actions correctives

---

**Client** : Transactis
**Statut Tests** : GO
**Statut Production** : NO-GO (actions requises)
**Version** : 2.0
