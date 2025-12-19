# Plan de Tests de Performance - MirrorMaker 2

## Objectif

Définir le plan complet des tests de performance pour valider la capacité de MirrorMaker 2 à répliquer les données avec les débits et latences attendus, tout en respectant les exigences du SLA.

---

## Pré-requis

- [x] ✅ Baseline observabilité capturée (`02-baseline/`)
- [ ] Topics de test créés (`01-prerequis/prerequis-tests.md`)
- [x] ✅ Système en état nominal confirmé
- [ ] Créneau de test réservé et communiqué

## Environnement Validé

| Paramètre | Valeur |
|-----------|--------|
| Infrastructure | 4 vCPU / 32 Go RAM / 250 Go Disk |
| Java | OpenJDK 17 |
| Confluent Platform | 7.7.3 |
| Architecture | Collocalisée (Broker + ZK + Connect + SR) |
| JMX Exporters | ✅ Fonctionnels |
| Dashboards Grafana | ✅ Fonctionnels |

---

## 1. Objectifs des Tests de Performance

### 1.1 Questions à Répondre

| Question | Métrique de Réponse |
|----------|---------------------|
| Quel est le débit maximal de réplication ? | Messages/sec, MB/sec |
| Quelle est la latence de réplication end-to-end ? | P50, P95, P99 en ms |
| Le système supporte-t-il la charge nominale ? | Stabilité sur durée |
| Quel est le comportement en surcharge ? | Dégradation gracieuse vs crash |
| Le rattrapage après retard est-il acceptable ? | Temps de rattrapage du lag |

### 1.2 Lien avec le SLA (< 1h annuel = 99.9886%)

| Exigence SLA | Test Associé | Critère de Succès |
|--------------|--------------|-------------------|
| Disponibilité 99.9886% | Tests de stabilité | Pas d'interruption sur durée test |
| Temps de reprise | Tests de rattrapage | Rattrapage < 15 min |
| Perte de données minimale | Tests de cohérence | 0 message perdu |

**Contexte Transactis (Validé ✅):**
- Cluster NEMO (Source) : 3 instances collocalisées
- Cluster Applicatif (Cible) : 3 instances collocalisées
- MirrorMaker 2 : 3 workers collocalisés
- Confluent Platform 7.7.3
- Java 17
- Infrastructure : 4 vCPU / 32 Go RAM / 250 Go Disk par instance
- Architecture : Broker + ZK + Connect + SR collocalisés

---

## 2. Scénarios de Test

### 2.1 Vue d'Ensemble des Scénarios

| ID | Scénario | Objectif | Durée | Priorité |
|----|----------|----------|-------|----------|
| PERF-01 | Charge nominale | Valider comportement normal | 1h | Haute |
| PERF-02 | Montée en charge progressive | Identifier le point de saturation | 2h | Haute |
| PERF-03 | Charge de pointe | Valider capacité de burst | 30min | Haute |
| PERF-04 | Test d'endurance | Valider stabilité long terme | 8h+ | Moyenne |
| PERF-05 | Messages volumineux | Impact de la taille des messages | 1h | Moyenne |
| PERF-06 | Latence end-to-end | Mesure précise de la latence | 30min | Haute |
| PERF-07 | Rattrapage de lag | Capacité de récupération | 1h | Haute |

### 2.2 Détail Scénario PERF-01 : Charge Nominale

**Objectif :** Valider que le système réplique correctement à la charge de production normale.

| Paramètre | Valeur |
|-----------|--------|
| Débit cible | 1000 msg/sec (nominal) |
| Taille message | 1024 bytes (1 KB) |
| Durée | 60 minutes |
| Topic | test-mm2-perf |
| Partitions | 6 (aligné sur workers MM2) |

**Étapes :**

1. Vérifier état nominal du système
2. Démarrer la production à débit constant
3. Monitorer les métriques pendant 60 min
4. Arrêter la production
5. Vérifier la cohérence des données répliquées
6. Analyser les métriques

**Critères de succès :**

| Métrique | Critère OK | Critère KO |
|----------|------------|------------|
| Messages répliqués | 100% | < 100% |
| Lag MM2 | < 1000 records | > 1000 records |
| Latence P99 | < 500 ms | > 500 ms |
| Erreurs MM2 | 0 | > 0 |
| CPU Brokers | < 70% | > 70% |
| CPU MM2 Workers | < 80% | > 80% |

**Dashboards de monitoring (Grafana):**
- `mm2-replication` : Latence, Record Age, Throughput
- `mm2-detailed-metrics` : Tasks, Errors, Buffer
- `kafka-producer` : Métriques producer MM2
- `kafka-consumer` : Métriques consumer MM2

### 2.3 Détail Scénario PERF-02 : Montée en Charge Progressive

**Objectif :** Identifier le débit maximal soutenable et le point de saturation.

| Palier | Débit (msg/sec) | Durée | Observations |
|--------|-----------------|-------|--------------|
| P1 | 1000 msg/sec | 10 min | Baseline nominal |
| P2 | 1500 msg/sec | 10 min | +50% |
| P3 | 2000 msg/sec | 10 min | +100% |
| P4 | 2500 msg/sec | 10 min | +150% |
| P5 | 3000 msg/sec | 10 min | +200% (burst) |
| P6 | Max théorique | 10 min | Saturation |

