# Métriques MTTR et RPO - Tests de Résilience MirrorMaker 2

## Objectif

Définir les métriques de résilience (MTTR, MTBF, RPO, RTO) à mesurer, les méthodes de calcul, et les seuils de conformité SLA.

---

## Pré-requis

- [ ] Scénarios de pannes exécutés (`scenarios-pannes.md`)
- [ ] Monitoring actif pendant les tests
- [ ] Timestamps des événements capturés

---

## 1. Définitions des Métriques

### 1.1 Glossaire

| Métrique | Définition | Unité |
|----------|------------|-------|
| **MTTR** | Mean Time To Recovery - Temps moyen de restauration | Minutes |
| **MTBF** | Mean Time Between Failures - Temps moyen entre pannes | Heures |
| **RTO** | Recovery Time Objective - Temps de restauration maximal acceptable | Minutes |
| **RPO** | Recovery Point Objective - Perte de données maximale acceptable | Secondes/Messages |
| **Disponibilité** | (MTBF - MTTR) / MTBF × 100 | % |

### 1.2 Objectifs Liés au SLA

| Métrique | Objectif SLA | Justification |
|----------|--------------|---------------|
| MTTR | < `${RTO_MINUTES}` min | Budget 60 min/an, incidents multiples possibles |
| RTO | < `${RTO_MINUTES}` min | Temps max restauration par incident |
| RPO | < `${RPO_SECONDS}` sec | Perte données acceptable |
| Disponibilité | > 99.9886% | < 1h indisponibilité/an |

---

## 2. Méthodes de Mesure du MTTR

### 2.1 Définition des Phases de Reprise

```
Timeline d'un incident:

T0          T1              T2              T3              T4
│           │               │               │               │
▼           ▼               ▼               ▼               ▼
┌───────────┬───────────────┬───────────────┬───────────────┐
│  PANNE    │   DÉTECTION   │   RÉPARATION  │   VALIDATION  │ NOMINAL
└───────────┴───────────────┴───────────────┴───────────────┘

MTTR = T4 - T0
TTD  = T1 - T0  (Time To Detect)
TTR  = T3 - T1  (Time To Repair)
TTV  = T4 - T3  (Time To Validate)
```

### 2.2 Critères de Définition des Phases

| Phase | Début | Fin | Indicateur |
|-------|-------|-----|------------|
| **Panne (T0)** | Injection de la panne | - | Timestamp commande |
| **Détection (T1)** | Panne injectée | Alerte déclenchée | Première alerte/log d'erreur |
| **Réparation (T3)** | Début intervention | Service restauré | Connecteurs RUNNING |
| **Validation (T4)** | Service restauré | Retour nominal | Lag = 0, pas d'erreurs |

### 2.3 Scripts de Mesure MTTR

