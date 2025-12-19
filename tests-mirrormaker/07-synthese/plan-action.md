# Plan d'Action - Synthèse MirrorMaker 2 Transactis

## Objectif

Fournir un plan d'action structuré et priorisé pour adresser les problèmes identifiés lors de l'audit J1/J2 et implémenter les recommandations pour atteindre le SLA cible (< 1h downtime annuel).

---

## Pré-requis

- [x] Analyse des goulots complétée (`analyse-goulots.md`)
- [x] Recommandations validées (`recommandations.md`)
- [x] Validation SLA complétée (`04-resilience/validation-sla.md`)
- [x] Constats J1/J2 documentés

---

## Contexte Transactis

### Décision Go/No-Go (cf. `01-prerequis/prerequis-tests.md`)

| Critère | Résultat |
|---------|----------|
| **Tests de validation** | ✅ **GO** |
| **Production** | ❌ **NO-GO** (actions requises) |

### Actions Bloquantes Production

| Priorité | Action | Statut |
|----------|--------|--------|
| **P0** | Migrer MM2 vers Connect distribué | [ ] |
| **P0** | Implémenter ACLs | [ ] |
| P1 | Ajouter 3ème worker MM2 | [ ] |
| P1 | Séparer VMs MM2/Brokers | [ ] |
| P2 | Vérifier/renouveler certificats | [ ] |

---

## 1. Résumé Exécutif

### 1.1 État Actuel (Post-J2)

| Domaine | Score | Verdict |
|---------|-------|---------|
| Performance | - % | ⚠️ À valider |
| Résilience | 60% | ⚠️ MM2 SPOF |
| Sécurité | 50% | ❌ Pas d'ACLs |
| Fonctionnel | 80% | ✅ Réplication OK |
| Observabilité | 100% | ✅ Validé J2 |
| **Global** | - % | ⚠️ NO-GO Production |

### 1.2 Conformité SLA

| Métrique | Objectif | Mesuré | Écart |
|----------|----------|--------|-------|
| Disponibilité | 99.9886% | - % | - % |
| MTTR | < 10 min | - min | - min |
| RTO | < 5 min | - min | - min |
| RPO | < 60 sec | - sec | - sec |
| Latence MM2 | ≤ 1000 ms | - ms | - ms |
| Lag MM2 | ≤ 10000 | - | - |

### 1.3 Actions Prioritaires

| # | Action | Impact | Urgence |
|---|--------|--------|---------|
| 1 | - | Élevé | Immédiat |
| 2 | - | Élevé | Court terme |
| 3 | - | Moyen | Court terme |

---

## 2. Plan d'Action Détaillé

### 2.1 Actions Immédiates (J0 - J7)

#### ACT-001 : ${ACTION_TITLE}

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-001 |
| **Catégorie** | Performance / Résilience / Sécurité / Opérations |
| **Recommandation source** | REC-XXX-XX |
| **Priorité** | P1 - Critique |
| **Responsable** | `${RESPONSABLE_NAME}` |
| **Échéance** | ${DATE_ECHEANCE} |
| **Effort estimé** | ${EFFORT_JOURS} jours-homme |

**Description :**
${DESCRIPTION_DETAILLEE}

**Étapes de réalisation :**
1. [ ] Étape 1 - ${DESCRIPTION}
2. [ ] Étape 2 - ${DESCRIPTION}
3. [ ] Étape 3 - ${DESCRIPTION}

**Critères de succès :**
- [ ] ${CRITERE_1}
- [ ] ${CRITERE_2}

**Risques :**
- ${RISQUE_1}
- ${RISQUE_2}

**Rollback :**
${PROCEDURE_ROLLBACK}

---

#### ACT-002 : Implémentation des Alertes Critiques

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-002 |
| **Catégorie** | Résilience |
| **Recommandation source** | REC-RES-04 |
| **Priorité** | P1 - Critique |
| **Responsable** | - |
| **Échéance** | J+3 |
| **Effort estimé** | 0.5 jour-homme |

**Description :**
Configurer les alertes Prometheus/Alertmanager pour détecter rapidement les problèmes MM2.

**Étapes de réalisation :**
1. [ ] Ajouter les règles d'alerte dans Prometheus
2. [ ] Configurer les canaux de notification (email, Slack, PagerDuty)
3. [ ] Tester le déclenchement des alertes
4. [ ] Documenter les seuils et les réponses attendues

**Critères de succès :**
- [ ] Alertes se déclenchent en < 5 minutes
- [ ] Notifications reçues par l'équipe on-call

