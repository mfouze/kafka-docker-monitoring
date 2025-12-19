# Traduction SLA → SLO / Critères Opérationnels

## SLA Cible

**Indisponibilité < 1 heure par an** = **99.989% disponibilité**

---

## Traduction en SLO Opérationnels

| Élément | Définition | Valeur Cible | Justification |
|---------|------------|--------------|---------------|
| **SLO Latence Réplication** | Temps source → target (p99) | **< 5 secondes** | Permet détection et réaction avant impact métier |
| **SLO Lag Maximum** | Backlog messages en attente | **< 10 000 msg** ou **< 30 sec** de retard | Évite perte en cas de failover |
| **RTO** (Recovery Time Objective) | Temps reprise après incident | **< 10 minutes** | Basé sur budget 1h/an, permet ~6 incidents |
| **RPO** (Recovery Point Objective) | Perte données max | **< 1 minute** de messages | Idéalement 0, mais réaliste avec async |
| **MTTR** (Mean Time To Repair) | Temps moyen réparation | **< 15 minutes** | Inclut détection + diagnostic + action |
| **Temps de Détection** | Alerte → Notification | **< 2 minutes** | Prometheus scrape (15s) + évaluation + notification |

---

## Calcul du Budget d'Erreur

```
Budget annuel = 1 heure = 60 minutes = 3600 secondes

Si MTTR = 15 min :
  → Max 4 incidents majeurs par an (60 / 15)

Si incident mineur (latence dégradée mais pas down) :
  → Compte partiellement selon impact
```

---

## À Compléter avec les Équipes Métier

| Question | Réponse | Validé par |
|----------|---------|------------|
| Quel délai max acceptable avant qu'un message arrive sur target ? | _________ | _________ |
| Combien de messages perdus est acceptable en cas d'incident ? | _________ | _________ |
| Quelles heures sont critiques (pics, batch nocturnes) ? | _________ | _________ |
| Y a-t-il des topics plus critiques que d'autres ? | _________ | _________ |

---

## Méthode pour Obtenir ces Infos

1. **Atelier SLI/SLO** : Réunir Product Owner, Dev, Ops
2. **Analyse historique** : Regarder les incidents passés et leur impact
3. **Simulation** : Couper MM2 5 min en pré-prod, observer l'impact business
