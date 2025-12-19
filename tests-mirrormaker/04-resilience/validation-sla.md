# Validation du SLA - Tests de Résilience MirrorMaker 2 Transactis

## Objectif

Valider formellement la conformité de l'infrastructure MirrorMaker 2 avec le SLA contractuel de disponibilité < 1h d'indisponibilité annuelle (99.989%).

---

## Pré-requis

- [ ] Tests de résilience exécutés (`scenarios-pannes.md`)
- [ ] Métriques MTTR/RPO collectées (`metriques-mttr-rpo.md`)
- [ ] Tests de performance validés (`03-performance/`)

---

## 1. Rappel des Exigences SLA Transactis

### 1.1 Engagement Contractuel

| Critère | Valeur Contractuelle | Traduction Technique |
|---------|---------------------|----------------------|
| **Disponibilité annuelle** | > 99.989% | 525,600 min - 60 min = 525,540 min UP |
| **Indisponibilité max/an** | < 60 minutes | Budget d'incidents cumulé |
| **RPO** | ≤ 60 secondes | Perte données acceptable |
| **RTO** | ≤ 5 minutes | Temps restauration max |
| **MTTR par incident** | ≤ 10 minutes | Temps reprise par incident |

### 1.2 Seuils Impératifs - NE PAS DÉPASSER

| Métrique | Seuil MAXIMUM | Justification |
|----------|---------------|---------------|
| **MTTR par incident** | ≤ 10 minutes | Permet ~6 incidents/an |
| **RPO (perte données)** | ≤ 60 secondes | Transactions financières |
| **RTO (restauration)** | ≤ 5 minutes | Continuité service |
| **Lag réplication** | ≤ 30 secondes | Cohérence données |
| **Latence E2E MM2** | ≤ 1000 ms | Performance acceptable |
| **Latence E2E P99** | ≤ 5000 ms | Pic de charge |

### 1.3 Décomposition du Budget d'Indisponibilité

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

## 2. Cartographie des Risques d'Indisponibilité

### 2.1 Analyse des Points de Défaillance

| Composant | Type de Panne | Fréquence/An | MTTR Max Toléré | Impact Max |
|-----------|---------------|--------------|-----------------|------------|
| Broker Source (1/3) | Crash/Panne HW | 4 | 30 sec | 2 min |
| Broker Cible (1/3) | Crash/Panne HW | 4 | 30 sec | 2 min |
| Worker MM2 (1/3) | Crash/OOM | 6 | 60 sec | 6 min |
| ZooKeeper (1/3) | Crash (quorum OK) | 2 | 0 sec* | 0 min |
| Réseau Inter-Cluster | Coupure | 1 | 120 sec | 2 min |
| Certificats | Expiration | 0** | 0 sec | 0 min |
| Rolling Restart Brokers | Maintenance | 4 | 30 sec/broker | 6 min |
| Rolling Restart MM2 | Maintenance | 4 | 30 sec/worker | 6 min |

*Quorum maintenu = pas d'impact
**Avec monitoring proactif

### 2.2 Estimation Indisponibilité Annuelle (Pire Cas)

```
Calcul estimatif (scénario pire cas) :

Pannes Broker Source:    4 × 30s  = 120s  =  2 min
Pannes Broker Cible:     4 × 30s  = 120s  =  2 min
Pannes Worker MM2:       6 × 60s  = 360s  =  6 min
Pannes ZK (quorum OK):   0        = 0s    =  0 min
Pannes Réseau:           1 × 120s = 120s  =  2 min
─────────────────────────────────────────────────
Sous-total Incidents:                      12 min

Maintenances Planifiées:
Rolling Restart Kafka:   4 × 2min = 480s  =  8 min
Rolling Restart MM2:     4 × 2min = 480s  =  8 min
─────────────────────────────────────────────────
Sous-total Maintenance:                    16 min

═════════════════════════════════════════════════
TOTAL ESTIMÉ ANNUEL:                       28 min
Budget Disponible:                         60 min
Marge de Sécurité:                         32 min (53%)
```

---

## 3. Seuils de Validation par Scénario

### 3.1 Tableau des Seuils IMPÉRATIFS