---

#### ACT-003 : Optimisation Configuration MM2

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-003 |
| **Catégorie** | Performance |
| **Recommandation source** | REC-PERF-04, REC-PERF-05 |
| **Priorité** | P1 - Critique |
| **Responsable** | - |
| **Échéance** | J+5 |
| **Effort estimé** | 1 jour-homme |

**Description :**
Appliquer les optimisations de configuration MM2 identifiées.

**Étapes de réalisation :**
1. [ ] Backup de la configuration actuelle
2. [ ] Appliquer les nouveaux paramètres sur un worker (canary)
3. [ ] Valider les métriques pendant 2h
4. [ ] Déployer sur tous les workers en rolling
5. [ ] Valider les performances globales

**Critères de succès :**
- [ ] Throughput augmenté de > 20%
- [ ] Latence P99 réduite
- [ ] Pas de régression fonctionnelle

---

### 2.2 Actions Court Terme (J7 - J30)

#### ACT-004 : Création des Runbooks

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-004 |
| **Catégorie** | Opérations |
| **Recommandation source** | REC-OPS-01 |
| **Priorité** | P2 - Importante |
| **Responsable** | - |
| **Échéance** | J+14 |
| **Effort estimé** | 3 jours-homme |

**Description :**
Créer les runbooks pour les incidents courants.

**Runbooks à créer :**
1. [ ] Runbook - Panne Broker Kafka
2. [ ] Runbook - Panne Worker MM2
3. [ ] Runbook - Lag Excessif MM2
4. [ ] Runbook - Panne Réseau Inter-DC
5. [ ] Runbook - Expiration Certificat
6. [ ] Runbook - Échec Authentification SASL

**Critères de succès :**
- [ ] Runbooks validés par l'équipe ops
- [ ] Drill d'incident réalisé avec succès

---

#### ACT-005 : Dashboard Grafana Unifié

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-005 |
| **Catégorie** | Résilience |
| **Recommandation source** | REC-RES-05 |
| **Priorité** | P2 - Importante |
| **Responsable** | - |
| **Échéance** | J+10 |
| **Effort estimé** | 1 jour-homme |

**Description :**
Créer un dashboard unifié de supervision MM2.

**Panels à inclure :**
- [ ] État des connecteurs (status)
- [ ] Lag par topic (graph + stat)
- [ ] Throughput comparatif (source vs réplication)
- [ ] Latence end-to-end (percentiles)
- [ ] Ressources système (CPU, RAM, I/O)
- [ ] Alertes actives

---

#### ACT-006 : Automatisation Vérification Certificats

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-006 |
| **Catégorie** | Sécurité |
| **Recommandation source** | REC-SEC-01 |
| **Priorité** | P2 - Importante |
| **Responsable** | - |
| **Échéance** | J+21 |
| **Effort estimé** | 1 jour-homme |

**Description :**
Mettre en place un monitoring automatique de l'expiration des certificats.

**Étapes de réalisation :**
1. [ ] Configurer blackbox_exporter pour les checks SSL
2. [ ] Créer les alertes d'expiration (J-90, J-30, J-7)
3. [ ] Tester les alertes
4. [ ] Documenter la procédure de renouvellement

---

### 2.3 Actions Moyen Terme (J30 - J90)

#### ACT-007 : Tests de Résilience Périodiques

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-007 |
| **Catégorie** | Opérations |
| **Recommandation source** | REC-OPS-02 |
| **Priorité** | P3 - Standard |
| **Responsable** | - |
| **Échéance** | J+60 |
| **Effort estimé** | 2 jours-homme |

**Description :**
Mettre en place un programme de tests de résilience réguliers.

**Étapes de réalisation :**
1. [ ] Définir le calendrier des tests (mensuel/trimestriel)
2. [ ] Scripter les scénarios de chaos
3. [ ] Réaliser le premier cycle de tests
4. [ ] Documenter les résultats et améliorations

---

#### ACT-008 : Optimisation Réseau

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-008 |
| **Catégorie** | Performance |
| **Recommandation source** | REC-PERF-07 |
| **Priorité** | P3 - Standard |
| **Responsable** | - |
| **Échéance** | J+45 |
| **Effort estimé** | 1 jour-homme |

**Description :**
Appliquer les optimisations TCP pour le réseau inter-DC.

---

#### ACT-009 : Hardening Sécurité

