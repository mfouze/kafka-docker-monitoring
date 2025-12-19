# Commandes de Simulation d'Incidents - Tests de Résilience MirrorMaker 2

## Objectif

Fournir les commandes exactes pour simuler chaque scénario de panne défini dans `scenarios-pannes.md`.

---

## Pré-requis

- [ ] Accès SSH aux serveurs avec privilèges sudo
- [ ] Scripts de monitoring prêts
- [ ] Procédures de rollback validées
- [ ] Équipe prévenue du test

---

## 1. Variables d'Environnement

```bash
# Charger avant chaque session
export KAFKA_HOME="${KAFKA_INSTALL_PATH}"
export SSH_USER="${SSH_USER}"
export SSH_KEY="${SSH_KEY_PATH}"

# Brokers Source
export SRC_BROKER_1="${SRC_BROKER_1_HOST}"
export SRC_BROKER_2="${SRC_BROKER_2_HOST}"
export SRC_BROKER_3="${SRC_BROKER_3_HOST}"
export SRC_BOOTSTRAP="${SRC_BOOTSTRAP_SERVERS}"

# Brokers Cible
export TGT_BROKER_1="${TGT_BROKER_1_HOST}"
export TGT_BROKER_2="${TGT_BROKER_2_HOST}"
export TGT_BROKER_3="${TGT_BROKER_3_HOST}"
export TGT_BOOTSTRAP="${TGT_BOOTSTRAP_SERVERS}"

# ZooKeeper
export SRC_ZK_1="${SRC_ZK_1_HOST}"
export SRC_ZK_2="${SRC_ZK_2_HOST}"
export SRC_ZK_3="${SRC_ZK_3_HOST}"
export TGT_ZK_1="${TGT_ZK_1_HOST}"

# MirrorMaker 2
export MM2_WORKER_1="${MM2_WORKER_1_HOST}"
export MM2_WORKER_2="${MM2_WORKER_2_HOST}"
export MM2_WORKER_3="${MM2_WORKER_3_HOST}"
export CONNECT_PORT="${CONNECT_REST_PORT}"

# Services
export KAFKA_SERVICE="${KAFKA_SERVICE_NAME}"
export ZK_SERVICE="${ZOOKEEPER_SERVICE_NAME}"
export MM2_SERVICE="${MM2_SERVICE_NAME}"

# Configurations
export CLIENT_CONFIG="${TEST_CONFIG_PATH}/client-test.properties"
```

---

## 2. Scripts de Monitoring Communs

### 2.1 Script de Monitoring Continu

```bash
#!/bin/bash
# monitor-resilience.sh
# Lancer dans un terminal séparé pendant les tests

LOG_FILE="resilience-monitor-$(date +%Y%m%d-%H%M%S).csv"
echo "timestamp,mm2_lag,mm2_state,src_urp,tgt_urp,cpu_src,cpu_tgt" > $LOG_FILE

while true; do
    TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)

    # Lag MM2
    LAG=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag{job=\"mm2-connect\"})" \
        | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)

    # État connecteurs
    STATE=$(curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status 2>/dev/null \
        | jq -r '.connector.state // "UNKNOWN"')

    # Under-replicated partitions Source
    SRC_URP=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_server_replicamanager_underreplicatedpartitions{job=\"kafka-source\"})" \
        | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)

    # Under-replicated partitions Cible
    TGT_URP=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_server_replicamanager_underreplicatedpartitions{job=\"kafka-target\"})" \
        | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)

    # CPU
    CPU_SRC=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=avg(100-rate(node_cpu_seconds_total{mode=\"idle\",job=\"kafka-source\"}[1m])*100)" \
        | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)

    CPU_TGT=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=avg(100-rate(node_cpu_seconds_total{mode=\"idle\",job=\"kafka-target\"}[1m])*100)" \
        | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)

    echo "$TIMESTAMP,$LAG,$STATE,$SRC_URP,$TGT_URP,$CPU_SRC,$CPU_TGT" | tee -a $LOG_FILE

    sleep 5
done
```

### 2.2 Script de Capture d'Événements