| ID | Scénario | MTTR MAX | RPO MAX | Validation Grafana |
|----|----------|----------|---------|-------------------|
| RES-01 | Panne 1 broker source | **≤ 30 sec** | 0 msg | kafka-cluster |
| RES-02 | Panne 1 broker cible | **≤ 30 sec** | 0 msg | kafka-cluster |
| RES-03 | Panne 1 worker MM2 | **≤ 60 sec** | ≤ 1000 msg | mm2-replication |
| RES-04 | Panne ZK source (quorum OK) | **0 sec** | 0 msg | zookeeper-cluster |
| RES-05 | Panne ZK cible (quorum OK) | **0 sec** | 0 msg | zookeeper-cluster |
| RES-06 | Coupure réseau 30s | **≤ 90 sec** | ≤ 5000 msg | mm2-replication |
| RES-07 | Coupure réseau 2min | **≤ 180 sec** | ≤ 20000 msg | mm2-replication |
| RES-08 | Rolling restart brokers | **≤ 30 sec/broker** | 0 msg | kafka-cluster |
| RES-09 | Rolling restart MM2 | **≤ 30 sec/worker** | ≤ 1000 msg | mm2-replication |
| RES-10 | Panne 2 brokers simultanés | **≤ 60 sec** | 0 msg | kafka-cluster |
| RES-11 | Panne complète MM2 | **≤ 120 sec** | ≤ 10000 msg | mm2-detailed-metrics |
| RES-12 | Expiration certificat | **0 sec*** | 0 msg | - |

*Avec renouvellement proactif avant expiration

### 3.2 Matrice de Validation - À REMPLIR

| ID | Scénario | MTTR Max | MTTR Mesuré | RPO Max | RPO Mesuré | Verdict |
|----|----------|----------|-------------|---------|------------|---------|
| RES-01 | Panne broker source | ≤ 30s | ___ s | 0 | ___ | ⬜ |
| RES-02 | Panne broker cible | ≤ 30s | ___ s | 0 | ___ | ⬜ |
| RES-03 | Panne worker MM2 | ≤ 60s | ___ s | ≤1000 | ___ | ⬜ |
| RES-04 | Panne ZK source | 0s | ___ s | 0 | ___ | ⬜ |
| RES-05 | Panne ZK cible | 0s | ___ s | 0 | ___ | ⬜ |
| RES-06 | Coupure réseau 30s | ≤ 90s | ___ s | ≤5000 | ___ | ⬜ |
| RES-08 | Rolling brokers | ≤30s/broker | ___ s | 0 | ___ | ⬜ |
| RES-09 | Rolling MM2 | ≤30s/worker | ___ s | ≤1000 | ___ | ⬜ |

**Légende verdict:** ✅ Conforme | ⚠️ Limite | ❌ Non conforme | ⬜ Non testé

---

## 4. Métriques de Validation via Dashboards

### 4.1 Dashboard MM2 Replication (mm2-replication)

| Métrique | Seuil OK | Seuil Warning | Seuil Critical |
|----------|----------|---------------|----------------|
| `avg(kafka_connect_mirror_source_connector_replication_latency_ms)` | < 100ms | 100-500ms | > 1000ms |
| `max(kafka_connect_mirror_source_connector_replication_latency_ms_max)` | < 500ms | 500-2000ms | > 5000ms |
| `avg(kafka_connect_mirror_source_connector_record_age_ms_avg)` | < 1000ms | 1000-5000ms | > 5000ms |
| `sum(kafka_connect_mirror_source_connector_record_rate)` | > 0 | stable | drop > 50% |

### 4.2 Dashboard MM2 Detailed (mm2-detailed-metrics)

| Métrique | Seuil OK | Seuil Warning | Seuil Critical |
|----------|----------|---------------|----------------|
| `kafka_connect_source_task_metrics_source_record_active_count` | < 1000 | 1000-10000 | > 10000 |
| `kafka_connect_connector_task_status{status="failed"}` | 0 | - | > 0 |
| `kafka_producer_producer_metrics_record_error_total` | 0 | 1-10 | > 10 |
| `kafka_producer_producer_metrics_buffer_exhausted_total` | 0 | 1-5 | > 5 |

