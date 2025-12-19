# Critères GO/NOGO

## Critères pour Passage en Production

Tous ces critères DOIVENT être validés (GO) pour autoriser le passage en production.

### Critères Fonctionnels

| # | Critère | Phase | Seuil | Résultat |
|---|---------|-------|-------|----------|
| 1 | Smoke test réussi | Phase 1 | 100% messages répliqués | ☐ GO ☐ NOGO |
| 2 | Réplication fonctionne | Phase 1 | ratio > 99% | ☐ GO ☐ NOGO |
| 3 | Charge nominale stable | Phase 2 | 30 min sans dégradation | ☐ GO ☐ NOGO |
| 4 | Latence dans SLO | Phase 3 | p99 < 5 secondes | ☐ GO ☐ NOGO |
| 5 | Latence E2E mesurée | Phase 3 | Documentée | ☐ GO ☐ NOGO |

### Critères de Capacité

| # | Critère | Phase | Seuil | Résultat |
|---|---------|-------|-------|----------|
| 6 | Capacité max identifiée | Phase 4 | Documentée | ☐ GO ☐ NOGO |
| 7 | Marge de sécurité calculée | Phase 4 | 70% capacité max | ☐ GO ☐ NOGO |
| 8 | Temps de récupération burst | Phase 4 | < 5 min | ☐ GO ☐ NOGO |

### Critères de Stabilité

| # | Critère | Phase | Seuil | Résultat |
|---|---------|-------|-------|----------|
| 9 | Long run 24h stable | Phase 5 | Pas de dégradation | ☐ GO ☐ NOGO |
| 10 | Pas de memory leak | Phase 5 | Memory stable | ☐ GO ☐ NOGO |
| 11 | CPU stable | Phase 5 | Pas de tendance ↑ | ☐ GO ☐ NOGO |

### Critères de Résilience

| # | Critère | Phase | Seuil | Résultat |
|---|---------|-------|-------|----------|
| 12 | Failover worker OK | Phase 6 | Rebalance < 2 min | ☐ GO ☐ NOGO |
| 13 | Failover broker OK | Phase 6 | Continuité assurée | ☐ GO ☐ NOGO |
| 14 | Récupération réseau | Phase 6 | Auto-récupération | ☐ GO ☐ NOGO |
| 15 | Gestion throttling | Phase 6 | Pas de perte | ☐ GO ☐ NOGO |

### Critères de Qualité

| # | Critère | Phase | Seuil | Résultat |
|---|---------|-------|-------|----------|
| 16 | 0 message perdu | Toutes | 0 | ☐ GO ☐ NOGO |
| 17 | 0 duplication | Toutes | 0 (ou < 0.01%) | ☐ GO ☐ NOGO |
| 18 | Ordering préservé | Phase 1+ | Par partition | ☐ GO ☐ NOGO |

### Critères Opérationnels

| # | Critère | Phase | Seuil | Résultat |
|---|---------|-------|-------|----------|
| 19 | Alertes configurées | Ops | Testées | ☐ GO ☐ NOGO |
| 20 | Dashboards accessibles | Ops | Fonctionnels | ☐ GO ☐ NOGO |
| 21 | Runbook documenté | Ops | Complet | ☐ GO ☐ NOGO |
| 22 | Rollback testé | Ops | Fonctionnel | ☐ GO ☐ NOGO |

---

## Critères NOGO (Bloquants)

Un seul de ces critères suffit à bloquer le passage en production.

| Critère NOGO | Détail |
|--------------|--------|
| ❌ Latence p99 > 5s | Sous charge nominale, pendant > 2 min |
| ❌ Ratio réplication < 99% | Messages potentiellement perdus |
| ❌ Tasks FAILED sans recovery | Intervention manuelle nécessaire |
| ❌ Lag croissant non stabilisé | Capacité insuffisante |
| ❌ Messages perdus > 0 | Inacceptable pour SLA |
| ❌ Duplication > 0.1% | Impact métier potentiel |
| ❌ Crash/OOM pendant long run | Instabilité |
| ❌ Temps récupération > 10 min | Dépasse RTO |

---

## Critères GO/NOGO en Exploitation Continue

### Alertes Critiques (Intervention Immédiate)

| Alerte | Seuil | Action |
|--------|-------|--------|
| Connector FAILED | state = failed | Restart, escalade |
| Lag > 10000 | > 5 min | Scale out, analyse |
| Latence > 5s | > 5 min | Analyse réseau, tuning |
| Worker down | > 2 min | Vérifier restart auto |

### Alertes Warning (Surveillance)

| Alerte | Seuil | Action |
|--------|-------|--------|
| Lag > 5000 | > 10 min | Planifier intervention |
| Latence > 1s | > 10 min | Analyser tendance |
| CPU > 80% | > 10 min | Planifier scale out |
| Memory > 85% | > 10 min | Vérifier heap |

---

## Matrice de Décision

```
                    ┌─────────────────────────────────────┐
                    │         TOUS CRITÈRES GO ?          │
                    └─────────────────┬───────────────────┘
                                      │
                        ┌─────────────┴─────────────┐
                        │                           │
                       OUI                         NON
                        │                           │
                        ▼                           ▼
              ┌─────────────────┐         ┌─────────────────┐
              │  GO PRODUCTION  │         │   CRITÈRES      │
              │                 │         │   NOGO ?        │
              └─────────────────┘         └────────┬────────┘
                                                   │
                                     ┌─────────────┴─────────────┐
                                     │                           │
                                   MAJEUR                      MINEUR
                                     │                           │
                                     ▼                           ▼
                           ┌─────────────────┐         ┌─────────────────┐
                           │     STOP        │         │   CORRIGER      │
                           │   RCA requis    │         │   Re-tester     │
                           │   Pas de prod   │         │   phase concernée
                           └─────────────────┘         └─────────────────┘
```

---

## Fiche de Décision

### Résumé des Tests

| Catégorie | GO | NOGO | Notes |
|-----------|----|----- |-------|
| Fonctionnel (1-5) | __/5 | __/5 | |
| Capacité (6-8) | __/3 | __/3 | |
| Stabilité (9-11) | __/3 | __/3 | |
| Résilience (12-15) | __/4 | __/4 | |
| Qualité (16-18) | __/3 | __/3 | |
| Opérationnel (19-22) | __/4 | __/4 | |
| **TOTAL** | __/22 | __/22 | |

### Décision Finale

☐ **GO PRODUCTION** - 22/22 critères validés

☐ **NOGO** - Points bloquants à résoudre

**Si NOGO, liste des actions** :

| Point | Action | Owner | Deadline |
|-------|--------|-------|----------|
| | | | |
| | | | |

---

**Validé par** :

| Rôle | Nom | Date |
|------|-----|------|
| Testeur | | |
| SRE Lead | | |
| Manager | | |
