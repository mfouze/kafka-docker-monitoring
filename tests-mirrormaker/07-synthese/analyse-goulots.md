# Analyse des Goulots d'Étranglement - Synthèse MirrorMaker 2 Transactis

## Objectif

Identifier et analyser les goulots d'étranglement potentiels ou avérés de l'infrastructure MirrorMaker 2 Transactis sur la base des tests réalisés et des constats J1/J2.

---

## Pré-requis

- [ ] Tests de performance exécutés (`03-performance/`)
- [ ] Tests de résilience exécutés (`04-resilience/`)
- [x] Métriques collectées via Prometheus/Grafana (validé J2)

---

## Contexte Transactis - Goulots Identifiés J1/J2

| Constat | Impact | Catégorie |
|---------|--------|-----------|
| MM2 en mode standalone | SPOF - pas de HA | Architecture |
| 2 workers au lieu de 3 | Capacité réduite, HA limitée | Ressources |
| Composants collocalisés (brokers + MM2) | Contention ressources | Architecture |
| ACLs non configurées | Risque sécurité (non perf) | Sécurité |

**Dashboards d'analyse :**
- `mm2-replication` - Latence, throughput
- `mm2-detailed-metrics` - Tasks, buffer, errors
- `kafka-cluster` - Brokers, partitions
- `node-exporter` - CPU, RAM, Disk, Network

---

## 1. Méthodologie d'Analyse

### 1.1 Approche

L'analyse des goulots d'étranglement suit une approche systématique :

1. **Collecte des métriques** pendant les tests de charge
2. **Identification des saturations** (CPU, mémoire, I/O, réseau)
3. **Corrélation** entre métriques et dégradations observées
4. **Classification** par niveau de criticité
5. **Proposition de solutions**

### 1.2 Indicateurs de Goulot

| Indicateur | Seuil d'Attention | Seuil Critique | Composant Affecté |
|------------|-------------------|----------------|-------------------|
| CPU > 70% | Attention | > 90% | Brokers, MM2 |
| Mémoire Heap > 80% | Attention | > 95% | JVM |
| Disk I/O Util > 70% | Attention | > 90% | Brokers |
| Network > 70% capacité | Attention | > 90% | Inter-DC |
| Request Queue > 100 | Attention | > 1000 | Brokers |
| Lag croissant | Attention | - | MM2 |
| GC Time > 5%/min | Attention | > 10%/min | JVM |

---

## 2. Analyse par Composant

### 2.1 Brokers Kafka - Cluster Source

#### 2.1.1 Métriques Observées

| Métrique | Baseline | Charge Nominale | Charge Max | Saturation |
|----------|----------|-----------------|------------|------------|
| CPU % | - | - | - | ⬜ Oui/Non |
| Mémoire % | - | - | - | ⬜ Oui/Non |
| Disk I/O % | - | - | - | ⬜ Oui/Non |
| Network In MB/s | - | - | - | ⬜ Oui/Non |
| Network Out MB/s | - | - | - | ⬜ Oui/Non |
| Request Queue | - | - | - | ⬜ Oui/Non |
| Produce Latency P99 | - | - | - | - |
| Fetch Latency P99 | - | - | - | - |

#### 2.1.2 Goulots Identifiés

| ID | Goulot | Niveau | Impact | Cause Racine |
|----|--------|--------|--------|--------------|
| GE-SRC-01 | - | - | - | - |
| GE-SRC-02 | - | - | - | - |

### 2.2 Brokers Kafka - Cluster Cible

#### 2.2.1 Métriques Observées

| Métrique | Baseline | Charge Nominale | Charge Max | Saturation |
|----------|----------|-----------------|------------|------------|
| CPU % | - | - | - | ⬜ Oui/Non |
| Mémoire % | - | - | - | ⬜ Oui/Non |
| Disk I/O % | - | - | - | ⬜ Oui/Non |
| Network In MB/s | - | - | - | ⬜ Oui/Non |
| Produce Latency P99 | - | - | - | - |

#### 2.2.2 Goulots Identifiés

| ID | Goulot | Niveau | Impact | Cause Racine |
|----|--------|--------|--------|--------------|
| GE-TGT-01 | - | - | - | - |

### 2.3 Workers MirrorMaker 2

#### 2.3.1 Métriques Observées

| Métrique | Baseline | Charge Nominale | Charge Max | Saturation |
|----------|----------|-----------------|------------|------------|
| CPU % | - | - | - | ⬜ Oui/Non |
| Heap Used % | - | - | - | ⬜ Oui/Non |
| GC Time/min | - | - | - | ⬜ Oui/Non |
| Threads | - | - | - | ⬜ Oui/Non |
| Tasks Running | - | - | - | - |
| Records Lag | - | - | - | - |
| Throughput rec/s | - | - | - | - |

#### 2.3.2 Goulots Identifiés

| ID | Goulot | Niveau | Impact | Cause Racine |
|----|--------|--------|--------|--------------|
| GE-MM2-01 | - | - | - | - |
| GE-MM2-02 | - | - | - | - |

