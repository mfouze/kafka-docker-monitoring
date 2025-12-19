# Plan de Test MirrorMaker 2 (MM2)

**Version**: 1.0  
**Date**: 2024-12-16  
**SLA Cible**: Indisponibilité < 1h/an (99.989% disponibilité)

---

## Structure du Plan

Ce plan de test est organisé en sections numérotées pour une exécution séquentielle :

| Dossier | Contenu |
|---------|---------|
| `00-prerequis/` | Checklist environnement, configuration, traduction SLA→SLO |
| `01-strategie/` | Stratégie de test mixte Python Bombers vs kafka-perf-test |
| `02-runbook/` | Plan chronologique étape par étape avec commandes |
| `03-scenarios/` | Scénarios de charge S1 à S7 avec double implémentation |
| `04-metriques/` | Métriques à collecter, seuils, dashboards Grafana |
| `05-go-nogo/` | Critères de réussite alignés SLA |
| `06-optimisation/` | Guide de tuning par symptôme |
| `07-dashboards/` | Guide d'utilisation des dashboards Grafana |

---

## Ordre d'Exécution Recommandé

```
1. Lire 00-prerequis/     → Préparer l'environnement
2. Lire 01-strategie/     → Comprendre l'approche
3. Exécuter 02-runbook/   → Phase par phase
4. Référencer 03-scenarios/ → Pour les commandes exactes
5. Surveiller 07-dashboards/ + 04-metriques/ → Pendant les tests
6. Valider 05-go-nogo/    → Décision finale
7. Consulter 06-optimisation/ → Si problèmes détectés
```

---

## Dashboards Grafana Disponibles

| Dashboard | Fichier | Usage |
|-----------|---------|-------|
| **MM2 Replication** | `mm2-replication.json` | Latence, throughput, topics répliqués |
| **MM2 Detailed** | `mm2-detailed-metrics.json` | Tasks, erreurs, buffer, producer |
| **Kafka Connect Cluster** | `kafka-connect-cluster.json` | État workers, connecteurs |
| **Kafka Cluster** | `kafka-cluster.json` | Brokers, partitions, ISR |
| **Kafka Consumer** | `kafka-consumer.json` | Lag consumer groups |
| **Node Exporter** | `Node-Eporter.json` | CPU, RAM, disque des workers |

---

## Contacts

| Rôle | Contact |
|------|---------|
| L1 Opérations | **À compléter** |
| L2 SRE | **À compléter** |
| L3 Kafka Expert | **À compléter** |