```bash
#!/bin/bash
# measure-mttr.sh
# Usage: ./measure-mttr.sh <scenario_id>

SCENARIO=$1
RESULTS_FILE="mttr-$SCENARIO-$(date +%Y%m%d-%H%M%S).json"

# Initialisation
cat > $RESULTS_FILE << EOF
{
    "scenario": "$SCENARIO",
    "timestamps": {},
    "metrics": {}
}
EOF

# Fonction pour enregistrer un timestamp
record_timestamp() {
    local phase=$1
    local ts=$(date +%s%3N)
    jq ".timestamps.$phase = $ts" $RESULTS_FILE > tmp.json && mv tmp.json $RESULTS_FILE
    echo "[$phase] Timestamp enregistré: $ts"
}

# Fonction pour attendre un état
wait_for_state() {
    local check_cmd=$1
    local expected=$2
    local timeout=$3
    local start=$(date +%s)

    while true; do
        result=$(eval $check_cmd 2>/dev/null)
        if [ "$result" = "$expected" ]; then
            return 0
        fi
        elapsed=$(($(date +%s) - start))
        if [ $elapsed -gt $timeout ]; then
            return 1
        fi
        sleep 1
    done
}

# Mesure automatique pour RES-01 (exemple)
if [ "$SCENARIO" = "RES-01" ]; then
    echo "=== Mesure MTTR pour RES-01 ==="

    # T0: Injection panne
    record_timestamp "T0_panne"
    ssh $SSH_USER@$SRC_BROKER_1 "sudo systemctl stop $KAFKA_SERVICE"

    # T1: Détection (quand MM2 détecte un problème)
    echo "Attente détection..."
    while true; do
        errors=$(curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status | jq '.tasks[].trace // empty' | wc -l)
        if [ "$errors" -gt 0 ]; then
            record_timestamp "T1_detection"
            break
        fi
        sleep 1
    done

    # T2: Début réparation (automatique via failover Kafka)
    record_timestamp "T2_repair_start"

    # T3: Service restauré (MM2 fonctionne à nouveau)
    echo "Attente reprise service..."
    wait_for_state "curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status | jq -r '.connector.state'" "RUNNING" 300
    record_timestamp "T3_service_restored"

    # Redémarrer le broker pour T4
    ssh $SSH_USER@$SRC_BROKER_1 "sudo systemctl start $KAFKA_SERVICE"

    # T4: Validation (lag revenu à baseline)
    echo "Attente validation (lag = 0)..."
    wait_for_state "curl -s 'http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag)' | jq -r '.data.result[0].value[1] // 0' | cut -d. -f1" "0" 600
    record_timestamp "T4_validated"

    # Calcul des métriques
    T0=$(jq -r '.timestamps.T0_panne' $RESULTS_FILE)
    T1=$(jq -r '.timestamps.T1_detection' $RESULTS_FILE)
    T3=$(jq -r '.timestamps.T3_service_restored' $RESULTS_FILE)
    T4=$(jq -r '.timestamps.T4_validated' $RESULTS_FILE)

    TTD=$(( (T1 - T0) / 1000 ))
    TTR=$(( (T3 - T1) / 1000 ))
    TTV=$(( (T4 - T3) / 1000 ))
    MTTR=$(( (T4 - T0) / 1000 ))

    jq ".metrics = {\"TTD_sec\": $TTD, \"TTR_sec\": $TTR, \"TTV_sec\": $TTV, \"MTTR_sec\": $MTTR}" $RESULTS_FILE > tmp.json && mv tmp.json $RESULTS_FILE

    echo ""
    echo "=== Résultats MTTR ==="
    echo "TTD (Time To Detect): $TTD sec"
    echo "TTR (Time To Repair): $TTR sec"
    echo "TTV (Time To Validate): $TTV sec"
    echo "MTTR Total: $MTTR sec ($((MTTR / 60)) min)"
    echo ""
    echo "Résultats sauvegardés dans $RESULTS_FILE"
fi
```

---

## 3. Méthodes de Mesure du RPO

### 3.1 Définition du RPO

Le RPO mesure la quantité de données potentiellement perdues lors d'un incident.

**Types de mesure :**

| Type | Description | Métrique |
|------|-------------|----------|
| **RPO temporel** | Temps entre dernier message répliqué et panne | Secondes |
| **RPO volumétrique** | Nombre de messages non répliqués | Records |

### 3.2 Méthode de Mesure RPO