**Étapes :**

1. Démarrer au palier P1
2. À chaque palier, attendre stabilisation (5 min)
3. Mesurer les métriques clés
4. Augmenter au palier suivant
5. Arrêter si critère KO atteint
6. Noter le palier maximal soutenable

**Critères de saturation :**

| Indicateur | Seuil de Saturation |
|------------|---------------------|
| Lag croissant | Lag augmente continuellement |
| CPU > 90% | Saturation CPU |
| Latence > 10s | Dégradation inacceptable |
| Erreurs | Apparition d'erreurs |
| Rebalancing | Instabilité Connect |

### 2.4 Détail Scénario PERF-03 : Charge de Pointe

**Objectif :** Valider la capacité à absorber des bursts de trafic.

| Paramètre | Valeur |
|-----------|--------|
| Débit burst | 3000 msg/sec (3x nominal) |
| Durée burst | 5 minutes |
| Pause entre bursts | 5 minutes |
| Nombre de bursts | 3 |
| Taille message | 1024 bytes (1 KB) |

**Pattern de charge :**

```
     Débit
       │
  3x ──┤    ┌────┐         ┌────┐         ┌────┐
       │    │    │         │    │         │    │
  1x ──┼────┘    └─────────┘    └─────────┘    └────
       │
       └──────────────────────────────────────────── Temps
           5min   5min     5min   5min     5min
```

**Critères de succès :**

| Métrique | Pendant Burst | Après Burst |
|----------|---------------|-------------|
| Lag | Augmentation acceptable (< 50000 records) | Retour à baseline |
| Erreurs | 0 | 0 |
| Messages perdus | 0 | 0 |
| Temps de rattrapage | - | < 15 min |

### 2.5 Détail Scénario PERF-04 : Test d'Endurance

**Objectif :** Valider la stabilité du système sur une longue période.

| Paramètre | Valeur |
|-----------|--------|
| Débit | 1000 msg/sec (nominal) |
| Durée | 8 heures minimum (idéal: 24h) |
| Taille message | 1024 bytes (1 KB) |
| Variation charge | ±10% (simulation production réelle) |

**Points de contrôle :**

| Moment | Vérification |
|--------|--------------|
| T+1h | État stable, pas de drift |
| T+2h | Mémoire JVM stable |
| T+4h | Pas de fuite mémoire |
| T+8h | Métriques dans les seuils |
| T+24h | Validation endurance |

**Critères de succès :**

| Métrique | Critère OK |
|----------|------------|
| Interruptions | 0 |
| Erreurs cumulées | 0 |
| Dérive lag | < 1000 records sur durée |
| Memory leak | Heap stable (±5%) |
| GC pauses | < 500ms P99 |

### 2.6 Détail Scénario PERF-05 : Messages Volumineux

**Objectif :** Mesurer l'impact de la taille des messages sur les performances.

| Taille Message | Débit (MB/sec) | Durée |
|----------------|----------------|-------|
| 100 bytes | Ajuster pour constant MB/sec | 15 min |
| 1 KB | Ajuster pour constant MB/sec | 15 min |
| 10 KB | Ajuster pour constant MB/sec | 15 min |
| 100 KB | Ajuster pour constant MB/sec | 15 min |
| 1 MB | Ajuster pour constant MB/sec | 15 min |

**Métriques à comparer :**

| Métrique | 100B | 1KB | 10KB | 100KB | 1MB |
|----------|------|-----|------|-------|-----|
| Throughput MB/sec | - | - | - | - | - |
| Throughput msg/sec | - | - | - | - | - |
| Latence P99 | - | - | - | - | - |
| CPU % | - | - | - | - | - |
| Network % | - | - | - | - | - |

### 2.7 Détail Scénario PERF-06 : Latence End-to-End

**Objectif :** Mesurer précisément la latence de réplication.

| Paramètre | Valeur |
|-----------|--------|
| Mode | Message par message avec timestamp |
| Nombre de mesures | 1000 |
| Intervalle | 1 seconde |
| Charge background | 1000 msg/sec (nominal) |

**Méthodologie :**

1. Charge de fond nominale sur topic test-mm2-perf
2. Messages de mesure sur topic test-mm2-latency (1 partition)
3. Timestamp embedded dans le message
4. Consumer sur cluster cible mesure la différence

**Métriques à produire :**

| Percentile | Latence (ms) |
|------------|--------------|
| Min | - |
| P50 | - |
| P75 | - |
| P90 | - |
| P95 | - |
| P99 | - |
| P99.9 | - |
| Max | - |

### 2.8 Détail Scénario PERF-07 : Rattrapage de Lag

**Objectif :** Mesurer la capacité de rattrapage après accumulation de retard.

| Phase | Action | Durée |
|-------|--------|-------|
| 1 | Production sans MM2 (lag artificiel) | 10 min |
| 2 | Démarrage MM2, mesure rattrapage | Jusqu'à lag=0 |
| 3 | Production continue pendant rattrapage | - |