### 2.4 Réseau Inter-DC

#### 2.4.1 Métriques Observées

| Métrique | Baseline | Charge Nominale | Charge Max | Saturation |
|----------|----------|-----------------|------------|------------|
| Latence RTT (ms) | - | - | - | - |
| Bande passante utilisée | - | - | - | ⬜ Oui/Non |
| Packet Loss % | - | - | - | - |
| TCP Retransmits/s | - | - | - | - |

#### 2.4.2 Goulots Identifiés

| ID | Goulot | Niveau | Impact | Cause Racine |
|----|--------|--------|--------|--------------|
| GE-NET-01 | - | - | - | - |

### 2.5 ZooKeeper

#### 2.5.1 Métriques Observées

| Métrique | Baseline | Charge Nominale | Charge Max | Saturation |
|----------|----------|-----------------|------------|------------|
| Avg Latency | - | - | - | ⬜ Oui/Non |
| Outstanding Requests | - | - | - | ⬜ Oui/Non |
| Connections | - | - | - | - |

#### 2.5.2 Goulots Identifiés

| ID | Goulot | Niveau | Impact | Cause Racine |
|----|--------|--------|--------|--------------|
| GE-ZK-01 | - | - | - | - |

---

## 3. Analyse des Corrélations

### 3.1 Corrélation Lag vs Ressources

```
Graphique conceptuel:

Lag MM2 ──────────────────────────────────────────────────
          │                    ╱╲
          │                   ╱  ╲
          │                  ╱    ╲
          │        ╱────────╱      ╲────────
          │       ╱
          │──────╱
          └───────────────────────────────────────────────► Temps

CPU Broker ────────────────────────────────────────────────
          │                    ╱╲
          │                   ╱  ╲
          │         ╱────────╱    ╲────
          │        ╱
          │───────╱
          └───────────────────────────────────────────────► Temps

Corrélation: Quand CPU Broker > 80%, le Lag commence à augmenter
```

### 3.2 Tableau de Corrélations

| Symptôme | Métrique Corrélée 1 | Métrique Corrélée 2 | Coefficient |
|----------|---------------------|---------------------|-------------|
| Lag croissant | CPU Broker Source | - | - |
| Lag croissant | Disk I/O Broker | - | - |
| Lag croissant | GC Time MM2 | - | - |
| Latence E2E élevée | Network Latency | - | - |
| Latence E2E élevée | Request Queue | - | - |

### 3.3 Analyse des Seuils de Dégradation

| Seuil Dépassé | Temps Avant Dégradation | Type de Dégradation |
|---------------|------------------------|---------------------|
| CPU Broker > 80% | ~ X minutes | Lag augmente |
| Heap MM2 > 85% | ~ X minutes | Throughput diminue |
| Disk I/O > 90% | Immédiat | Latence explose |
| Network > 80% | ~ X minutes | Lag + Retransmits |

---

## 4. Classification des Goulots

### 4.1 Matrice de Criticité

| ID | Goulot | Probabilité | Impact | Criticité | Priorité |
|----|--------|-------------|--------|-----------|----------|
| GE-001 | - | Haute/Moyenne/Basse | Haut/Moyen/Bas | - | P1/P2/P3 |
| GE-002 | - | - | - | - | - |
| GE-003 | - | - | - | - | - |

### 4.2 Top 5 des Goulots Critiques

| Rang | ID | Description | Impact SLA | Action Requise |
|------|-----|-------------|------------|----------------|
| 1 | - | - | - | - |
| 2 | - | - | - | - |
| 3 | - | - | - | - |
| 4 | - | - | - | - |
| 5 | - | - | - | - |

---

## 5. Analyse de Capacité

### 5.1 Capacité Actuelle vs Requise

| Ressource | Capacité Actuelle | Utilisation Nominale | Utilisation Max | Marge |
|-----------|-------------------|---------------------|-----------------|-------|
| CPU Broker (total cores) | - | - % | - % | - % |
| RAM Broker (total GB) | - | - % | - % | - % |
| Disk IOPS | - | - | - | - % |
| Disk Throughput MB/s | - | - | - | - % |
| Network Bandwidth Gbps | - | - | - | - % |
| MM2 Workers | - | - | - | - |

### 5.2 Projection de Croissance

| Scénario | Croissance Trafic | Ressource Limitante | Action Requise |
|----------|-------------------|---------------------|----------------|
| +50% trafic | - | - | - |
| +100% trafic | - | - | - |
| +200% trafic | - | - | - |

### 5.3 Point de Saturation Identifié

```
Débit (msg/s)
     │
     │                                    ┌─────── Saturation
     │                               ╱────┘
     │                          ╱────
     │                     ╱────
     │                ╱────
     │           ╱────
     │      ╱────
     │ ╱────
     │────────────────────────────────────────────────► Charge
     │    Nominal     2x         3x         4x

Point de saturation observé: ~X msg/s
Facteur limitant: [CPU / Disk / Network / Memory]
```

---

## 6. Goulots Spécifiques MirrorMaker 2

### 6.1 Configuration Connect

