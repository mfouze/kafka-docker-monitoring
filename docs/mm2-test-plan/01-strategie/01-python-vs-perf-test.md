# Stratégie de Test Mixte

## Vue d'Ensemble

Ce plan utilise deux types d'outils complémentaires :

| Outil | Type | Force | Faiblesse |
|-------|------|-------|-----------|
| **Python Bombers** | Test applicatif E2E | Réaliste, détection perte/duplication | Plus lent à configurer |
| **kafka-*-perf-test** | Benchmark standardisé | Rapide, comparable, throughput max | Ne teste pas E2E |

---

## Ce que Valide Chaque Outil

### Python Bombers (`kafka_producer_bomber.py` / `kafka_consumer_bomber.py`)

| Validation | Comment |
|------------|---------|
| ✅ Réplication E2E | Produire sur source, consommer sur target |
| ✅ Détection perte | Comparer `message_id` source vs target |
| ✅ Détection duplication | Count `message_id` > 1 sur target |
| ✅ Ordering par partition | Vérifier `sequence_num` croissant par key |
| ✅ Latence applicative | `consumed_at - generated_at` dans metadata |
| ✅ Comportement sous charge | Multi-threads, durée longue |
| ⚠️ Payload réaliste | JSON ~1KB typique |

### kafka-producer-perf-test / kafka-consumer-perf-test

| Validation | Comment |
|------------|---------|
| ✅ Throughput max brut | `--throughput -1` (illimité) |
| ✅ Latence producer | Métriques intégrées |
| ✅ Baseline capacité | Avant tuning |
| ✅ Comparaison configs | Tester acks, compression, batch |
| ❌ Pas E2E | Ne traverse pas MM2 |
| ❌ Pas de validation contenu | Payload binaire aléatoire |

---

## Tableau de Décision : Quel Outil pour Quel Objectif ?

| Objectif | Outil Recommandé | Métriques | Dashboard Grafana |
|----------|------------------|-----------|-------------------|
| **Valider que MM2 réplique** | Python bombers | poll_total, write_total | mm2-replication |
| **Mesurer latence E2E** | Python bombers + Grafana | replication_latency_ms | mm2-replication |
| **Détecter perte messages** | Python bombers | Comparaison counts | mm2-detailed |
| **Throughput max producer** | kafka-producer-perf-test | records/s, MB/s | kafka-producer |
| **Throughput max consumer** | kafka-consumer-perf-test | records/s, MB/s | kafka-consumer |
| **Stress test MM2** | Python bombers (charge élevée) | CPU, RAM, lag | Node-Exporter + mm2 |
| **Baseline avant tuning** | kafka-*-perf-test | p95, p99 latency | kafka-cluster |
| **Test longue durée (24h+)** | Python bombers | Stabilité métriques | Tous |

---

## Quand Utiliser Quoi

```
┌─────────────────────────────────────────────────────────────┐
│                    PHASE DE TEST                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. SMOKE TEST          → Python bombers                    │
│     (valider chaîne)      Regarder: mm2-replication         │
│                                                             │
│  2. BASELINE CAPACITÉ   → kafka-*-perf-test                 │
│     (limites cluster)     Regarder: kafka-cluster           │
│                                                             │
│  3. CHARGE NOMINALE     → Python bombers                    │
│     (SLO réaliste)        Regarder: mm2-replication         │
│                                                             │
│  4. STRESS/PIC          → Python bombers OU perf-test       │
│     (limites MM2)         Regarder: mm2-detailed, Node      │
│                                                             │
│  5. LONG RUN            → Python bombers                    │
│     (stabilité 24h)       Regarder: TOUS les dashboards     │
│                                                             │
│  6. RÉSILIENCE          → Python bombers                    │
│     (failover)            Regarder: kafka-connect-cluster   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Limites de Chaque Approche

### Python Bombers

| Limite | Mitigation |
|--------|------------|
| Dépend synchronisation NTP | Vérifier NTP sur tous les hosts |
| Overhead Python (GIL) | Utiliser plusieurs processus si besoin |
| Pas de métriques intégrées JMX | Compenser avec Prometheus/Grafana |

### kafka-*-perf-test

| Limite | Mitigation |
|--------|------------|
| Ne teste pas MM2 | Utiliser pour baseline uniquement |
| Payload non réaliste | Adapter `--record-size` au use case |
| Pas de durée illimitée | Scripter en boucle si nécessaire |