```bash
#!/bin/bash
# capture-event.sh
# Usage: ./capture-event.sh "Description de l'événement"

EVENT_LOG="events-$(date +%Y%m%d).log"
TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S.%3N)

echo "[$TIMESTAMP] $1" >> $EVENT_LOG
echo "[$TIMESTAMP] $1"
```

---

## 3. Commandes RES-01 : Panne Broker Source

### 3.1 Préparation

```bash
# Identifier le broker leader pour le topic de test
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --describe \
    --topic test-mm2-perf \
    | grep "Leader:" | head -5

# Vérifier l'état initial
echo "=== État initial cluster source ==="
for broker in $SRC_BROKER_1 $SRC_BROKER_2 $SRC_BROKER_3; do
    echo "Broker: $broker"
    ssh $SSH_USER@$broker "systemctl is-active $KAFKA_SERVICE"
done

# Vérifier ISR complet
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --describe \
    --under-replicated-partitions
```

### 3.2 Injection de la Panne

```bash
# ==== PANNE BROKER SOURCE ====

# Méthode 1: Arrêt propre (graceful)
ssh $SSH_USER@$SRC_BROKER_1 "sudo systemctl stop $KAFKA_SERVICE"

# Méthode 2: Arrêt brutal (kill -9) - Plus réaliste
ssh $SSH_USER@$SRC_BROKER_1 "sudo kill -9 \$(pgrep -f kafka.Kafka)"

# Méthode 3: Simulation panne réseau (broker isolé)
ssh $SSH_USER@$SRC_BROKER_1 "sudo iptables -A INPUT -p tcp --dport 9092 -j DROP && sudo iptables -A INPUT -p tcp --dport 9093 -j DROP"

# Capturer l'événement
./capture-event.sh "PANNE: Broker $SRC_BROKER_1 arrêté"
```

### 3.3 Observation

```bash
# Observer l'élection de leader (dans les 30 secondes)
watch -n 1 "$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --describe \
    --topic test-mm2-perf | head -10"

# Vérifier les URP
watch -n 2 "$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --describe \
    --under-replicated-partitions | wc -l"

# Observer l'état MM2
watch -n 2 "curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors?expand=status | jq '.[][\"status\"][\"connector\"][\"state\"]'"

# Observer le lag
watch -n 2 "curl -s 'http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag)' | jq '.data.result[0].value[1]'"
```

### 3.4 Restauration

```bash
# Redémarrer le broker
ssh $SSH_USER@$SRC_BROKER_1 "sudo systemctl start $KAFKA_SERVICE"

# OU si iptables utilisé
ssh $SSH_USER@$SRC_BROKER_1 "sudo iptables -D INPUT -p tcp --dport 9092 -j DROP && sudo iptables -D INPUT -p tcp --dport 9093 -j DROP"

# Capturer l'événement
./capture-event.sh "RESTAURATION: Broker $SRC_BROKER_1 redémarré"

# Vérifier retour ISR
watch -n 5 "$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG \
    --describe \
    --under-replicated-partitions"
```

---

## 4. Commandes RES-02 : Panne Broker Cible

### 4.1 Préparation

```bash
# Vérifier l'état initial du cluster cible
echo "=== État initial cluster cible ==="
for broker in $TGT_BROKER_1 $TGT_BROKER_2 $TGT_BROKER_3; do
    echo "Broker: $broker"
    ssh $SSH_USER@$broker "systemctl is-active $KAFKA_SERVICE"
done

# Identifier où MM2 produit
curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status | jq .
```

### 4.2 Injection de la Panne

```bash
# ==== PANNE BROKER CIBLE ====

# Arrêt brutal
ssh $SSH_USER@$TGT_BROKER_1 "sudo kill -9 \$(pgrep -f kafka.Kafka)"

# Capturer l'événement
./capture-event.sh "PANNE: Broker cible $TGT_BROKER_1 arrêté"
```

### 4.3 Observation

```bash
# Observer les logs MM2 pour les erreurs de production
ssh $SSH_USER@$MM2_WORKER_1 "sudo tail -f /var/log/kafka-connect/connect.log | grep -E 'ERROR|WARN|Failed'"

# Observer l'état des tâches MM2
watch -n 2 "curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status | jq '.tasks[].state'"

# Observer le lag
watch -n 2 "curl -s 'http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag)' | jq '.data.result[0].value[1]'"
```

