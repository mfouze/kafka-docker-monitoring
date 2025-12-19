# Phase 5 : Long Run (Test de Stabilité 24h)

**Durée** : 24 heures minimum  
**Objectif** : Valider la stabilité sur la durée (pas de memory leak, GC stable, pas de dégradation)

---

## Configuration du Test

### Charge Recommandée

```
Débit = 70% de la capacité max validée en Phase 4
```

**Exemple** : Si capacité max = 5000 msg/s → Long run à 3500 msg/s

---

## Lancer le Test

### Variante A - Python Bomber (background)

```bash
nohup python kafka_producer_bomber.py \
  --bootstrap-servers "$KAFKA_SOURCE" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --topic-prefix "test-prometheus" \
  --num-topics 10 \
  --messages-per-second 3500 \
  --num-threads 7 \
  --duration-minutes 1440 \
  > /var/log/longrun_producer.log 2>&1 &

echo $! > /tmp/longrun_producer.pid
```

### Consumer en parallèle (optionnel)

```bash
nohup python kafka_consumer_bomber.py \
  --bootstrap-servers "$KAFKA_TARGET" \
  --username "$KAFKA_USER" \
  --password "$KAFKA_PASS" \
  --topic-prefix "source.test-prometheus" \
  --num-topics 10 \
  --num-consumers 3 \
  --duration-minutes 1440 \
  > /var/log/longrun_consumer.log 2>&1 &
```

### Pour arrêter si besoin

```bash
kill $(cat /tmp/longrun_producer.pid)
```

---

## Points de Contrôle

### Fréquence

| Checkpoint | Heure | Action |
|------------|-------|--------|
| T+1h | __:__ | Vérification rapide |
| T+4h | __:__ | Vérification complète |
| T+8h | __:__ | Vérification complète |
| T+12h | __:__ | Vérification complète |
| T+24h | __:__ | Vérification finale |

---

## Dashboards à Vérifier à Chaque Checkpoint

### Dashboard : `mm2-replication.json`

| Panel | Checkpoint 1h | 4h | 8h | 12h | 24h |
|-------|---------------|----|----|-----|-----|
| Latence avg | ___ms | ___ms | ___ms | ___ms | ___ms |
| Latence max | ___ms | ___ms | ___ms | ___ms | ___ms |
| Record rate | ___/s | ___/s | ___/s | ___/s | ___/s |

### Dashboard : `mm2-detailed-metrics.json`

| Panel | 1h | 4h | 8h | 12h | 24h |
|-------|----|----|----|----|-----|
| Lag (active_count) | ___ | ___ | ___ | ___ | ___ |
| Replication ratio | ___% | ___% | ___% | ___% | ___% |
| Task failures | ___ | ___ | ___ | ___ | ___ |

### Dashboard : `Node-Eporter.json`

| Panel | 1h | 4h | 8h | 12h | 24h |
|-------|----|----|----|----|-----|
| CPU workers | ___% | ___% | ___% | ___% | ___% |
| Memory workers | ___% | ___% | ___% | ___% | ___% |

### Dashboard : `kafka-connect-cluster.json`

| Panel | 1h | 4h | 8h | 12h | 24h |
|-------|----|----|----|----|-----|
| Workers online | ___ | ___ | ___ | ___ | ___ |
| Rebalance count | ___ | ___ | ___ | ___ | ___ |

---

## Critères de Stabilité

### ✅ Tendance OK

```
Métrique
    │
    │     ╭────────────────────────────────╮
    │─────╯                                ╰─────  ← Stable
    │
    └────────────────────────────────────────────→ 24h
```

### ⚠️ Tendance Warning (légère dégradation)

```
Métrique
    │                                    ╱╱╱
    │                              ╱╱╱╱╱╱
    │                        ╱╱╱╱╱╱
    │                  ╱╱╱╱╱╱
    │            ╱╱╱╱╱╱
    │───────────                          ← Dégradation lente
    └────────────────────────────────────────────→ 24h
```

Action : Investiguer, possiblement memory leak ou fragmentation heap

### ❌ Tendance NOGO

```
Métrique
    │                              │
    │                          ╱╱╱│
    │                      ╱╱╱╱   │  ← Crash/OOM
    │                 ╱╱╱╱╱       │
    │           ╱╱╱╱╱╱            │
    │      ╱╱╱╱╱                  ↓
    │─────                        STOP
    └────────────────────────────────────────────→
```

---

## Détection de Memory Leak

**Dashboard** : `Node-Eporter.json` → Panel "Memory Usage"

**Symptôme** : Mémoire augmente continuellement sans redescendre

**Confirmation** :
```bash
# Sur un worker Connect
jstat -gc $(pgrep -f kafka-connect) 5000
# Observer Old Generation (OU) qui augmente sans arrêt
```

---

## Grille Long Run

| Critère | Seuil OK | Seuil Warning | Seuil NOGO |
|---------|----------|---------------|------------|
| Latence max 24h | < 5s | < 10s | > 10s |
| Lag max 24h | < 20000 | < 50000 | > 100000 |
| Memory trend | Stable | +10% sur 24h | +50% sur 24h |
| CPU trend | Stable | +20% sur 24h | Saturation |
| Rebalances | < 3 | < 10 | > 10 |
| Task failures | 0 | 1-2 (auto-recover) | > 2 persistants |

---

## Checklist Phase 5

| Checkpoint | Latence OK | Lag OK | Memory OK | Résultat |
|------------|------------|--------|-----------|----------|
| T+1h | ☐ | ☐ | ☐ | ☐ GO ☐ WARN |
| T+4h | ☐ | ☐ | ☐ | ☐ GO ☐ WARN |
| T+8h | ☐ | ☐ | ☐ | ☐ GO ☐ WARN |
| T+12h | ☐ | ☐ | ☐ | ☐ GO ☐ WARN |
| T+24h | ☐ | ☐ | ☐ | ☐ GO ☐ WARN |

**Tendance globale** : ☐ Stable ☐ Légère dégradation ☐ Dégradation importante

**Phase 5 terminée** : ☐ GO pour Phase 6 ☐ NOGO - analyse requise