```bash
#!/bin/bash
# measure-rpo.sh

# Capturer l'offset avant panne
get_current_offset() {
    local cluster=$1
    local bootstrap=$2
    local topic=$3

    $KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
        --broker-list $bootstrap \
        --topic $topic \
        --time -1 \
        --command-config $CLIENT_CONFIG 2>/dev/null \
        | awk -F: '{sum+=$3} END {print sum}'
}

# === Avant la panne ===
TOPIC="test-mm2-perf"
TOPIC_REPLICATED="${SOURCE_CLUSTER_ALIAS}.test-mm2-perf"

# Offset source (dernier message produit)
OFFSET_SOURCE_BEFORE=$(get_current_offset "source" $SRC_BOOTSTRAP $TOPIC)
echo "Offset source avant panne: $OFFSET_SOURCE_BEFORE"

# Offset cible (dernier message répliqué)
OFFSET_TARGET_BEFORE=$(get_current_offset "target" $TGT_BOOTSTRAP $TOPIC_REPLICATED)
echo "Offset cible avant panne: $OFFSET_TARGET_BEFORE"

# Lag avant panne
LAG_BEFORE=$((OFFSET_SOURCE_BEFORE - OFFSET_TARGET_BEFORE))
echo "Lag avant panne: $LAG_BEFORE records"

# === PANNE ===
echo "Injection de la panne..."
# ... (commande de panne)

# Continuer la production pendant la panne
MESSAGES_DURING_PANNE=10000
$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic $TOPIC \
    --num-records $MESSAGES_DURING_PANNE \
    --record-size 100 \
    --throughput -1 \
    --producer.config $PRODUCER_CONFIG &

PROD_PID=$!

# === Après restauration ===
# ... (commande de restauration)

# Attendre fin production
wait $PROD_PID

# Offset source après (total produit)
OFFSET_SOURCE_AFTER=$(get_current_offset "source" $SRC_BOOTSTRAP $TOPIC)
echo "Offset source après: $OFFSET_SOURCE_AFTER"

# Attendre la réplication complète
echo "Attente réplication complète..."
while true; do
    OFFSET_TARGET_CURRENT=$(get_current_offset "target" $TGT_BOOTSTRAP $TOPIC_REPLICATED)
    if [ "$OFFSET_TARGET_CURRENT" -ge "$OFFSET_SOURCE_AFTER" ]; then
        break
    fi
    echo "Réplication en cours: $OFFSET_TARGET_CURRENT / $OFFSET_SOURCE_AFTER"
    sleep 5
done

OFFSET_TARGET_AFTER=$(get_current_offset "target" $TGT_BOOTSTRAP $TOPIC_REPLICATED)
echo "Offset cible après: $OFFSET_TARGET_AFTER"

# Calcul RPO
MESSAGES_PRODUCED=$((OFFSET_SOURCE_AFTER - OFFSET_SOURCE_BEFORE))
MESSAGES_REPLICATED=$((OFFSET_TARGET_AFTER - OFFSET_TARGET_BEFORE))
MESSAGES_LOST=$((MESSAGES_PRODUCED - MESSAGES_REPLICATED))

echo ""
echo "=== Résultats RPO ==="
echo "Messages produits pendant incident: $MESSAGES_PRODUCED"
echo "Messages répliqués: $MESSAGES_REPLICATED"
echo "Messages potentiellement perdus (RPO): $MESSAGES_LOST"

if [ "$MESSAGES_LOST" -eq 0 ]; then
    echo "✅ RPO = 0 (aucune perte)"
else
    echo "⚠️  RPO = $MESSAGES_LOST messages"
fi
```

### 3.3 Validation de l'Intégrité des Données

```bash
#!/bin/bash
# validate-data-integrity.sh

# Vérifier que tous les messages ont été répliqués correctement
# en comparant les checksums

TOPIC="test-mm2-perf"
TOPIC_REPLICATED="${SOURCE_CLUSTER_ALIAS}.test-mm2-perf"
NUM_MESSAGES=1000

# Consumer sur source - calculer hash des messages
echo "Calcul hash messages source..."
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --topic $TOPIC \
    --consumer.config $CLIENT_CONFIG \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null | md5sum > /tmp/source-hash.txt

# Consumer sur cible - calculer hash des messages
echo "Calcul hash messages cible..."
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server $TGT_BOOTSTRAP \
    --topic $TOPIC_REPLICATED \
    --consumer.config $CLIENT_CONFIG \
    --from-beginning \
    --max-messages $NUM_MESSAGES \
    --timeout-ms 30000 2>/dev/null | md5sum > /tmp/target-hash.txt

# Comparer
SOURCE_HASH=$(cat /tmp/source-hash.txt | awk '{print $1}')
TARGET_HASH=$(cat /tmp/target-hash.txt | awk '{print $1}')

echo ""
echo "=== Validation Intégrité ==="
echo "Hash source: $SOURCE_HASH"
echo "Hash cible:  $TARGET_HASH"

if [ "$SOURCE_HASH" = "$TARGET_HASH" ]; then
    echo "✅ Intégrité validée - Messages identiques"
else
    echo "❌ Écart détecté - Messages différents"
fi
```