### 4.4 Restauration

```bash
# Redémarrer le broker cible
ssh $SSH_USER@$TGT_BROKER_1 "sudo systemctl start $KAFKA_SERVICE"

./capture-event.sh "RESTAURATION: Broker cible $TGT_BROKER_1 redémarré"
```

---

## 5. Commandes RES-03 : Panne Worker MM2

### 5.1 Préparation

```bash
# Vérifier distribution des tâches
echo "=== Distribution des tâches MM2 ==="
curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors?expand=status | jq '
    .[] | {
        name: .status.name,
        tasks: [.status.tasks[] | {id: .id, worker_id: .worker_id, state: .state}]
    }'

# Lister les workers actifs
curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/ | jq .
```

### 5.2 Injection de la Panne

```bash
# ==== PANNE WORKER MM2 ====

# Arrêt brutal du worker 1
ssh $SSH_USER@$MM2_WORKER_1 "sudo kill -9 \$(pgrep -f ConnectDistributed)"

./capture-event.sh "PANNE: Worker MM2 $MM2_WORKER_1 arrêté"
```

### 5.3 Observation du Rebalancing

```bash
# Observer les logs pour le rebalancing
ssh $SSH_USER@$MM2_WORKER_2 "sudo tail -f /var/log/kafka-connect/connect.log | grep -E 'rebalance|Rebalance|joined|left'"

# Observer l'état des connecteurs (depuis un worker restant)
watch -n 2 "curl -s http://${MM2_WORKER_2}:${CONNECT_PORT}/connectors?expand=status | jq '
    .[] | {
        name: .status.name,
        connector_state: .status.connector.state,
        tasks: [.status.tasks[] | {id: .id, state: .state}]
    }'"

# Compter les tâches RUNNING
watch -n 2 "curl -s http://${MM2_WORKER_2}:${CONNECT_PORT}/connectors?expand=status | jq '[.[] | .status.tasks[] | select(.state==\"RUNNING\")] | length'"
```

### 5.4 Restauration

```bash
# Redémarrer le worker
ssh $SSH_USER@$MM2_WORKER_1 "sudo systemctl start $MM2_SERVICE"

./capture-event.sh "RESTAURATION: Worker MM2 $MM2_WORKER_1 redémarré"

# Observer le nouveau rebalancing
watch -n 2 "curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors?expand=status | jq '.[] | .status.tasks[] | {worker_id, state}'"
```

---

## 6. Commandes RES-04/05 : Panne ZooKeeper

### 6.1 Préparation

```bash
# Vérifier l'état de l'ensemble ZooKeeper
for zk in $SRC_ZK_1 $SRC_ZK_2 $SRC_ZK_3; do
    echo "=== ZK: $zk ==="
    ssh $SSH_USER@$zk "echo stat | nc localhost 2181 2>/dev/null | grep -E 'Mode|Connections'"
done
```

### 6.2 Panne 1 Nœud ZK (Quorum Maintenu)

```bash
# ==== PANNE 1 NOEUD ZK ====

# Identifier le leader et les followers
for zk in $SRC_ZK_1 $SRC_ZK_2 $SRC_ZK_3; do
    MODE=$(ssh $SSH_USER@$zk "echo stat | nc localhost 2181 2>/dev/null | grep Mode:")
    echo "$zk: $MODE"
done

# Arrêter un follower (ou le leader pour test élection)
ssh $SSH_USER@$SRC_ZK_1 "sudo systemctl stop $ZK_SERVICE"

./capture-event.sh "PANNE: ZooKeeper $SRC_ZK_1 arrêté"

# Vérifier que le quorum est maintenu
for zk in $SRC_ZK_2 $SRC_ZK_3; do
    echo "=== ZK: $zk ==="
    ssh $SSH_USER@$zk "echo stat | nc localhost 2181 2>/dev/null | grep -E 'Mode|Connections'"
done

# Vérifier pas d'impact Kafka
$KAFKA_HOME/bin/kafka-broker-api-versions.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config $CLIENT_CONFIG
```

### 6.3 Panne Leader ZK (Test Élection)