| Attribut | Valeur |
|----------|--------|
| **ID** | ACT-009 |
| **Catégorie** | Sécurité |
| **Recommandation source** | REC-SEC-03 |
| **Priorité** | P3 - Standard |
| **Responsable** | - |
| **Échéance** | J+60 |
| **Effort estimé** | 1 jour-homme |

**Description :**
Désactiver les protocoles TLS obsolètes et renforcer les cipher suites.

---

## 3. Planning Global

### 3.1 Vue Gantt Simplifiée

```
Semaine    | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
-----------|---|---|---|---|---|---|---|---|---|----|----|-----|
ACT-001    |███|   |   |   |   |   |   |   |   |    |    |     |
ACT-002    |███|   |   |   |   |   |   |   |   |    |    |     |
ACT-003    |███|███|   |   |   |   |   |   |   |    |    |     |
ACT-004    |   |███|███|   |   |   |   |   |   |    |    |     |
ACT-005    |   |███|   |   |   |   |   |   |   |    |    |     |
ACT-006    |   |   |███|███|   |   |   |   |   |    |    |     |
ACT-007    |   |   |   |   |   |   |   |███|███|    |    |     |
ACT-008    |   |   |   |   |   |███|███|   |   |    |    |     |
ACT-009    |   |   |   |   |   |   |   |███|███|    |    |     |

Légende: ███ = Travail planifié
```

### 3.2 Jalons Clés

| Jalon | Date | Actions Incluses | Critère de Succès |
|-------|------|------------------|-------------------|
| M1 - Stabilisation | J+7 | ACT-001, 002, 003 | Alertes actives, perf optimisée |
| M2 - Documentation | J+21 | ACT-004, 005 | Runbooks validés, dashboard opérationnel |
| M3 - Sécurité | J+30 | ACT-006 | Monitoring certificats actif |
| M4 - Consolidation | J+60 | ACT-007, 008, 009 | Programme de tests établi |

---

## 4. Ressources et Budget

### 4.1 Effort par Catégorie

| Catégorie | Effort Total (j/h) | % du Total |
|-----------|-------------------|------------|
| Performance | 2.5 | 25% |
| Résilience | 3.5 | 35% |
| Sécurité | 2 | 20% |
| Opérations | 2 | 20% |
| **Total** | 10 | 100% |

### 4.2 Affectation des Ressources

| Ressource | Rôle | Disponibilité | Actions Assignées |
|-----------|------|---------------|-------------------|
| - | Tech Lead | - % | Validation, support |
| - | Ops Kafka | - % | ACT-001, 003, 008 |
| - | DevOps | - % | ACT-002, 005, 006 |
| - | Security | - % | ACT-006, 009 |

---

## 5. Gestion des Risques

### 5.1 Risques Identifiés

| ID | Risque | Probabilité | Impact | Mitigation |
|----|--------|-------------|--------|------------|
| RSK-001 | Indisponibilité ressources | Moyenne | Élevé | Planifier en avance, backup |
| RSK-002 | Régression après optimisation | Faible | Élevé | Tests approfondis, rollback prêt |
| RSK-003 | Résistance au changement | Faible | Moyen | Communication, formation |
| RSK-004 | Dépendance externe (infra) | Moyenne | Moyen | Coordination avec équipes infra |

### 5.2 Plan de Contingence

| Risque | Action de Contingence |
|--------|----------------------|
| RSK-001 | Reprioritiser les actions, reporter les P3 |
| RSK-002 | Rollback immédiat, analyse post-mortem |
| RSK-003 | Démonstration des bénéfices, support management |
| RSK-004 | Réservation anticipée des slots de maintenance |

---

## 6. Suivi et Gouvernance

### 6.1 Fréquence des Points de Suivi

| Type | Fréquence | Participants | Objectif |
|------|-----------|--------------|----------|
| Stand-up | Quotidien | Équipe projet | Avancement, blocages |
| Point hebdo | Hebdomadaire | Équipe + Tech Lead | Revue, décisions |
| Comité pilotage | Bi-mensuel | Équipe + Management | Validation jalons |

### 6.2 Indicateurs de Suivi

| KPI | Cible | Actuel | Tendance |
|-----|-------|--------|----------|
| Actions terminées vs planifiées | 100% | - % | - |
| Jalons respectés | 100% | - % | - |
| Budget effort respecté | ±10% | - % | - |
| Incidents liés aux changements | 0 | - | - |

### 6.3 Template de Reporting