---

## 4. Tableau de Mesure par Scénario

### 4.1 Template de Résultats MTTR

| Scénario | T0 (Panne) | T1 (Détection) | T3 (Restauré) | T4 (Validé) | TTD | TTR | TTV | MTTR |
|----------|------------|----------------|---------------|-------------|-----|-----|-----|------|
| RES-01 | - | - | - | - | - s | - s | - s | - s |
| RES-02 | - | - | - | - | - s | - s | - s | - s |
| RES-03 | - | - | - | - | - s | - s | - s | - s |
| RES-04 | - | - | - | - | - s | - s | - s | - s |
| RES-05 | - | - | - | - | - s | - s | - s | - s |
| RES-06 | - | - | - | - | - s | - s | - s | - s |
| RES-08 | - | - | - | - | - s | - s | - s | - s |
| RES-09 | - | - | - | - | - s | - s | - s | - s |

### 4.2 Template de Résultats RPO

| Scénario | Messages Produits | Messages Répliqués | Messages Perdus | RPO (records) | RPO (temps estimé) |
|----------|-------------------|-------------------|-----------------|---------------|-------------------|
| RES-01 | - | - | - | - | - s |
| RES-02 | - | - | - | - | - s |
| RES-03 | - | - | - | - | - s |
| RES-06 | - | - | - | - | - s |

### 4.3 Synthèse MTTR par Composant

| Composant | MTTR Mesuré | RTO Cible | Conforme | Observations |
|-----------|-------------|-----------|----------|--------------|
| Kafka Broker Source | - sec | `${RTO_BROKER}` sec | ✅/❌ | - |
| Kafka Broker Cible | - sec | `${RTO_BROKER}` sec | ✅/❌ | - |
| Worker MM2 | - sec | `${RTO_MM2}` sec | ✅/❌ | - |
| ZooKeeper | - sec | `${RTO_ZK}` sec | ✅/❌ | - |
| Réseau | - sec | `${RTO_NETWORK}` sec | ✅/❌ | - |

---

## 5. Alerting pour Détection Rapide

### 5.1 Règles d'Alerte Prometheus

```yaml
# alerting-rules-resilience.yml

groups:
  - name: mm2-resilience
    rules:
      # Détection panne MM2
      - alert: MM2ConnectorDown
        expr: kafka_connect_connector_status{status="running"} == 0
        for: 10s
        labels:
          severity: critical
        annotations:
          summary: "MM2 Connector {{ $labels.connector }} is down"
          description: "Le connecteur MM2 n'est plus en état RUNNING"

      # Détection lag anormal
      - alert: MM2LagSpike
        expr: |
          (sum(kafka_consumer_fetch_manager_records_lag{job="mm2-connect"})
          - sum(kafka_consumer_fetch_manager_records_lag{job="mm2-connect"} offset 1m))
          > 10000
        for: 30s
        labels:
          severity: warning
        annotations:
          summary: "MM2 lag spike detected"
          description: "Le lag MM2 augmente rapidement (> 10000 records/min)"

      # Détection broker down
      - alert: KafkaBrokerDown
        expr: up{job=~"kafka-source|kafka-target"} == 0
        for: 10s
        labels:
          severity: critical
        annotations:
          summary: "Kafka broker {{ $labels.instance }} is down"

      # Détection URP
      - alert: KafkaUnderReplicatedPartitions
        expr: sum(kafka_server_replicamanager_underreplicatedpartitions) > 0
        for: 30s
        labels:
          severity: warning
        annotations:
          summary: "Under-replicated partitions detected"
          description: "{{ $value }} partitions sont under-replicated"

      # Détection ZooKeeper down
      - alert: ZooKeeperDown
        expr: up{job="zookeeper"} == 0
        for: 10s
        labels:
          severity: critical
        annotations:
          summary: "ZooKeeper {{ $labels.instance }} is down"
```