```bash
# Identifier le leader
LEADER=""
for zk in $SRC_ZK_1 $SRC_ZK_2 $SRC_ZK_3; do
    MODE=$(ssh $SSH_USER@$zk "echo stat | nc localhost 2181 2>/dev/null | grep 'Mode: leader'")
    if [ -n "$MODE" ]; then
        LEADER=$zk
        break
    fi
done
echo "Leader actuel: $LEADER"

# Arrêter le leader
ssh $SSH_USER@$LEADER "sudo systemctl stop $ZK_SERVICE"

./capture-event.sh "PANNE: ZooKeeper leader $LEADER arrêté"

# Observer l'élection (dans les 10 secondes)
sleep 5
for zk in $SRC_ZK_1 $SRC_ZK_2 $SRC_ZK_3; do
    MODE=$(ssh $SSH_USER@$zk "echo stat | nc localhost 2181 2>/dev/null | grep Mode:" 2>/dev/null)
    echo "$zk: $MODE"
done
```

### 6.4 Restauration

```bash
# Redémarrer le nœud ZK
ssh $SSH_USER@$SRC_ZK_1 "sudo systemctl start $ZK_SERVICE"

./capture-event.sh "RESTAURATION: ZooKeeper $SRC_ZK_1 redémarré"

# Vérifier l'ensemble
for zk in $SRC_ZK_1 $SRC_ZK_2 $SRC_ZK_3; do
    echo "=== ZK: $zk ==="
    ssh $SSH_USER@$zk "echo stat | nc localhost 2181 | grep -E 'Mode|Connections'"
done
```

---

## 7. Commandes RES-06 : Panne Réseau Inter-DC

### 7.1 Préparation

```bash
# Tester la connectivité actuelle
echo "=== Test connectivité MM2 -> Source ==="
ssh $SSH_USER@$MM2_WORKER_1 "nc -zv $SRC_BROKER_1 9093 2>&1"

echo "=== Test connectivité MM2 -> Cible ==="
ssh $SSH_USER@$MM2_WORKER_1 "nc -zv $TGT_BROKER_1 9093 2>&1"

# Vérifier l'état MM2 avant
curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors?expand=status | jq '.[].status.connector.state'
```

### 7.2 Simulation Coupure Réseau (Option 1: iptables sur MM2)

```bash
# ==== COUPURE RÉSEAU VERS CIBLE ====

# Bloquer le trafic vers le cluster cible depuis les workers MM2
for worker in $MM2_WORKER_1 $MM2_WORKER_2 $MM2_WORKER_3; do
    ssh $SSH_USER@$worker "sudo iptables -A OUTPUT -d $TGT_BROKER_1 -j DROP"
    ssh $SSH_USER@$worker "sudo iptables -A OUTPUT -d $TGT_BROKER_2 -j DROP"
    ssh $SSH_USER@$worker "sudo iptables -A OUTPUT -d $TGT_BROKER_3 -j DROP"
done

./capture-event.sh "PANNE RÉSEAU: Trafic MM2 vers cluster cible bloqué"
```

### 7.3 Simulation Coupure Réseau (Option 2: tc pour latence/perte)

```bash
# Ajouter 100% de perte de paquets
ssh $SSH_USER@$MM2_WORKER_1 "sudo tc qdisc add dev eth0 root netem loss 100%"

./capture-event.sh "PANNE RÉSEAU: 100% perte paquets sur MM2 worker 1"

# OU ajouter une latence extrême (10 secondes)
ssh $SSH_USER@$MM2_WORKER_1 "sudo tc qdisc add dev eth0 root netem delay 10000ms"
```

### 7.4 Observation

```bash
# Observer les erreurs MM2
ssh $SSH_USER@$MM2_WORKER_1 "sudo tail -f /var/log/kafka-connect/connect.log | grep -E 'ERROR|TimeoutException|Connection'"

# Observer l'accumulation du lag
watch -n 5 "curl -s 'http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag)' | jq '.data.result[0].value[1]'"

# Observer l'état des tâches
watch -n 5 "curl -s http://${MM2_WORKER_2}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status | jq '.tasks[].state'"
```

### 7.5 Restauration Réseau

