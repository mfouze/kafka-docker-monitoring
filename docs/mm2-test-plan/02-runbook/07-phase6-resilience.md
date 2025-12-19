# Phase 6 : Tests de Résilience

**Durée** : 1 heure  
**Objectif** : Valider le comportement en cas de panne (failover, recovery)

---

## Test 6.1 : Restart Worker Connect

**Objectif** : Vérifier le rebalance et la continuité de réplication

### Préparation

```bash
# Identifier les workers et le leader
curl -s http://kafka-connect-1:8083/connectors/mm2-source-connector/status | jq '.tasks[].worker_id'
```

### Exécution

```bash
# Arrêter un worker (pas tous !)
ssh kafka-connect-2 "sudo systemctl stop kafka-connect"

# Chronométrer le rebalance
# START_TIME=$(date +%s)
```

### Dashboard à Observer : `kafka-connect-cluster.json`

| Panel | Avant | Pendant | Après |
|-------|-------|---------|-------|
| Workers Online | 2 | 1 | 2 |
| Task Count | N | Transition | N |
| Rebalance Events | X | X+1 | X+1 |

### Dashboard : `mm2-replication.json`

Observer la **courbe de latence** pendant le rebalance :

```
Latence
    │           ╭──╮
    │          ╱    ╲
    │         ╱      ╲          ← Pic attendu pendant rebalance
    │────────╱        ╲────────
    │
    └────────────────────────────→
           ↑          ↑
         Stop       Restart
```

### Relancer

```bash
ssh kafka-connect-2 "sudo systemctl start kafka-connect"
```

### Métriques à Noter

| Métrique | Valeur | Seuil GO |
|----------|--------|----------|
| Temps avant détection rebalance | _____ s | < 30s |
| Durée du rebalance | _____ s | < 120s |
| Latence max pendant | _____ ms | < 10000ms |
| Messages perdus | _____ | 0 |
| État final tasks | _____ | RUNNING |

**GO** : Rebalance < 2 min, 0 perte, RUNNING après  
**NOGO** : Rebalance > 5 min ou tasks FAILED persistantes

---

## Test 6.2 : Restart Broker Source

**Objectif** : Vérifier que MM2 continue malgré un broker down

### Préparation

```bash
# Identifier un broker non-leader pour les partitions de test
kafka-topics.sh --bootstrap-server $KAFKA_SOURCE $SECURITY_OPTS \
  --describe --topic "test-prometheus.generated-data-01.json" | grep "Leader:"
```

### Exécution

```bash
# Arrêter un broker (pas le leader si possible)
ssh kafka-broker-3 "sudo systemctl stop kafka"
```

### Dashboard : `kafka-cluster.json`

| Panel | Avant | Pendant | Après |
|-------|-------|---------|-------|
| Online Brokers | 3 | 2 | 3 |
| Under Replicated Partitions | 0 | >0 | 0 |
| ISR Shrinks | X | X+N | X+N |

### Dashboard : `mm2-replication.json`

| Panel | Pendant | Attendu |
|-------|---------|---------|
| Record Rate | ___/s | Stable ou légère baisse |
| Latence | ___ms | Pic possible mais < 5s |

### Relancer

```bash
ssh kafka-broker-3 "sudo systemctl start kafka"
# Attendre resync ISR (peut prendre plusieurs minutes)
```

### Métriques à Noter

| Métrique | Valeur | Seuil GO |
|----------|--------|----------|
| URP pendant arrêt | _____ | > 0 (attendu) |
| URP après restart | _____ | 0 (< 5 min) |
| MM2 continue | ☐ Oui ☐ Non | Oui |
| Latence max | _____ ms | < 5000ms |

**GO** : MM2 continue, URP revient à 0  
**NOGO** : MM2 FAILED ou URP persistantes

---

## Test 6.3 : Simulation Réseau Dégradé

**Objectif** : Tester le comportement avec latence réseau élevée

### Exécution (sur un worker Connect)

```bash
# Ajouter 100ms de latence + jitter
sudo tc qdisc add dev eth0 root netem delay 100ms 20ms

# Vérifier
ping -c 5 kafka-source-1
```

### Dashboard : `mm2-replication.json`

| Panel | Avant | Pendant | Attendu |
|-------|-------|---------|---------|
| Latence avg | ___ms | ___ms | +100ms environ |
| Latence max | ___ms | ___ms | +200ms environ |

### Dashboard : `mm2-detailed-metrics.json`

| Panel | Pendant | Seuil OK |
|-------|---------|----------|
| Lag | _____ | Augmente légèrement |
| Task state | _____ | RUNNING |

### Retirer la perturbation

```bash
sudo tc qdisc del dev eth0 root netem
```

### Vérifier Récupération

Observer que la latence revient au niveau baseline en < 2 min.

**GO** : MM2 s'adapte, récupère après  
**NOGO** : Tasks FAILED ou non-récupération

---

## Test 6.4 : Test Quota/Throttling

**Objectif** : Valider le comportement quand un quota est atteint

### Exécution

```bash
# Appliquer un quota restrictif au user MM2 (côté target)
kafka-configs.sh --bootstrap-server $KAFKA_TARGET $SECURITY_OPTS \
  --alter --add-config 'producer_byte_rate=1048576' \
  --entity-type users --entity-name mm2-user
```

### Dashboard : `mm2-detailed-metrics.json`

| Panel | Attendu |
|-------|---------|
| Producer Throttle Time Max | > 0 (quota actif) |
| Lag | Augmente (throughput limité) |
| Buffer Utilization | Augmente |

### Retirer le quota

```bash
kafka-configs.sh --bootstrap-server $KAFKA_TARGET $SECURITY_OPTS \
  --alter --delete-config 'producer_byte_rate' \
  --entity-type users --entity-name mm2-user
```

### Métriques

| Métrique | Pendant | Après |
|----------|---------|-------|
| Throttle time | ___ms | 0 |
| Lag | _____ | Descend |
| Messages perdus | _____ | 0 |

**GO** : Throttle détecté, pas de perte, récupère  
**NOGO** : Buffer overflow, messages perdus

---

## Checklist Phase 6

| Test | Durée Impact | Récupération | Perte | Résultat |
|------|--------------|--------------|-------|----------|
| 6.1 Restart worker | ___s | ☐<2min ☐>2min | ☐0 ☐>0 | ☐GO ☐NOGO |
| 6.2 Restart broker | ___s | ☐<5min ☐>5min | ☐0 ☐>0 | ☐GO ☐NOGO |
| 6.3 Réseau dégradé | ___s | ☐OK ☐NOK | ☐0 ☐>0 | ☐GO ☐NOGO |
| 6.4 Throttling | ___s | ☐OK ☐NOK | ☐0 ☐>0 | ☐GO ☐NOGO |

**Phase 6 terminée** : ☐ GO pour Phase 7 ☐ NOGO - HA à corriger