| Paramètre | Valeur Actuelle | Valeur Recommandée | Impact |
|-----------|-----------------|-------------------|--------|
| tasks.max | - | - | Parallélisme |
| offset.flush.interval.ms | - | - | Durabilité vs Perf |
| consumer.fetch.max.bytes | - | - | Throughput |
| producer.batch.size | - | - | Throughput |
| producer.linger.ms | - | - | Latence vs Throughput |

### 6.2 Analyse du Rebalancing

| Métrique | Valeur Observée | Acceptable | Problématique |
|----------|-----------------|------------|---------------|
| Fréquence rebalancing | - /heure | < 1/heure | > 5/heure |
| Durée rebalancing | - sec | < 30 sec | > 120 sec |
| Impact sur lag | - records | < 10000 | > 100000 |

### 6.3 Gestion de la Mémoire MM2

| Worker | Heap Max | Heap Peak | GC Frequency | GC Duration Avg |
|--------|----------|-----------|--------------|-----------------|
| Worker 1 | - | - | - /min | - ms |
| Worker 2 | - | - | - /min | - ms |
| Worker 3 | - | - | - /min | - ms |

---

## 7. Synthèse des Goulots

### 7.1 Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CARTE DES GOULOTS                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  CLUSTER SOURCE              RÉSEAU              CLUSTER CIBLE       │
│  ┌─────────────┐         ┌──────────┐          ┌─────────────┐      │
│  │   Brokers   │         │          │          │   Brokers   │      │
│  │  [CPU: ⚠️]   │─────────│ [BW: ✅] │──────────│  [CPU: ✅]   │      │
│  │  [I/O: ⚠️]   │         │          │          │  [I/O: ✅]   │      │
│  └─────────────┘         └──────────┘          └─────────────┘      │
│         │                                             │              │
│         │                                             │              │
│         ▼                                             ▼              │
│  ┌─────────────┐                              ┌─────────────┐       │
│  │ ZooKeeper   │                              │ ZooKeeper   │       │
│  │  [LAT: ✅]   │                              │  [LAT: ✅]   │       │
│  └─────────────┘                              └─────────────┘       │
│                                                                      │
│                     ┌─────────────────┐                             │
│                     │  MirrorMaker 2  │                             │
│                     │   [CPU: ⚠️]      │                             │
│                     │   [HEAP: ⚠️]     │                             │
│                     │   [TASKS: ✅]    │                             │
│                     └─────────────────┘                             │
│                                                                      │
│  Légende: ✅ OK  ⚠️ Attention  ❌ Critique                           │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.2 Résumé Exécutif

| Catégorie | Nombre Goulots | Critiques | À Surveiller |
|-----------|----------------|-----------|--------------|
| Brokers Source | - | - | - |
| Brokers Cible | - | - | - |
| MirrorMaker 2 | - | - | - |
| Réseau | - | - | - |
| ZooKeeper | - | - | - |
| **Total** | - | - | - |

### 7.3 Impact sur le SLA

| Goulot | Impact Potentiel sur Disponibilité | Risque pour SLA |
|--------|-----------------------------------|-----------------|
| - | - | Faible/Moyen/Élevé |
| - | - | - |

---

## 8. Prochaines Étapes

### 8.1 Actions Immédiates (P1)

| Action | Responsable | Échéance | Statut |
|--------|-------------|----------|--------|
| - | - | - | ⬜ |

### 8.2 Actions Court Terme (P2)

| Action | Responsable | Échéance | Statut |
|--------|-------------|----------|--------|
| - | - | - | ⬜ |

### 8.3 Actions Moyen Terme (P3)

| Action | Responsable | Échéance | Statut |
|--------|-------------|----------|--------|
| - | - | - | ⬜ |

---

## 9. Goulots Spécifiques Transactis (J1/J2)

### 9.1 Goulot Architectural : MM2 Standalone

| Aspect | Actuel | Cible | Action |
|--------|--------|-------|--------|
| Mode déploiement | Standalone | Connect distribué | P0 |
| Workers | 2 | 3 | P1 |
| Collocation | Oui (VM partagées) | Non (VMs dédiées) | P1 |

### 9.2 Goulots Potentiels Identifiés

| ID | Goulot | Niveau | Impact SLA | Priorité |
|----|--------|--------|------------|----------|
| GE-ARCH-01 | MM2 Standalone (SPOF) | CRITIQUE | Disponibilité | **P0** |
| GE-ARCH-02 | 2 workers (vs 3) | ÉLEVÉ | HA/Throughput | **P1** |
| GE-RES-01 | Collocation Brokers/MM2 | MOYEN | Latence/CPU | P1 |
| GE-SEC-01 | Pas d'ACLs | N/A (sécurité) | N/A | **P0** |

---

## Artifacts Produits

- [ ] Rapport d'analyse des goulots
- [ ] Graphiques de corrélation
- [ ] Carte des goulots
- [ ] Plan d'actions priorisé

---

**Client** : Transactis
**Constats J1/J2** : MM2 standalone, 2 workers, collocation
**Version** : 2.0