**Scénarios de lag initial :**

| Scénario | Lag Initial | Temps Rattrapage Attendu |
|----------|-------------|--------------------------|
| Petit lag | 10,000 records | < 1 min |
| Lag moyen | 100,000 records | < 5 min |
| Grand lag | 1,000,000 records | < 30 min |

**Critères de succès :**

| Métrique | Critère OK |
|----------|------------|
| Temps de rattrapage | Conforme aux attentes |
| Messages perdus | 0 |
| Impact production | < 10% dégradation |

---

## 3. Environnement de Test

### 3.1 Configuration Topics de Test

| Topic | Partitions | RF | Retention | Cluster |
|-------|------------|-----|-----------|---------|
| test-mm2-perf | 6 | 3 | 24h | NEMO (Source) |
| test-mm2-latency | 1 | 3 | 24h | NEMO (Source) |
| test-mm2-large | 6 | 3 | 24h | NEMO (Source) |

### 3.2 Configuration Producer de Test

```properties
# producer-perf.properties - Transactis
bootstrap.servers=kafka-nemo-1:9093,kafka-nemo-2:9093,kafka-nemo-3:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="perf-test-user" \
    password="<PASSWORD>";
ssl.truststore.location=/etc/kafka/ssl/truststore.jks
ssl.truststore.password=<TRUSTSTORE_PASSWORD>

# Performance settings optimisés
acks=all
retries=3
batch.size=65536
linger.ms=5
buffer.memory=67108864
compression.type=lz4
max.in.flight.requests.per.connection=5
```

### 3.3 Configuration Consumer de Test

```properties
# consumer-perf.properties - Transactis
bootstrap.servers=kafka-app-1:9093,kafka-app-2:9093,kafka-app-3:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="perf-test-user" \
    password="<PASSWORD>";
ssl.truststore.location=/etc/kafka/ssl/truststore.jks
ssl.truststore.password=<TRUSTSTORE_PASSWORD>

# Performance settings optimisés
group.id=perf-consumer-group
auto.offset.reset=earliest
enable.auto.commit=true
fetch.min.bytes=1048576
fetch.max.wait.ms=500
max.poll.records=500
```

---

## 4. Planning d'Exécution

### 4.1 Ordre d'Exécution Recommandé

| Jour | Créneau | Scénario | Durée |
|------|---------|----------|-------|
| J1 | Matin | PERF-01 - Charge nominale | 1h30 |
| J1 | Après-midi | PERF-06 - Latence E2E | 1h |
| J1 | Après-midi | PERF-03 - Charge de pointe | 1h |
| J2 | Matin | PERF-02 - Montée en charge | 2h30 |
| J2 | Après-midi | PERF-07 - Rattrapage lag | 2h |
| J3 | Matin | PERF-05 - Messages volumineux | 2h |
| J3-J4 | Continu | PERF-04 - Endurance | 8-24h |

### 4.2 Temps Alloués par Scénario

| Scénario | Préparation | Exécution | Analyse | Total |
|----------|-------------|-----------|---------|-------|
| PERF-01 | 15 min | 60 min | 15 min | 1h30 |
| PERF-02 | 15 min | 120 min | 30 min | 2h45 |
| PERF-03 | 15 min | 30 min | 15 min | 1h |
| PERF-04 | 15 min | 480+ min | 60 min | 10h+ |
| PERF-05 | 15 min | 75 min | 30 min | 2h |
| PERF-06 | 15 min | 30 min | 15 min | 1h |
| PERF-07 | 15 min | 60 min | 30 min | 1h45 |

---

## 5. Checklist Pré-Test

### 5.1 Avant Chaque Scénario

- [ ] État du système vérifié (pas d'alertes actives)
- [ ] Baseline métriques notée
- [ ] Topics de test vérifiés
- [ ] Dashboards Grafana ouverts
- [ ] Enregistrement des métriques activé
- [ ] Équipe prévenue du test
- [ ] Procédure d'arrêt d'urgence prête

### 5.2 Après Chaque Scénario

- [ ] Métriques exportées
- [ ] Screenshots capturés
- [ ] Résultats notés dans le tableau
- [ ] Anomalies documentées
- [ ] Système remis à l'état nominal
- [ ] Topics nettoyés si nécessaire

---

## 6. Critères Go / No-Go Global

| Critère | Seuil | Importance |
|---------|-------|------------|
| PERF-01 réussi | Tous critères OK | Bloquant |
| PERF-02 réussi | Palier 2x nominal (2000 msg/s) atteint | Bloquant |
| PERF-06 P99 | < 500 ms | Bloquant |
| PERF-03 réussi | Rattrapage < 15 min | Important |
| PERF-04 réussi | 8h sans incident | Important |

---

## Artifacts Produits

- [ ] Résultats détaillés par scénario
- [ ] Fichiers CSV de métriques brutes
- [ ] Rapport de synthèse performance
- [ ] Graphiques comparatifs baseline vs charge

---

**Client** : Transactis
**Confluent Platform** : 7.7.3
**SLA** : < 1h downtime annuel (99.9886%)
**Version** : 2.0