### 4.3 Dashboard Kafka Cluster (kafka-cluster)

| Métrique | Seuil OK | Seuil Warning | Seuil Critical |
|----------|----------|---------------|----------------|
| `kafka_server_ReplicaManager_UnderReplicatedPartitions` | 0 | 1-10 | > 10 |
| `kafka_controller_KafkaController_OfflinePartitionsCount` | 0 | - | > 0 |
| `kafka_controller_KafkaController_ActiveControllerCount` | 1 | - | ≠ 1 |
| Brokers UP (`up{job="kafka"}`) | 3 | 2 | < 2 |

### 4.4 Dashboard ZooKeeper (zookeeper-cluster)

| Métrique | Seuil OK | Seuil Warning | Seuil Critical |
|----------|----------|---------------|----------------|
| `zk_avg_latency` | < 10ms | 10-50ms | > 50ms |
| `zk_outstanding_requests` | < 10 | 10-100 | > 100 |
| Nodes UP | 3 | 2 | < 2 |

---

## 5. Calcul de Disponibilité

### 5.1 Formule

```
Disponibilité (%) = (525,600 - Downtime_annuel_min) / 525,600 × 100

Pour SLA > 99.989% :
Downtime_max = 525,600 × (100 - 99.989) / 100 = 57.8 min ≈ 60 min
```

### 5.2 Template de Calcul Post-Tests

```
# DONNÉES MESURÉES (à remplir après tests)
MTTR_BROKER_SOURCE = ___ sec
MTTR_BROKER_CIBLE = ___ sec
MTTR_MM2_WORKER = ___ sec
MTTR_NETWORK = ___ sec
MTTR_ROLLING_BROKER = ___ sec/broker
MTTR_ROLLING_MM2 = ___ sec/worker

# FRÉQUENCES ESTIMÉES (à ajuster selon historique)
FREQ_PANNE_BROKER = 4 /an (par broker)
FREQ_PANNE_MM2 = 6 /an (par worker)
FREQ_PANNE_NETWORK = 1 /an
FREQ_ROLLING_KAFKA = 4 /an
FREQ_ROLLING_MM2 = 4 /an

# CALCUL DOWNTIME ANNUEL
DOWNTIME_BROKERS = (MTTR_BROKER_SOURCE + MTTR_BROKER_CIBLE) × FREQ_PANNE_BROKER
DOWNTIME_MM2 = MTTR_MM2_WORKER × FREQ_PANNE_MM2
DOWNTIME_NETWORK = MTTR_NETWORK × FREQ_PANNE_NETWORK
DOWNTIME_ROLLING = (3 × MTTR_ROLLING_BROKER × FREQ_ROLLING_KAFKA) +
                   (3 × MTTR_ROLLING_MM2 × FREQ_ROLLING_MM2)

TOTAL_DOWNTIME = DOWNTIME_BROKERS + DOWNTIME_MM2 + DOWNTIME_NETWORK + DOWNTIME_ROLLING

# DISPONIBILITÉ
AVAILABILITY = (525600 - TOTAL_DOWNTIME/60) / 525600 × 100

# VERDICT
Si AVAILABILITY >= 99.989% : CONFORME
Si AVAILABILITY >= 99.95% et < 99.989% : CONFORME SOUS RÉSERVE
Si AVAILABILITY < 99.95% : NON CONFORME
```

---

## 6. Grille de Décision SLA

### 6.1 Critères de Conformité

| Critère | Condition | Poids |
|---------|-----------|-------|
| MTTR tous scénarios | Tous ≤ seuils définis | BLOQUANT |
| RPO tous scénarios | Tous ≤ seuils définis | BLOQUANT |
| Disponibilité calculée | ≥ 99.989% | BLOQUANT |
| Latence E2E P99 | ≤ 5000ms | IMPORTANT |
| Alertes fonctionnelles | 100% opérationnelles | IMPORTANT |
| Documentation | Complète | RECOMMANDÉ |

### 6.2 Décision