### 5.2 Mesure du TTD via Alertmanager

```python
#!/usr/bin/env python3
# analyze-ttd.py
# Analyse le temps de détection à partir des alertes Alertmanager

import requests
import json
from datetime import datetime

ALERTMANAGER_URL = "http://${ALERTMANAGER_HOST}:9093"

def get_alerts_history():
    """Récupère l'historique des alertes"""
    response = requests.get(f"{ALERTMANAGER_URL}/api/v2/alerts")
    return response.json()

def calculate_ttd(incident_time, alert_time):
    """Calcule le TTD en secondes"""
    incident_dt = datetime.fromisoformat(incident_time)
    alert_dt = datetime.fromisoformat(alert_time)
    return (alert_dt - incident_dt).total_seconds()

# Exemple d'utilisation
incident_start = "2024-01-15T10:30:00Z"  # Timestamp injection panne
alerts = get_alerts_history()

for alert in alerts:
    if alert['labels']['alertname'] == 'MM2ConnectorDown':
        alert_time = alert['startsAt']
        ttd = calculate_ttd(incident_start, alert_time)
        print(f"TTD pour {alert['labels']['alertname']}: {ttd} secondes")
```

---

## 6. Calcul de la Disponibilité

### 6.1 Formule de Calcul

```
Disponibilité (%) = ((Temps Total - Temps Indisponibilité) / Temps Total) × 100

Temps Total = 365 jours × 24 heures × 60 minutes = 525,600 minutes/an

Pour SLA 99.9886% :
Temps Indisponibilité Max = 525,600 × (1 - 0.999886) = 59.9 minutes ≈ 60 minutes/an
```

### 6.2 Calcul à partir des MTTR Mesurés

```bash
#!/bin/bash
# calculate-availability.sh

# Données des tests
# Format: MTTR en secondes pour chaque type d'incident
declare -A MTTR_RESULTS
MTTR_RESULTS=(
    ["RES-01"]=30      # Panne broker source
    ["RES-02"]=30      # Panne broker cible
    ["RES-03"]=60      # Panne worker MM2
    ["RES-04"]=10      # Panne ZK (quorum maintenu)
    ["RES-06"]=120     # Panne réseau
)

# Fréquence estimée des incidents par an
declare -A INCIDENT_FREQUENCY
INCIDENT_FREQUENCY=(
    ["RES-01"]=4       # 4 pannes broker/an estimées
    ["RES-02"]=4
    ["RES-03"]=2
    ["RES-04"]=2
    ["RES-06"]=1
)

# Calcul du temps d'indisponibilité annuel estimé
TOTAL_DOWNTIME=0
echo "=== Estimation Temps d'Indisponibilité Annuel ==="
echo ""

for scenario in "${!MTTR_RESULTS[@]}"; do
    mttr=${MTTR_RESULTS[$scenario]}
    freq=${INCIDENT_FREQUENCY[$scenario]}
    downtime=$((mttr * freq))

    echo "$scenario: MTTR=${mttr}s × Fréquence=${freq}/an = ${downtime}s"
    TOTAL_DOWNTIME=$((TOTAL_DOWNTIME + downtime))
done

echo ""
echo "Temps d'indisponibilité total estimé: ${TOTAL_DOWNTIME}s ($(echo "scale=2; $TOTAL_DOWNTIME/60" | bc) min)"

# Calcul disponibilité
SECONDS_PER_YEAR=31536000  # 365 × 24 × 60 × 60
AVAILABILITY=$(echo "scale=6; (($SECONDS_PER_YEAR - $TOTAL_DOWNTIME) / $SECONDS_PER_YEAR) * 100" | bc)

echo "Disponibilité calculée: ${AVAILABILITY}%"

# Vérification SLA
SLA_TARGET=99.9886
if (( $(echo "$AVAILABILITY >= $SLA_TARGET" | bc -l) )); then
    echo "✅ Conforme au SLA ($SLA_TARGET%)"
else
    echo "❌ Non conforme au SLA ($SLA_TARGET%)"
    MARGIN=$(echo "scale=4; $SLA_TARGET - $AVAILABILITY" | bc)
    echo "   Écart: ${MARGIN}%"
fi
```

