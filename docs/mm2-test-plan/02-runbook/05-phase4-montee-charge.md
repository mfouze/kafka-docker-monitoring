# Phase 4 : Montée en Charge Progressive

**Durée** : 45 minutes  
**Objectif** : Identifier la capacité maximale avant dégradation SLO

---

## Paliers de Charge

| Palier | Débit (msg/s) | Durée | Critère Passage |
|--------|---------------|-------|-----------------|
| **P1** | 1 000 | 5 min | Latence p99 < 1s |
| **P2** | 2 500 | 5 min | Latence p99 < 2s |
| **P3** | 5 000 | 5 min | Latence p99 < 3s |
| **P4** | 7 500 | 5 min | Latence p99 < 4s |
| **P5** | 10 000 | 5 min | Latence p99 < 5s (SLO) |

**Règle** : Arrêter dès qu'un palier échoue le critère.

---

## Commandes par Palier

### Palier P1 - 1000 msg/s

```bash
# Variante A - Python
python kafka_producer_bomber.py \
  --bootstrap-servers "$KAFKA_SOURCE" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --messages-per-second 1000 \
  --num-threads 5 \
  --num-topics 10 \
  --duration-minutes 5

# Variante B - perf-test
kafka-producer-perf-test.sh \
  --topic "test-prometheus.generated-data-01.json" \
  --num-records 300000 \
  --record-size 1024 \
  --throughput 1000 \
  --producer-props bootstrap.servers=$KAFKA_SOURCE ...
```

### Palier P3 - 5000 msg/s

```bash
python kafka_producer_bomber.py \
  --messages-per-second 5000 \
  --num-threads 10 \
  --duration-minutes 5 \
  ...
```

### Palier P5 - 10000 msg/s

```bash
python kafka_producer_bomber.py \
  --messages-per-second 10000 \
  --num-threads 20 \
  --duration-minutes 5 \
  ...
```

---

## Dashboards à Surveiller

### Dashboard : `mm2-replication.json`

| Panel | P1 OK | P2 OK | P3 OK | P4 OK | P5 OK |
|-------|-------|-------|-------|-------|-------|
| Latence avg | <200ms | <500ms | <1s | <2s | <3s |
| Latence max | <1s | <2s | <3s | <4s | <5s |

### Dashboard : `mm2-detailed-metrics.json`

| Panel | Seuil Warning | Seuil Stop |
|-------|---------------|------------|
| Active Records (Lag) | > 10000 | > 50000 |
| Buffer Utilization | > 70% | > 90% |
| Buffer Exhausted | > 0 | > 10 |

### Dashboard : `Node-Eporter.json`

| Panel | Seuil Warning | Seuil Stop |
|-------|---------------|------------|
| CPU workers | > 80% | > 95% |
| Memory workers | > 85% | > 95% |
| Disk I/O | Saturation visible | |

---

## Grille de Résultats

| Palier | msg/s | Latence Avg | Latence Max | Lag | CPU % | Résultat |
|--------|-------|-------------|-------------|-----|-------|----------|
| P1 | 1000 | _____ ms | _____ ms | _____ | ___% | ☐ GO ☐ STOP |
| P2 | 2500 | _____ ms | _____ ms | _____ | ___% | ☐ GO ☐ STOP |
| P3 | 5000 | _____ ms | _____ ms | _____ | ___% | ☐ GO ☐ STOP |
| P4 | 7500 | _____ ms | _____ ms | _____ | ___% | ☐ GO ☐ STOP |
| P5 | 10000 | _____ ms | _____ ms | _____ | ___% | ☐ GO ☐ STOP |

---

## Procédure entre Paliers

1. **Terminer** le producer du palier N
2. **Attendre 2 min** que le lag se résorbe
3. **Vérifier** que lag revient proche de 0
4. **Noter** le temps de récupération
5. **Lancer** palier N+1

### Temps de Récupération par Palier

| Palier | Lag max pendant | Temps récup à <1000 |
|--------|-----------------|---------------------|
| P1 | _____ | _____ min |
| P2 | _____ | _____ min |
| P3 | _____ | _____ min |
| P4 | _____ | _____ min |
| P5 | _____ | _____ min |

---

## Résultat Final

### Capacité Maximale Validée

```
Dernier palier GO : P___ = _____ msg/s
```

### Capacité Recommandée pour Prod

```
70% de la capacité max = _____ msg/s
```

**Justification** : Marge pour pics, GC, maintenance

---

## Checklist Phase 4

| Critère | Résultat |
|---------|----------|
| Tous les paliers documentés | ☐ |
| Capacité max identifiée | ☐ |
| Capacité prod calculée (70%) | ☐ |
| Temps récupération mesurés | ☐ |

**Phase 4 terminée** : ☐ GO pour Phase 5