| Scénario | Critères | Décision |
|----------|----------|----------|
| Tous BLOQUANT OK | N/A | ✅ CONFORME |
| 1+ BLOQUANT KO | N/A | ❌ NON CONFORME |
| BLOQUANT OK, IMPORTANT KO | Avec actions correctives | ⚠️ CONFORME SOUS RÉSERVE |

---

## 7. Déclaration de Conformité

### 7.1 Synthèse des Résultats - À COMPLÉTER

| Catégorie | Tests | Réussis | Taux |
|-----------|-------|---------|------|
| Résilience | 12 | ___ | ___% |
| Performance | 7 | ___ | ___% |
| Fonctionnel | 5 | ___ | ___% |
| **Total** | 24 | ___ | ___% |

### 7.2 Verdict de Conformité

```
┌─────────────────────────────────────────────────────────────────┐
│           VERDICT DE CONFORMITÉ SLA - TRANSACTIS                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Date d'évaluation: _______________                              │
│                                                                  │
│  SLA Évalué: Disponibilité > 99.989% (< 1h downtime/an)         │
│                                                                  │
│  Résultat:                                                       │
│                                                                  │
│  [ ] ✅ CONFORME                                                 │
│      L'infrastructure MirrorMaker 2 respecte les exigences      │
│      du SLA sur la base des tests réalisés.                     │
│      Disponibilité démontrée: ______%                           │
│      Marge: ______ min                                          │
│                                                                  │
│  [ ] ⚠️ CONFORME SOUS RÉSERVE                                   │
│      Conformité conditionnée à:                                  │
│      □ Migration MM2 vers Connect distribué                     │
│      □ Implémentation ACLs                                      │
│      □ Séparation VMs MM2/Brokers                               │
│      □ _______________________________                          │
│                                                                  │
│  [ ] ❌ NON CONFORME                                             │
│      Actions correctives OBLIGATOIRES:                          │
│      □ _______________________________                          │
│      □ _______________________________                          │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Métriques clés:                                                 │
│  - Disponibilité démontrée: ______%                             │
│  - Downtime estimé annuel: ______ min                           │
│  - Budget SLA: 60 min                                           │
│  - Marge: ______ min (______%)                                  │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Signatures:                                                     │
│                                                                  │
│  Auditeur: _____________________ Date: ______________           │
│                                                                  │
│  Tech Lead Transactis: ____________ Date: ______________        │
│                                                                  │
│  Responsable Client: ______________ Date: ______________        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Constats et Recommandations Post-Audit

### 8.1 Constats Critiques (BLOQUANTS pour SLA)

| # | Constat | Impact SLA | Action Requise | Priorité |
|---|---------|------------|----------------|----------|
| 1 | MM2 en mode standalone (SPOF) | +30 min downtime/an | Migrer vers Connect distribué | P0 |
| 2 | Pas d'ACLs | Risque sécurité | Implémenter ACLs | P1 |
| 3 | Composants collocalisés | Contention ressources | Séparer VMs | P1 |

### 8.2 Recommandations d'Amélioration

| ID | Recommandation | Impact | Effort |
|----|----------------|--------|--------|
| REC-01 | 3 workers MM2 minimum (HA) | -20 min downtime | Moyen |
| REC-02 | Alertes < 1 min detection | -5 min MTTR | Faible |
| REC-03 | Runbooks incidents | -30% MTTR | Faible |
| REC-04 | Tests chaos trimestriels | Validation continue | Moyen |

### 8.3 Plan de Suivi SLA

| Activité | Fréquence | Métrique Clé |
|----------|-----------|--------------|
| Revue dashboards | Quotidienne | Latence, Lag |
| Rapport SLA | Mensuel | Disponibilité cumul |
| Test résilience | Trimestriel | MTTR validation |
| Audit complet | Annuel | Conformité globale |

---

## Artifacts Produits

- [ ] Matrice de validation SLA complétée
- [ ] Calcul de disponibilité documenté
- [ ] Déclaration de conformité signée
- [ ] Plan de recommandations
- [ ] Planning de suivi

---

**Client** : Transactis
**Mission** : Audit MirrorMaker 2
**SLA** : < 1h downtime annuel (> 99.989%)
**Version** : 2.0