---

## 7. Rapport de Métriques de Résilience

### 7.1 Template de Rapport

```markdown
# Rapport de Résilience MirrorMaker 2

**Date du rapport:** ${REPORT_DATE}
**Période de test:** Du ${TEST_START_DATE} au ${TEST_END_DATE}
**Version testée:** MM2 ${MM2_VERSION} / Kafka ${KAFKA_VERSION}

## 1. Résumé Exécutif

| Métrique | Objectif | Mesuré | Verdict |
|----------|----------|--------|---------|
| MTTR Moyen | < ${RTO_MINUTES} min | X min | ✅/❌ |
| RPO Max | < ${RPO_SECONDS} sec | X sec | ✅/❌ |
| Disponibilité Estimée | > 99.9886% | X% | ✅/❌ |
| Tests Réussis | 100% | X% | ✅/❌ |

## 2. Détail des Tests

### 2.1 MTTR par Scénario

[Tableau MTTR]

### 2.2 RPO par Scénario

[Tableau RPO]

## 3. Analyse des Résultats

### 3.1 Points Forts
- [Point fort 1]
- [Point fort 2]

### 3.2 Points d'Amélioration
- [Point amélioration 1]
- [Point amélioration 2]

## 4. Conformité SLA

### 4.1 Calcul de Disponibilité
[Détail du calcul]

### 4.2 Budget d'Indisponibilité
- Budget annuel: 60 minutes
- Consommation estimée: X minutes
- Marge restante: Y minutes

## 5. Recommandations

1. [Recommandation 1]
2. [Recommandation 2]
3. [Recommandation 3]

## 6. Conclusion

[Verdict final et prochaines étapes]
```

---

## 8. Critères de Conformité

### 8.1 Matrice de Conformité MTTR

| Scénario | MTTR Max Acceptable | MTTR Mesuré | Conforme |
|----------|---------------------|-------------|----------|
| RES-01 | 60 sec | - | [ ] |
| RES-02 | 60 sec | - | [ ] |
| RES-03 | 120 sec | - | [ ] |
| RES-04 | 30 sec | - | [ ] |
| RES-05 | 30 sec | - | [ ] |
| RES-06 | 300 sec | - | [ ] |
| RES-08 | 0 sec (rolling) | - | [ ] |
| RES-09 | 60 sec | - | [ ] |

### 8.2 Matrice de Conformité RPO

| Scénario | RPO Max Acceptable | RPO Mesuré | Conforme |
|----------|-------------------|------------|----------|
| Tous scénarios | 0 messages | - | [ ] |

---

## Artifacts Produits

- [ ] Fichiers JSON de mesures MTTR (`mttr-*.json`)
- [ ] Fichiers CSV de monitoring (`resilience-monitor-*.csv`)
- [ ] Rapport de résilience
- [ ] Matrices de conformité complétées

---

**Auteur** : `${AUTHOR_NAME}`
**Date de création** : `${DATE_CREATION}`
**Version** : 1.0