```markdown
# Rapport de Suivi - Semaine XX

## Résumé
- Actions terminées: X/Y
- Jalon actuel: MX
- Prochaine échéance: [DATE] - [ACTION]

## Actions Terminées
- [x] ACT-XXX - Description

## Actions en Cours
- [ ] ACT-XXX - % avancement - [Blocage si applicable]

## Points d'Attention
- [Point 1]

## Décisions Requises
- [Décision 1]

## Prochaines Étapes
- [Étape 1]
```

---

## 7. Communication

### 7.1 Plan de Communication

| Audience | Message | Canal | Fréquence |
|----------|---------|-------|-----------|
| Équipe ops | Détail des changements | Confluence + Slack | Avant chaque action |
| Management | Avancement global | Email + réunion | Hebdomadaire |
| Client | Améliorations apportées | Rapport formel | À chaque jalon |

### 7.2 Escalade

| Niveau | Type de Problème | Contact | Délai de Réponse |
|--------|------------------|---------|------------------|
| N1 | Blocage technique | Tech Lead | 4h |
| N2 | Décision architecturale | Architecte | 24h |
| N3 | Budget/Ressources | Management | 48h |

---

## 8. Tableau de Bord Synthétique

```
┌────────────────────────────────────────────────────────────────────┐
│                 PLAN D'ACTION MM2 - TABLEAU DE BORD                │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  AVANCEMENT GLOBAL                          PROCHAINE ÉCHÉANCE     │
│  ┌─────────────────────────┐                ┌──────────────────┐   │
│  │ ████████░░░░░░░░░░░░░░░ │  35%           │ ACT-003          │   │
│  └─────────────────────────┘                │ J+5              │   │
│                                             └──────────────────┘   │
│  ACTIONS PAR STATUT                                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ ✅ Terminé: 2  🔄 En cours: 3  ⬜ À faire: 4  ❌ Bloqué: 0 │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  JALONS                                                            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ M1 [██████████] 100%  M2 [████░░░░░░] 40%  M3 [░░░░░░░░░░] │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ALERTES                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ ⚠️  ACT-004: Besoin validation runbook par client           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## 9. Checklist de Clôture

### 9.1 Critères de Clôture du Plan d'Action

- [ ] Toutes les actions P1 terminées
- [ ] Toutes les actions P2 terminées ou planifiées
- [ ] Documentation mise à jour
- [ ] Formation équipe réalisée (si applicable)
- [ ] Tests de validation exécutés
- [ ] Rapport final produit
- [ ] Validation client obtenue

### 9.2 Livrables Finaux

| Livrable | Responsable | Statut |
|----------|-------------|--------|
| Rapport de tests complet | - | ⬜ |
| Configurations optimisées documentées | - | ⬜ |
| Runbooks | - | ⬜ |
| Dashboard Grafana | - | ⬜ |
| Rapport de conformité SLA | - | ⬜ |
| Plan de maintenance | - | ⬜ |

---

## 10. Livrables Finaux Transactis

### 10.1 Documents Produits

| Document | Localisation | Statut |
|----------|--------------|--------|
| Contexte et hypothèses | `00-context/` | [x] |
| Pré-requis et inventaire | `01-prerequis/` | [x] |
| Baseline observabilité | `02-baseline/` | [x] |
| Plan tests performance | `03-performance/` | [x] |
| Tests résilience et SLA | `04-resilience/` | [x] |
| Tests sécurité TLS/SASL | `05-securite/` | [x] |
| Validation fonctionnelle | `06-validation-fonctionnelle/` | [x] |
| Synthèse et recommandations | `07-synthese/` | [x] |
| Configurations tuning | `08-tuning/` | [x] |

### 10.2 Dashboards Grafana Utilisés

| Dashboard | UID | Usage |
|-----------|-----|-------|
| MM2 Replication Metrics | `mm2-replication` | SLA Latence |
| MM2 Detailed Metrics | `mm2-detailed-metrics` | Lag, Erreurs |
| Kafka Cluster | `kafka-cluster` | Santé brokers |
| Node Exporter | `node-exporter` | Ressources système |
| ZooKeeper Cluster | `zookeeper-cluster` | Coordination |

---

## Artifacts Produits

- [x] Plan d'action complet et validé
- [ ] Planning avec jalons
- [ ] Tableau de bord de suivi
- [ ] Templates de reporting

---

**Client** : Transactis
**Statut Tests** : ✅ GO
**Statut Production** : ❌ NO-GO (actions P0 requises)
**SLA Cible** : < 1h downtime annuel (99.9886%)
**Version** : 2.0
