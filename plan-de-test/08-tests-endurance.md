# Section 8 : Tests d'Endurance

**Objectif** : Valider la stabilité du système sur une durée prolongée (24h)  
**Durée estimée** : 24 heures  
**Prérequis** : Toutes les sections précédentes validées  
**SLA cible** : Disponibilité 99.989% sur la durée du test

---

## 8.1 Objectifs de cette Section

| Objectif | Description | Critère |
|----------|-------------|---------|
| Stabilité | Pas de dégradation dans le temps | Métriques stables ±10% |
| Fuites mémoire | Détection de memory leaks | Heap stable |
| Disk growth | Croissance disque maîtrisée | Selon retention |
| Performance | Latence stable sur 24h | P99 < 100 ms |

---

## 8.2 Configuration du Test d'Endurance

### Paramètres de Charge

| Paramètre | Valeur |
|-----------|--------|
| Durée totale | 24 heures |
| Throughput production | 3000 msg/s (sous le point d'équilibre) |
| Taille message | 1 KB |
| Topics | 10 topics répliqués |
| Partitions par topic | 6 |
| Consumer groups | 5 |

### Volume Total Attendu

| Métrique | Calcul | Valeur |
|----------|--------|--------|
| Messages/heure | 3000 × 3600 | 10.8M |
| Messages/jour | 10.8M × 24 | 259.2M |
| Volume/jour | 259.2M × 1 KB | ~250 GB |
| Volume avec RF=3 | 250 GB × 3 | ~750 GB |

---

## 8.3 Script de Lancement

### Producteur Continu

```bash
#!/bin/bash
# endurance-producer.sh

TOPICS="endurance-topic-{01..10}"
THROUGHPUT_PER_TOPIC=300  # 300 × 10 = 3000 msg/s total
RECORD_SIZE=1024

for TOPIC in $(eval echo $TOPICS); do
  echo "Démarrage producteur pour ${TOPIC}"
  kafka-producer-perf-test \
    --topic ${TOPIC} \
    --num-records 999999999 \
    --record-size ${RECORD_SIZE} \
    --throughput ${THROUGHPUT_PER_TOPIC} \
    --producer.config producer-tls.properties &
done

echo "Tous les producteurs démarrés"
wait
```

### Consommateurs Continus

```bash
#!/bin/bash
# endurance-consumer.sh

TOPICS="endurance-topic-{01..10}"

for TOPIC in $(eval echo $TOPICS); do
  for GROUP in {1..5}; do
    kafka-console-consumer \
      --bootstrap-server ${BOOTSTRAP_SERVERS} \
      --topic ${TOPIC} \
      --group endurance-group-${GROUP} \
      --consumer.config consumer-tls.properties &
  done
done

wait
```

### Collecte Métriques Horaire

```bash
#!/bin/bash
# endurance-monitor.sh

LOG_FILE="/var/log/endurance-test-$(date +%Y%m%d).log"

while true; do
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Métriques Kafka
  THROUGHPUT=$(curl -s "http://prometheus:9090/api/v1/query?query=sum(rate(kafka_server_brokertopicmetrics_messagesinpersec[5m]))" | jq -r '.data.result[0].value[1]')
  LATENCY_P99=$(curl -s "http://prometheus:9090/api/v1/query?query=histogram_quantile(0.99, kafka_network_requestmetrics_totaltimems)" | jq -r '.data.result[0].value[1]')
  UNDER_REP=$(curl -s "http://prometheus:9090/api/v1/query?query=sum(kafka_server_replicamanager_underreplicatedpartitions)" | jq -r '.data.result[0].value[1]')
  
  # Métriques JVM
  HEAP_USED=$(curl -s "http://prometheus:9090/api/v1/query?query=avg(jvm_memory_bytes_used{area=\"heap\"})" | jq -r '.data.result[0].value[1]')
  
  # Métriques système
  CPU=$(curl -s "http://prometheus:9090/api/v1/query?query=avg(100-irate(node_cpu_seconds_total{mode=\"idle\"}[5m])*100)" | jq -r '.data.result[0].value[1]')
  DISK_USED=$(curl -s "http://prometheus:9090/api/v1/query?query=sum(node_filesystem_size_bytes-node_filesystem_avail_bytes)" | jq -r '.data.result[0].value[1]')
  
  # MM2 lag
  MM2_LAG=$(curl -s http://connect:8083/connectors/mirror-source/status | jq -r '.tasks[0].trace // "0"')
  
  echo "${TIMESTAMP},${THROUGHPUT},${LATENCY_P99},${UNDER_REP},${HEAP_USED},${CPU},${DISK_USED},${MM2_LAG}" >> ${LOG_FILE}
  
  sleep 300  # Toutes les 5 minutes
done
```

---

## 8.4 Grille de Suivi Horaire

### Template de Collecte

| Heure | Throughput | Latency P99 | Under-Rep | Heap (MB) | CPU % | Disk (GB) | MM2 Lag |
|-------|------------|-------------|-----------|-----------|-------|-----------|---------|
| H+0 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+1 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+2 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+3 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+4 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+6 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+8 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+12 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+16 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+20 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |
| H+24 | _____ | _____ ms | _____ | _____ | _____ | _____ | _____ |

---

## 8.5 Points de Contrôle

### Toutes les 4 Heures

| Contrôle | H+4 | H+8 | H+12 | H+16 | H+20 | H+24 |
|----------|-----|-----|------|------|------|------|
| Tous brokers UP | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| ZK quorum stable | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Connect workers UP | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| MM2 connecteurs RUNNING | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Under-rep = 0 | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Latence P99 < 100ms | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Aucune erreur log | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Disk < 80% | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

---

## 8.6 Analyse de Tendance

### Métriques à Analyser

#### 8.6.1 Heap Memory

```
Tendance attendue: Stable avec cycles GC réguliers
Alerte si: Croissance linéaire continue (memory leak)
```

| Heure | Heap Used (MB) | Heap Max (MB) | % Utilisé |
|-------|----------------|---------------|-----------|
| H+0 | _____ | _____ | _____% |
| H+12 | _____ | _____ | _____% |
| H+24 | _____ | _____ | _____% |

**Tendance** : ☐ Stable ☐ Croissante ☐ Variable

#### 8.6.2 Latence

```
Tendance attendue: Stable dans le temps
Alerte si: Dégradation progressive
```

| Heure | Latence Avg | Latence P95 | Latence P99 |
|-------|-------------|-------------|-------------|
| H+0 | _____ ms | _____ ms | _____ ms |
| H+12 | _____ ms | _____ ms | _____ ms |
| H+24 | _____ ms | _____ ms | _____ ms |

**Variation P99** : _____ % (cible < 20%)

#### 8.6.3 Disk Usage

```
Tendance attendue: Croissance puis stabilisation (retention)
Alerte si: Croissance plus rapide que prévu
```

| Heure | Disk Used (GB) | Croissance | Estimation 7j |
|-------|----------------|------------|---------------|
| H+0 | _____ | - | - |
| H+12 | _____ | +_____ GB | _____ GB |
| H+24 | _____ | +_____ GB | _____ GB |

---

## 8.7 Tests Chaos Pendant Endurance

### Événements à Injecter (optionnel)

| Heure | Événement | Impact Attendu | Récupération |
|-------|-----------|----------------|--------------|
| H+6 | Restart broker 1 | < 30s interruption | Auto |
| H+12 | Kill -9 worker Connect | Rebalancing < 60s | Auto |
| H+18 | Network delay 50ms inter-AZ | Latence augmentée | Auto |

### Résultats Chaos

| Événement | Durée Impact | Erreurs | Récupération OK |
|-----------|--------------|---------|-----------------|
| Restart broker | _____ s | _____ | ☐ Oui ☐ Non |
| Kill worker | _____ s | _____ | ☐ Oui ☐ Non |
| Network delay | _____ s | _____ | ☐ Oui ☐ Non |

---

## 8.8 Critères de Succès

### Métriques de Stabilité

| Métrique | Variation Max Tolérée | Observée | Statut |
|----------|----------------------|----------|--------|
| Throughput | ±10% | _____% | ☐ OK |
| Latence P99 | ±20% | _____% | ☐ OK |
| CPU | ±15% | _____% | ☐ OK |
| Heap | ±20% (hors GC) | _____% | ☐ OK |

### Critères d'Arrêt d'Urgence

| Condition | Action |
|-----------|--------|
| Under-rep > 0 pendant 30 min | Investigation |
| Latence P99 > 500 ms | Investigation |
| Heap > 90% continu | Arrêt test |
| Disk > 90% | Arrêt test |
| Perte de données | Arrêt immédiat |

---

## 8.9 Rapport de Fin de Test

### Synthèse Globale

| Métrique | Début | Fin | Variation |
|----------|-------|-----|-----------|
| Throughput moyen | _____ msg/s | _____ msg/s | _____% |
| Latence P99 moyenne | _____ ms | _____ ms | _____% |
| Messages totaux produits | 0 | _____ | - |
| Messages totaux répliqués | 0 | _____ | - |
| Erreurs totales | 0 | _____ | - |
| Downtime total | 0 | _____ s | - |

### Disponibilité Calculée

```
Disponibilité = (Durée Test - Downtime) / Durée Test × 100

Durée test: 24 heures = 86400 secondes
Downtime observé: _____ secondes

Disponibilité: ((86400 - _____) / 86400) × 100 = _____% 

Cible SLA: 99.989%
Résultat: ☐ PASS ☐ FAIL
```

---

## 8.10 Checklist de Fin de Section

### Validation

- [ ] Test d'endurance 24h exécuté
- [ ] Métriques collectées toutes les 5 minutes
- [ ] Points de contrôle toutes les 4 heures validés
- [ ] Analyse de tendance réalisée
- [ ] Tests chaos (optionnels) exécutés
- [ ] Rapport de fin généré

### Résultat Global Section 8

| Critère | Statut |
|---------|--------|
| Stabilité 24h | ☐ PASS ☐ FAIL |
| Pas de memory leak | ☐ PASS ☐ FAIL |
| Latence stable | ☐ PASS ☐ FAIL |
| Disponibilité > 99.989% | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests de Réplication Bout-en-Bout](07-tests-replication-e2e.md)  
**Section suivante** : [Tests de Monitoring et Alerting](09-tests-monitoring-alerting.md)