```bash
# ==== RESTAURATION RÉSEAU ====

# Option 1: Supprimer règles iptables
for worker in $MM2_WORKER_1 $MM2_WORKER_2 $MM2_WORKER_3; do
    ssh $SSH_USER@$worker "sudo iptables -D OUTPUT -d $TGT_BROKER_1 -j DROP" 2>/dev/null
    ssh $SSH_USER@$worker "sudo iptables -D OUTPUT -d $TGT_BROKER_2 -j DROP" 2>/dev/null
    ssh $SSH_USER@$worker "sudo iptables -D OUTPUT -d $TGT_BROKER_3 -j DROP" 2>/dev/null
done

# Option 2: Supprimer tc
ssh $SSH_USER@$MM2_WORKER_1 "sudo tc qdisc del dev eth0 root" 2>/dev/null

./capture-event.sh "RESTAURATION RÉSEAU: Connectivité rétablie"

# Observer le rattrapage
watch -n 5 "curl -s 'http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag)' | jq '.data.result[0].value[1]'"
```

---

## 8. Commandes RES-08/09 : Rolling Restart

### 8.1 Rolling Restart Brokers Source

```bash
#!/bin/bash
# rolling-restart-brokers.sh

BROKERS=($SRC_BROKER_1 $SRC_BROKER_2 $SRC_BROKER_3)

for broker in "${BROKERS[@]}"; do
    echo "=========================================="
    echo "  Rolling restart: $broker"
    echo "=========================================="

    ./capture-event.sh "ROLLING: Début restart $broker"

    # Arrêter le broker
    ssh $SSH_USER@$broker "sudo systemctl stop $KAFKA_SERVICE"

    # Attendre que les partitions soient redistribuées
    echo "Attente redistribution partitions..."
    sleep 30

    # Vérifier URP
    URP=$($KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server $SRC_BOOTSTRAP \
        --command-config $CLIENT_CONFIG \
        --describe --under-replicated-partitions 2>/dev/null | grep -c "Topic:")
    echo "Under-replicated partitions: $URP"

    # Redémarrer le broker
    ssh $SSH_USER@$broker "sudo systemctl start $KAFKA_SERVICE"

    # Attendre que le broker rejoigne
    echo "Attente réintégration cluster..."
    sleep 60

    # Attendre ISR complet
    while true; do
        URP=$($KAFKA_HOME/bin/kafka-topics.sh \
            --bootstrap-server $SRC_BOOTSTRAP \
            --command-config $CLIENT_CONFIG \
            --describe --under-replicated-partitions 2>/dev/null | grep -c "Topic:")
        if [ "$URP" -eq 0 ]; then
            echo "ISR complet"
            break
        fi
        echo "Attente ISR... URP=$URP"
        sleep 10
    done

    ./capture-event.sh "ROLLING: Fin restart $broker"

    echo "Pause avant prochain broker..."
    sleep 30
done

echo "Rolling restart terminé"
```

### 8.2 Rolling Restart Workers MM2

```bash
#!/bin/bash
# rolling-restart-mm2.sh

WORKERS=($MM2_WORKER_1 $MM2_WORKER_2 $MM2_WORKER_3)

for worker in "${WORKERS[@]}"; do
    echo "=========================================="
    echo "  Rolling restart MM2: $worker"
    echo "=========================================="

    ./capture-event.sh "ROLLING MM2: Début restart $worker"

    # Arrêter le worker
    ssh $SSH_USER@$worker "sudo systemctl stop $MM2_SERVICE"

    # Attendre le rebalancing
    echo "Attente rebalancing..."
    sleep 60

    # Vérifier que toutes les tâches sont RUNNING (sur autres workers)
    OTHER_WORKER=""
    for w in "${WORKERS[@]}"; do
        if [ "$w" != "$worker" ]; then
            OTHER_WORKER=$w
            break
        fi
    done

    TASKS_RUNNING=$(curl -s http://${OTHER_WORKER}:${CONNECT_PORT}/connectors?expand=status | \
        jq '[.[] | .status.tasks[] | select(.state=="RUNNING")] | length')
    echo "Tâches RUNNING: $TASKS_RUNNING"

    # Redémarrer le worker
    ssh $SSH_USER@$worker "sudo systemctl start $MM2_SERVICE"

    # Attendre rebalancing de retour
    echo "Attente rebalancing retour..."
    sleep 60

    # Vérifier état
    curl -s http://${worker}:${CONNECT_PORT}/connectors?expand=status | \
        jq '.[] | {name: .status.name, tasks: [.status.tasks[].state]}'

    ./capture-event.sh "ROLLING MM2: Fin restart $worker"

    echo "Pause avant prochain worker..."
    sleep 30
done

echo "Rolling restart MM2 terminé"
```

