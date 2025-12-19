# Phase 8 : Validation Production

**Durée** : 30 minutes  
**Objectif** : Checklist finale avant mise en production

---

## Checklist Pré-Production

### Documentation

| Élément | Vérifié |
|---------|---------|
| Runbook d'exploitation documenté | ☐ |
| Procédure de rollback prête | ☐ |
| Contacts escalade définis | ☐ |
| Dashboards accessibles à l'équipe ops | ☐ |
| Alertes configurées et testées | ☐ |

### Configuration

| Élément | Vérifié |
|---------|---------|
| Config MM2 sauvegardée (backup) | ☐ |
| Paramètres optimisés selon tests | ☐ |
| Quotas appropriés configurés | ☐ |
| ACLs correctes sur tous les topics | ☐ |
| SSL/Certificats valides > 3 mois | ☐ |

### Monitoring

| Élément | Vérifié |
|---------|---------|
| Dashboard mm2-replication fonctionnel | ☐ |
| Dashboard mm2-detailed fonctionnel | ☐ |
| Alertes Prometheus configurées | ☐ |
| Notification (Slack/PagerDuty) testée | ☐ |

---

## Procédure de Fenêtre de Change

### H-1 : Préparation

```bash
# Backup config
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/config > backup_mm2_config_$(date +%Y%m%d).json

# Screenshot baseline Grafana
# Sauvegarder les métriques actuelles
```

### H0 : Exécution

```bash
# Pause si nécessaire
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/pause

# Appliquer changement
# ...

# Resume
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/resume
```

### H+15min : Validation

| Vérification | Résultat |
|--------------|----------|
| Connector RUNNING | ☐ |
| Tasks RUNNING | ☐ |
| Latence dans SLO | ☐ |
| Lag diminue | ☐ |
| Pas d'erreurs logs | ☐ |

### H+1 : Post-change

```bash
# Réactiver alertes si silenciées
# Documenter le changement
# Communication équipe
```

---

## Procédure de Rollback

```bash
#!/bin/bash
# rollback_mm2.sh

echo "=== ROLLBACK MM2 ==="

# 1. Pause
curl -X PUT http://kafka-connect-1:8083/connectors/mm2-source-connector/pause
sleep 5

# 2. Supprimer
curl -X DELETE http://kafka-connect-1:8083/connectors/mm2-source-connector
sleep 10

# 3. Recréer avec backup
curl -X POST http://kafka-connect-1:8083/connectors \
  -H "Content-Type: application/json" \
  -d @backup_mm2_config_YYYYMMDD.json

# 4. Vérifier
sleep 30
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/status | jq .

echo "=== ROLLBACK TERMINÉ ==="
```

---

## Critères GO/NOGO Finaux

### Tous ces critères DOIVENT être GO

| # | Critère | Phase | Résultat |
|---|---------|-------|----------|
| 1 | Smoke test réussi | Phase 1 | ☐ GO ☐ NOGO |
| 2 | Charge nominale stable | Phase 2 | ☐ GO ☐ NOGO |
| 3 | Latence p99 < 5s (SLO) | Phase 3 | ☐ GO ☐ NOGO |
| 4 | Capacité max documentée | Phase 4 | ☐ GO ☐ NOGO |
| 5 | Long run 24h stable | Phase 5 | ☐ GO ☐ NOGO |
| 6 | Résilience validée | Phase 6 | ☐ GO ☐ NOGO |
| 7 | Comportements erreur documentés | Phase 7 | ☐ GO ☐ NOGO |
| 8 | 0 message perdu sur tous les tests | Toutes | ☐ GO ☐ NOGO |
| 9 | Alertes configurées | Monitoring | ☐ GO ☐ NOGO |
| 10 | Rollback testé | Ops | ☐ GO ☐ NOGO |

---

## Décision Finale

### ✅ GO PRODUCTION

Conditions :
- Tous les critères ci-dessus sont GO
- Aucun NOGO majeur non résolu
- Documentation complète

**Signatures** :

| Rôle | Nom | Date | Signature |
|------|-----|------|-----------|
| Testeur | | | |
| SRE Lead | | | |
| Product Owner | | | |

### ❌ NOGO

**Points bloquants identifiés** :

| # | Point Bloquant | Action Corrective | Owner | Deadline |
|---|----------------|-------------------|-------|----------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

**Date prévue nouvelle tentative** : ______________

---

## Résumé Capacités Validées

```
┌──────────────────────────────────────────────────────────┐
│                FICHE TECHNIQUE MM2                       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Capacité max testée      : _________ msg/s             │
│  Capacité recommandée     : _________ msg/s (70%)       │
│                                                          │
│  Latence baseline         : _________ ms                │
│  Latence max sous charge  : _________ ms                │
│  Latence p99 validée      : _________ ms                │
│                                                          │
│  Temps récupération burst : _________ min               │
│  Temps rebalance worker   : _________ s                 │
│                                                          │
│  Nombre workers           : _________                   │
│  Nombre tasks             : _________                   │
│                                                          │
└──────────────────────────────────────────────────────────┘
```
