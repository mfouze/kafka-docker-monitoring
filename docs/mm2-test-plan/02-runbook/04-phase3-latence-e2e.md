# Phase 3 : Mesure Latence End-to-End

**Durée** : 15 minutes  
**Objectif** : Valider que la latence respecte le SLO (< 5 secondes p99)

---

## Méthode : Utiliser les Métriques MM2 Existantes

MM2 expose déjà la latence de réplication via JMX/Prometheus. Pas besoin de scripts custom.

### Métrique Clé

```
kafka_connect_mirror_source_connector_replication_latency_ms
```

Cette métrique mesure le temps entre :
- **Timestamp du message** (CreateTime dans le record Kafka source)
- **Moment où MM2 l'écrit** sur le target

---

## Dashboard : `mm2-replication.json`

### Panels de Latence

| Panel | Description | Seuil SLO |
|-------|-------------|-----------|
| **Avg Replication Latency** | Moyenne sur la période | < 500 ms |
| **Max Replication Latency** | Maximum observé | < 5000 ms |
| **Replication Latency by Topic/Partition** | Détail par partition | Uniformité |

### Comment Lire le Graphique de Latence

```
ms
5000 ─┼─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  ← SLO p99 (5s)
     │
     │                   ╭╮        
1000 ─┼─ ─ ─ ─ ─ ─ ─ ─ ─│ │─ ─ ─ ─ ─ ─ ─ ─ ─ ─  ← Seuil Warning
     │               ╭──╯ ╰──╮
     │    ╭────╮ ╭──╯        ╰──╮    ╭───
 500 ─┼───╯    ╰─╯              ╰────╯     ← Normal
     │
     └────────────────────────────────────────→ Temps
```

---

## Dashboard : `mm2-detailed-metrics.json`

### Panels Complémentaires

| Panel | Ce qu'il montre |
|-------|-----------------|
| **Record Age (Avg/Max)** | Âge des messages au moment de la réplication |
| **Offset Commit Max Time** | Temps pour persister les offsets |
| **Task Pause Ratio** | Temps passé en pause (backpressure) |

---

## Étape 3.1 : Observer Latence sous Charge

Pendant que la charge de Phase 2 ou une nouvelle charge tourne :

1. Ouvrir `mm2-replication.json`
2. Régler la fenêtre temporelle sur "Last 15 minutes"
3. Observer les panels de latence

### Valeurs à Noter

| Métrique | Valeur | Seuil | OK? |
|----------|--------|-------|-----|
| Latence moyenne | _____ ms | < 500 ms | ☐ |
| Latence max | _____ ms | < 5000 ms | ☐ |
| Latence p99 (si disponible) | _____ ms | < 5000 ms | ☐ |

---

## Étape 3.2 : Vérifier Distribution par Topic/Partition

Dans le panel **"Replication Latency by Topic/Partition"** :

**Attendu** : Toutes les partitions ont des latences similaires

**NOGO si** : Une partition a une latence 10× plus élevée que les autres (hot partition)

---

## Étape 3.3 : Vérifier Record Age

**Dashboard** : `mm2-replication.json` section "Record Age"

| Métrique | Signification | Seuil OK |
|----------|---------------|----------|
| **Avg Record Age** | Âge moyen des messages répliqués | < 1000 ms |
| **Max Record Age** | Âge du message le plus vieux répliqué | < 5000 ms |

Si Record Age >> Replication Latency :
- Messages anciens dans la queue source
- MM2 rattrape un backlog

---

## Étape 3.4 : Calcul Latence E2E Réelle (Optionnel)

Pour mesurer la vraie latence E2E incluant le consumer :

### Via Consumer Bomber

```bash
# Lancer le consumer sur target avec verbose
python kafka_consumer_bomber.py \
  --bootstrap-servers "$KAFKA_TARGET" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --topic-prefix "source.test-prometheus" \
  --num-topics 1 \
  --num-consumers 1 \
  --duration-minutes 5 \
  --verbose
```

Les logs afficheront le temps de traitement. Ajouter le temps de réplication MM2 pour obtenir E2E total.

**Latence E2E ≈ Latence MM2 + Latence Consumer**

---

## Checklist Phase 3

| Critère | Valeur | SLO | Résultat |
|---------|--------|-----|----------|
| Latence avg | _____ ms | < 500 ms | ☐ GO ☐ NOGO |
| Latence max | _____ ms | < 5000 ms | ☐ GO ☐ NOGO |
| Record age max | _____ ms | < 5000 ms | ☐ GO ☐ NOGO |
| Distribution uniforme | ☐ Oui ☐ Non | Uniforme | ☐ GO ☐ NOGO |

**Phase 3 terminée** : ☐ GO pour Phase 4 ☐ NOGO - tuning requis

---

## Si Latence Hors SLO

Voir `06-optimisation/02-latence-elevee.md` pour les actions correctives.

Causes fréquentes :
- Réseau lent entre clusters
- Quotas/throttling côté target
- Partitions non équilibrées
- `linger.ms` trop élevé