---

## 9. Commandes RES-10 : Saturation Disque

### 9.1 Simulation Saturation

```bash
# ==== SATURATION DISQUE ====
# ATTENTION: À exécuter dans un répertoire non critique

# Vérifier espace disque actuel
ssh $SSH_USER@$SRC_BROKER_1 "df -h ${KAFKA_LOG_DIRS}"

# Créer un fichier volumineux (ajuster la taille selon l'espace disponible)
ssh $SSH_USER@$SRC_BROKER_1 "sudo dd if=/dev/zero of=${KAFKA_LOG_DIRS}/fill.tmp bs=1G count=50 2>&1"

./capture-event.sh "SATURATION: Disque $SRC_BROKER_1 rempli"

# Vérifier le nouvel état
ssh $SSH_USER@$SRC_BROKER_1 "df -h ${KAFKA_LOG_DIRS}"
```

### 9.2 Observation

```bash
# Observer les erreurs dans les logs Kafka
ssh $SSH_USER@$SRC_BROKER_1 "sudo tail -f /var/log/kafka/server.log | grep -E 'ERROR|No space|IOException'"

# Observer l'état du broker
watch -n 5 "$KAFKA_HOME/bin/kafka-broker-api-versions.sh --bootstrap-server $SRC_BROKER_1:9093 --command-config $CLIENT_CONFIG 2>&1 | head -5"
```

### 9.3 Restauration

```bash
# Supprimer le fichier de remplissage
ssh $SSH_USER@$SRC_BROKER_1 "sudo rm -f ${KAFKA_LOG_DIRS}/fill.tmp"

./capture-event.sh "RESTAURATION: Espace disque libéré sur $SRC_BROKER_1"

# Vérifier
ssh $SSH_USER@$SRC_BROKER_1 "df -h ${KAFKA_LOG_DIRS}"
```

---

## 10. Commandes RES-11 : Test Certificats

### 10.1 Vérification Validité Certificats

```bash
# Vérifier la date d'expiration des certificats
for broker in $SRC_BROKER_1 $SRC_BROKER_2 $SRC_BROKER_3; do
    echo "=== Certificat: $broker ==="
    ssh $SSH_USER@$broker "openssl x509 -in ${BROKER_CERT_PATH} -noout -dates"
done

# Vérifier via connexion SSL
openssl s_client -connect $SRC_BROKER_1:9093 -servername $SRC_BROKER_1 2>/dev/null | openssl x509 -noout -dates
```

### 10.2 Simulation Expiration (sur environnement de test)

```bash
# ATTENTION: Uniquement sur environnement de test

# Option 1: Modifier la date système (dangereux)
# ssh $SSH_USER@$SRC_BROKER_1 "sudo date -s '+1 year'"

# Option 2: Utiliser un certificat expiré de test
# Remplacer le certificat par un certificat expiré préparé à l'avance
ssh $SSH_USER@$SRC_BROKER_1 "sudo cp ${EXPIRED_CERT_PATH} ${BROKER_CERT_PATH}"

./capture-event.sh "TEST CERT: Certificat expiré déployé sur $SRC_BROKER_1"
```

### 10.3 Restauration

```bash
# Restaurer le certificat valide
ssh $SSH_USER@$SRC_BROKER_1 "sudo cp ${VALID_CERT_PATH} ${BROKER_CERT_PATH}"

# Redémarrer le broker pour recharger
ssh $SSH_USER@$SRC_BROKER_1 "sudo systemctl restart $KAFKA_SERVICE"

./capture-event.sh "RESTAURATION CERT: Certificat valide restauré"
```

---

## 11. Commandes RES-12 : Test Credentials SASL

### 11.1 Simulation Invalidation Credentials

```bash
# ==== INVALIDATION CREDENTIALS ====

# Sauvegarder les credentials actuels
CURRENT_PASSWORD=$(grep "password=" ${CLIENT_JAAS_CONFIG_PATH} | cut -d'"' -f2)

# Modifier le password dans Kafka (invalide les credentials existants)
$KAFKA_HOME/bin/kafka-configs.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config ${ADMIN_PROPERTIES_PATH} \
    --alter \
    --entity-type users \
    --entity-name ${MM2_USER_SOURCE} \
    --add-config 'SCRAM-SHA-512=[password=invalidpassword123]'

./capture-event.sh "TEST SASL: Credentials MM2 invalidés"
```

### 11.2 Observation

```bash
# Observer les erreurs d'authentification
ssh $SSH_USER@$MM2_WORKER_1 "sudo tail -f /var/log/kafka-connect/connect.log | grep -E 'Authentication|SASL|auth'"

# Observer l'état des tâches MM2
watch -n 2 "curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/status | jq '.tasks[].state'"
```

### 11.3 Restauration

```bash
# Restaurer le password original
$KAFKA_HOME/bin/kafka-configs.sh \
    --bootstrap-server $SRC_BOOTSTRAP \
    --command-config ${ADMIN_PROPERTIES_PATH} \
    --alter \
    --entity-type users \
    --entity-name ${MM2_USER_SOURCE} \
    --add-config "SCRAM-SHA-512=[password=${CURRENT_PASSWORD}]"

./capture-event.sh "RESTAURATION SASL: Credentials MM2 restaurés"

# Redémarrer les tâches MM2 si nécessaire
curl -X POST http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/restart
```

---

## 12. Script de Test Automatisé

```bash
#!/bin/bash
# run-resilience-test.sh
# Usage: ./run-resilience-test.sh RES-01

SCENARIO=$1
RESULTS_DIR="resilience-results/$(date +%Y%m%d-%H%M%S)-$SCENARIO"
mkdir -p $RESULTS_DIR

# Fonctions utilitaires
log() {
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $1" | tee -a $RESULTS_DIR/test.log
}

capture_state() {
    local phase=$1
    log "Capture état: $phase"

    # État MM2
    curl -s http://${MM2_WORKER_1}:${CONNECT_PORT}/connectors?expand=status \
        > $RESULTS_DIR/mm2-state-$phase.json 2>/dev/null

    # Lag
    curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=sum(kafka_consumer_fetch_manager_records_lag)" \
        > $RESULTS_DIR/lag-$phase.json 2>/dev/null

    # URP
    $KAFKA_HOME/bin/kafka-topics.sh \
        --bootstrap-server $SRC_BOOTSTRAP \
        --command-config $CLIENT_CONFIG \
        --describe --under-replicated-partitions \
        > $RESULTS_DIR/urp-$phase.txt 2>/dev/null
}

# Exécution
log "=== Début test $SCENARIO ==="
capture_state "initial"

case $SCENARIO in
    RES-01)
        log "Exécution RES-01: Panne broker source"
        # Panne
        ssh $SSH_USER@$SRC_BROKER_1 "sudo systemctl stop $KAFKA_SERVICE"
        PANNE_TIME=$(date +%s)
        log "Panne injectée"

        # Attente et observation
        sleep 60
        capture_state "during"

        # Restauration
        ssh $SSH_USER@$SRC_BROKER_1 "sudo systemctl start $KAFKA_SERVICE"
        RESTORE_TIME=$(date +%s)
        log "Restauration effectuée"

        # Attente stabilisation
        sleep 120
        capture_state "after"

        # Calcul MTTR
        MTTR=$((RESTORE_TIME - PANNE_TIME))
        log "MTTR: $MTTR secondes"
        ;;

    # Ajouter les autres scénarios...

    *)
        log "Scénario inconnu: $SCENARIO"
        exit 1
        ;;
esac

log "=== Fin test $SCENARIO ==="
log "Résultats dans $RESULTS_DIR/"
```

---

## Artifacts Produits

- [ ] Logs des événements (`events-YYYYMMDD.log`)
- [ ] Métriques de monitoring (`resilience-monitor-*.csv`)
- [ ] Résultats par scénario (`resilience-results/`)

---

**Auteur** : `${AUTHOR_NAME}`
**Date de création** : `${DATE_CREATION}`
**Version** : 1.0
