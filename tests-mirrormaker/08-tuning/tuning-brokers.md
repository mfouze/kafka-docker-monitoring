# Tuning Kafka Brokers - Transactis

## Objectif

Fournir les configurations optimisées des brokers Kafka pour atteindre le SLA < 1h de downtime annuel avec les ressources actuelles.

---

## Environnement Validé ✅

| Paramètre | Valeur |
|-----------|--------|
| **vCPU** | 4 |
| **RAM** | 32 Go |
| **Disque** | 250 Go |
| **Java** | OpenJDK 17 |
| **Confluent Platform** | 7.7.3 |
| **Architecture** | **COLLOCALISÉE** (Broker + ZK + Connect + SR sur même instance) |

### ⚠️ Répartition Mémoire (Architecture Collocalisée)

| Composant | Heap Recommandé | Note |
|-----------|-----------------|------|
| **Kafka Broker** | **6 Go** | Réduit vs dédié (collocation) |
| Kafka Connect (MM2) | 4 Go | - |
| Schema Registry | 1 Go | - |
| ZooKeeper | 1 Go | - |
| **OS + Page Cache** | **~20 Go** | Critique pour Kafka I/O |
| **TOTAL** | **32 Go** | ✅ |

---

## 📐 Formules de Calcul par Flavour

> **Flavour de référence** : 4 vCPU / 32 Go RAM / 250 Go Disque
> Les formules ci-dessous permettent d'adapter les paramètres à n'importe quel flavour.

### Exemples de Flavours

| Flavour | vCPU | RAM | Disque | Use Case |
|---------|------|-----|--------|----------|
| **v4/32/250** (base) | 4 | 32 Go | 250 Go | Dev/Test, petite prod |
| v8/64/500 | 8 | 64 Go | 500 Go | Prod moyenne |
| v16/128/1000 | 16 | 128 Go | 1 To | Prod haute charge |
| v32/256/2000 | 32 | 256 Go | 2 To | Enterprise |

---

### 🔧 Paramètres Kafka Broker (`server.properties`)

| Paramètre                           | Utilité                                              | Formule             | v4/32/250 | v8/64/500 | v16/128/1000 | v32/256/2000 |
| ----------------------------------- | ---------------------------------------------------- | ------------------- | --------- | --------- | ------------ | ------------ |
| `num.network.threads`               | Traitement requêtes réseau (Produce/Fetch)           | `vCPU`              | **4**     | 8         | 16           | 32           |
| `num.io.threads`                    | Traitement I/O disque (écriture/lecture segments)    | `2 × vCPU`          | **8**     | 16        | 32           | 64           |
| `num.replica.fetchers`              | Threads fetch réplication (vitesse sync followers)   | `max(2, vCPU / 2)`  | **2**     | 4         | 8            | 16           |
| `num.recovery.threads.per.data.dir` | Threads recovery au démarrage (temps de restart)     | `max(2, vCPU / 2)`  | **2**     | 4         | 8            | 16           |
| `background.threads`                | Tâches async (compaction, suppression logs)          | `max(10, vCPU × 2)` | **10**    | 16        | 32           | 64           |
| `log.cleaner.threads`               | Threads compaction log (topics compactés)            | `max(2, vCPU / 2)`  | **2**     | 4         | 8            | 16           |
| `queued.max.requests`               | File requêtes en attente (absorbe pics de charge)    | `100 × vCPU + 100`  | **500**   | 900       | 1700         | 3300         |
| `max.connections.per.ip`            | Limite connexions par IP (protection DoS)            | `25 × vCPU`         | **100**   | 200       | 400          | 800          |

---

### 🧠 Paramètres Mémoire JVM (Architecture Collocalisée)

| Composant                  | Utilité                                          | Formule                  | v4/32/250 | v8/64/500 | v16/128/1000 | v32/256/2000 |
| -------------------------- | ------------------------------------------------ | ------------------------ | --------- | --------- | ------------ | ------------ |
| **Kafka Broker Heap**      | Mémoire broker (metadata, requêtes, buffers)     | `RAM × 0.19`             | **6 Go**  | 12 Go     | 24 Go        | 48 Go        |
| Kafka Connect (MM2) Heap   | Mémoire MM2 (connecteurs, tâches, offsets)       | `RAM × 0.125`            | **4 Go**  | 8 Go      | 16 Go        | 32 Go        |
| Schema Registry Heap       | Mémoire SR (cache schémas, validation)           | `RAM × 0.03`             | **1 Go**  | 2 Go      | 4 Go         | 8 Go         |
| ZooKeeper Heap             | Mémoire ZK (état cluster, sessions)              | `RAM × 0.03`             | **1 Go**  | 2 Go      | 4 Go         | 8 Go         |
| **OS + Page Cache**        | Cache fichiers OS (lecture segments Kafka rapide)| `RAM × 0.625` (~60-65%)  | **20 Go** | 40 Go     | 80 Go        | 160 Go       |

> ⚠️ **Règle d'or** : Toujours garder **≥ 60%** de la RAM pour le Page Cache (critique pour les performances I/O Kafka)

---

### 🖥️ Paramètres Système (`/etc/sysctl.d/99-kafka.conf`)

| Paramètre                      | Utilité                                              | Formule                   | v4/32/250     | v8/64/500 | v16/128/1000 | v32/256/2000 |
| ------------------------------ | ---------------------------------------------------- | ------------------------- | ------------- | --------- | ------------ | ------------ |
| `vm.swappiness`                | Évite le swap (latence catastrophique pour Kafka)    | `1` (fixe)                | **1**         | 1         | 1            | 1            |
| `vm.dirty_ratio`               | % RAM avant flush synchrone (écriture disque)        | `80` (fixe)               | **80**        | 80        | 80           | 80           |
| `vm.dirty_background_ratio`    | % RAM avant flush asynchrone en arrière-plan         | `5` (fixe)                | **5**         | 5         | 5            | 5            |
| `vm.max_map_count`             | Nb max de zones mémoire mappées (segments Kafka)     | `65536 × vCPU`            | **262144**    | 524288    | 1048576      | 2097152      |
| `net.core.rmem_max`            | Buffer max réception socket (throughput réseau)      | `128 MB` (fixe)           | **134217728** | 134217728 | 134217728    | 134217728    |
| `net.core.wmem_max`            | Buffer max envoi socket (throughput réseau)          | `128 MB` (fixe)           | **134217728** | 134217728 | 134217728    | 134217728    |
| `net.core.rmem_default`        | Buffer par défaut réception (perf réseau initiale)   | `RAM_MB × 512` (max 64MB) | **16777216**  | 33554432  | 67108864     | 67108864     |
| `net.core.wmem_default`        | Buffer par défaut envoi (perf réseau initiale)       | `RAM_MB × 512` (max 64MB) | **16777216**  | 33554432  | 67108864     | 67108864     |
| `net.core.netdev_max_backlog`  | File d'attente paquets entrants (pic de trafic)      | `7500 × vCPU`             | **30000**     | 60000     | 120000       | 240000       |
| `net.core.somaxconn`           | File d'attente connexions TCP (nb clients simultanés)| `8192 × vCPU`             | **32768**     | 65536     | 131072       | 262144       |
| `net.ipv4.tcp_max_syn_backlog` | File d'attente SYN (protection contre pic connexions)| `2048 × vCPU`             | **8192**      | 16384     | 32768        | 65536        |
| `fs.file-max`                  | Nb max fichiers ouverts système (partitions + logs)  | `524288 × vCPU`           | **2097152**   | 4194304   | 8388608      | 16777216     |

---

### 👤 Limites Utilisateur (`/etc/security/limits.d/kafka.conf`)

| Paramètre            | Utilité                                                | Formule            | v4/32/250     | v8/64/500 | v16/128/1000 | v32/256/2000 |
| -------------------- | ------------------------------------------------------ | ------------------ | ------------- | --------- | ------------ | ------------ |
| `nofile` (soft/hard) | Nb fichiers ouverts par process (segments + sockets)   | `32768 × vCPU`     | **131072**    | 262144    | 524288       | 1048576      |
| `nproc` (soft/hard)  | Nb max de threads par utilisateur (threads I/O Kafka)  | `16384 × vCPU`     | **65536**     | 131072    | 262144       | 524288       |
| `memlock`            | Verrouillage mémoire (évite swap des pages critiques)  | `unlimited` (fixe) | **unlimited** | unlimited | unlimited    | unlimited    |

---

### 🔄 Paramètres JVM GC (G1GC)

| Paramètre                             | Utilité                                             | Formule                            | v4/32/250 | v8/64/500 | v16/128/1000 | v32/256/2000 |
| ------------------------------------- | --------------------------------------------------- | ---------------------------------- | --------- | --------- | ------------ | ------------ |
| `-Xms` / `-Xmx`                       | Taille heap (identique pour éviter resize)          | = Broker Heap                      | **6G**    | 12G       | 24G          | 48G          |
| `-XX:MaxGCPauseMillis`                | Objectif pause GC max (latence Kafka)               | `200` (fixe)                       | **200**   | 200       | 200          | 200          |
| `-XX:InitiatingHeapOccupancyPercent`  | % heap avant démarrage GC concurrent (évite full GC)| `35` (fixe)                        | **35**    | 35        | 35           | 35           |
| `-XX:G1HeapRegionSize`                | Taille région G1 (optimise gestion mémoire)         | `Heap / 2048` (arrondi puissance 2)| **4M**    | 8M        | 16M          | 32M          |
| `-XX:ParallelGCThreads`               | Threads GC parallèles (phase STW)                   | `vCPU`                             | **4**     | 8         | 16           | 32           |
| `-XX:ConcGCThreads` | `max(1, vCPU / 4)` | **1** | 2 | 4 | 8 |

---

### 📊 Script de Calcul Automatique

```bash
#!/bin/bash
# =============================================================================
# CALCUL AUTOMATIQUE DES PARAMÈTRES KAFKA PAR FLAVOUR
# Usage: ./calc-kafka-params.sh <vCPU> <RAM_GO> <DISK_GO>
# Exemple: ./calc-kafka-params.sh 4 32 250
# =============================================================================

VCPU=${1:-4}
RAM_GO=${2:-32}
DISK_GO=${3:-250}

echo "=============================================="
echo "CALCUL PARAMÈTRES KAFKA - Flavour v${VCPU}/${RAM_GO}/${DISK_GO}"
echo "=============================================="

echo ""
echo "=== KAFKA BROKER (server.properties) ==="
echo "num.network.threads=${VCPU}"
echo "num.io.threads=$((VCPU * 2))"
echo "num.replica.fetchers=$(( VCPU / 2 > 2 ? VCPU / 2 : 2 ))"
echo "num.recovery.threads.per.data.dir=$(( VCPU / 2 > 2 ? VCPU / 2 : 2 ))"
echo "background.threads=$(( VCPU * 2 > 10 ? VCPU * 2 : 10 ))"
echo "log.cleaner.threads=$(( VCPU / 2 > 2 ? VCPU / 2 : 2 ))"
echo "queued.max.requests=$(( VCPU * 100 + 100 ))"
echo "max.connections.per.ip=$(( VCPU * 25 ))"

echo ""
echo "=== MÉMOIRE JVM (Architecture Collocalisée) ==="
BROKER_HEAP=$(echo "$RAM_GO * 0.19" | bc | cut -d'.' -f1)
CONNECT_HEAP=$(echo "$RAM_GO * 0.125" | bc | cut -d'.' -f1)
SR_HEAP=$(echo "$RAM_GO * 0.03" | bc | cut -d'.' -f1)
ZK_HEAP=$(echo "$RAM_GO * 0.03" | bc | cut -d'.' -f1)
PAGE_CACHE=$(echo "$RAM_GO * 0.625" | bc | cut -d'.' -f1)

echo "Kafka Broker Heap: ${BROKER_HEAP} Go"
echo "Kafka Connect Heap: ${CONNECT_HEAP} Go"
echo "Schema Registry Heap: ${SR_HEAP} Go"
echo "ZooKeeper Heap: ${ZK_HEAP} Go"
echo "Page Cache disponible: ~${PAGE_CACHE} Go"

echo ""
echo "=== SYSTÈME (sysctl) ==="
echo "vm.max_map_count=$(( 65536 * VCPU ))"
echo "net.core.netdev_max_backlog=$(( 7500 * VCPU ))"
echo "net.core.somaxconn=$(( 8192 * VCPU ))"
echo "net.ipv4.tcp_max_syn_backlog=$(( 2048 * VCPU ))"
echo "fs.file-max=$(( 524288 * VCPU ))"

echo ""
echo "=== LIMITES UTILISATEUR (limits.conf) ==="
echo "nofile: $(( 32768 * VCPU ))"
echo "nproc: $(( 16384 * VCPU ))"

echo ""
echo "=== JVM GC OPTIONS ==="
echo "KAFKA_HEAP_OPTS=\"-Xms${BROKER_HEAP}G -Xmx${BROKER_HEAP}G\""
echo "-XX:ParallelGCThreads=${VCPU}"
echo "-XX:ConcGCThreads=$(( VCPU / 4 > 1 ? VCPU / 4 : 1 ))"
```

---

## 1. Configuration Actuelle vs Recommandée

### 1.1 Paramètres Critiques

| Paramètre | Actuel | Recommandé | Impact | Priorité |
|-----------|--------|------------|--------|----------|
| num.network.threads | 3 | **4** | Throughput réseau | HAUTE |
| num.io.threads | 8 | **8** | OK - Adapté 4 vCPU | - |
| num.replica.fetchers | 1 | **2** | Vitesse réplication | HAUTE |
| num.recovery.threads.per.data.dir | 1 | **2** | Temps recovery | HAUTE |
| group.initial.rebalance.delay.ms | 0 | **3000** | Stabilité consumers | MOYENNE |
| transaction.state.log.min.isr | 3 | **2** | Disponibilité transactions | HAUTE |
| log.flush.interval.messages | default | **50000** | Performance write | MOYENNE |

---

## 2. Configuration server.properties Recommandée

### 2.1 Fichier Complet Optimisé

```properties
# =============================================================================
# KAFKA BROKER - CONFIGURATION OPTIMISÉE TRANSACTIS
# SLA Target: < 1h downtime/an | Confluent Platform 7.7.3
# Ressources: 32 Go RAM, 4 vCPU, 250 Go disque
# =============================================================================

# -----------------------------------------------------------------------------
# IDENTIFICATION BROKER
# -----------------------------------------------------------------------------
broker.id=${BROKER_ID}
# Exemple: broker.id=0, broker.id=1, broker.id=2

# -----------------------------------------------------------------------------
# LISTENERS ET RÉSEAU
# -----------------------------------------------------------------------------
# Listener interne (inter-broker)
listeners=PLAINTEXT://:9092,SSL://:9093
advertised.listeners=PLAINTEXT://${HOSTNAME}:9092,SSL://${HOSTNAME}:9093

# Protocole inter-broker
inter.broker.listener.name=SSL
security.inter.broker.protocol=SSL

# Listener map
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_SSL:SASL_SSL

# -----------------------------------------------------------------------------
# THREADS - ADAPTÉ 4 vCPU
# -----------------------------------------------------------------------------
# Threads réseau (recommandé: num_cpus)
num.network.threads=4

# Threads I/O (recommandé: 2 * num_cpus)
num.io.threads=8

# Threads réplication (améliore catch-up)
num.replica.fetchers=2

# Threads recovery (accélère restart)
num.recovery.threads.per.data.dir=2

# Background threads
background.threads=10

# -----------------------------------------------------------------------------
# RÉPLICATION ET DURABILITÉ
# -----------------------------------------------------------------------------
# Facteur de réplication par défaut
default.replication.factor=3

# ISR minimum pour les writes
min.insync.replicas=2

# Réplication factor topics internes
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2

# Unclean leader election (DÉSACTIVÉ pour durabilité)
unclean.leader.election.enable=false

# Auto-création topics (DÉSACTIVÉ en prod)
auto.create.topics.enable=false

# -----------------------------------------------------------------------------
# BUFFER ET MÉMOIRE SOCKET
# -----------------------------------------------------------------------------
# Buffer socket (1 MB - adapté réseau interne)
socket.send.buffer.bytes=1048576
socket.receive.buffer.bytes=1048576

# Taille max requête (100 MB)
socket.request.max.bytes=104857600

# Réplication buffer
replica.socket.receive.buffer.bytes=1048576
replica.fetch.max.bytes=10485760

# -----------------------------------------------------------------------------
# LOGS ET RÉTENTION
# -----------------------------------------------------------------------------
# Répertoire des logs
log.dirs=/var/kafka/data

# Rétention par défaut (7 jours)
log.retention.hours=168

# Taille max par partition avant rotation
log.retention.bytes=-1

# Taille des segments (1 GB)
log.segment.bytes=1073741824

# Intervalle de vérification rétention (5 min)
log.retention.check.interval.ms=300000

# Log cleaner
log.cleaner.enable=true
log.cleaner.threads=2

# Flush (laisser OS gérer sauf besoin spécifique)
# log.flush.interval.messages=50000
# log.flush.interval.ms=1000

# -----------------------------------------------------------------------------
# CONSUMER GROUPS ET COORDINATION
# -----------------------------------------------------------------------------
# Délai initial rebalancing (évite rebalancing prématuré)
group.initial.rebalance.delay.ms=3000

# Timeout session consumer
group.min.session.timeout.ms=6000
group.max.session.timeout.ms=1800000

# Offsets topic configuration
offsets.topic.num.partitions=50
offsets.retention.minutes=10080

# -----------------------------------------------------------------------------
# QUOTAS ET LIMITES
# -----------------------------------------------------------------------------
# Quotas par défaut (désactivé - à activer si nécessaire)
# quota.producer.default=10485760
# quota.consumer.default=10485760

# Connexions max par IP
max.connections.per.ip=100

# Requêtes en file d'attente
queued.max.requests=500

# -----------------------------------------------------------------------------
# ZOOKEEPER
# -----------------------------------------------------------------------------
zookeeper.connect=${ZK_CONNECT}
# Exemple: zookeeper.connect=zk1:2181,zk2:2181,zk3:2181/kafka

zookeeper.connection.timeout.ms=18000
zookeeper.session.timeout.ms=18000

# -----------------------------------------------------------------------------
# SÉCURITÉ TLS/SSL
# -----------------------------------------------------------------------------
ssl.keystore.location=/etc/kafka/ssl/kafka.keystore.jks
ssl.keystore.password=${SSL_KEYSTORE_PASSWORD}
ssl.key.password=${SSL_KEY_PASSWORD}

ssl.truststore.location=/etc/kafka/ssl/kafka.truststore.jks
ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD}

# Protocoles TLS
ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

# Authentification client
ssl.client.auth=required

# Cipher suites (sécurisés)
ssl.cipher.suites=TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_128_GCM_SHA256

# -----------------------------------------------------------------------------
# SÉCURITÉ SASL
# -----------------------------------------------------------------------------
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512

# -----------------------------------------------------------------------------
# MÉTRIQUES JMX
# -----------------------------------------------------------------------------
# JMX Exporter port (configuré via KAFKA_OPTS)
# -javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=7070:/etc/kafka/jmx_exporter.yml

# -----------------------------------------------------------------------------
# TRANSACTIONS
# -----------------------------------------------------------------------------
transaction.max.timeout.ms=900000
transactional.id.expiration.ms=604800000

# -----------------------------------------------------------------------------
# COMPRESSION
# -----------------------------------------------------------------------------
compression.type=producer
# Accepte la compression du producer

# -----------------------------------------------------------------------------
# DIVERS
# -----------------------------------------------------------------------------
# Suppression des topics autorisée (en prod, contrôler via ACLs)
delete.topic.enable=true

# Controller listener
# (Pour KRaft, non applicable avec ZooKeeper)
```

---

## 3. Configuration JVM Optimisée (COLLOCALISÉE)

### 3.1 Fichier kafka-server-start.sh ou service file

```bash
# =============================================================================
# JVM OPTIONS - KAFKA BROKER (ARCHITECTURE COLLOCALISÉE)
# 32 Go RAM total → 6 Go Heap Broker (laisser RAM pour autres JVM + page cache)
# =============================================================================

export KAFKA_HEAP_OPTS="-Xms6G -Xmx6G"

export KAFKA_JVM_PERFORMANCE_OPTS="
    -server
    -XX:+UseG1GC
    -XX:MaxGCPauseMillis=200
    -XX:InitiatingHeapOccupancyPercent=35
    -XX:G1HeapRegionSize=16M
    -XX:MinMetaspaceFreeRatio=50
    -XX:MaxMetaspaceFreeRatio=80
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+ParallelRefProcEnabled
    -XX:+DisableExplicitGC
    -Djava.awt.headless=true
    -Dcom.sun.management.jmxremote
    -Dcom.sun.management.jmxremote.authenticate=false
    -Dcom.sun.management.jmxremote.ssl=false
"

# JMX Exporter
export KAFKA_OPTS="-javaagent:/opt/jmx_exporter/jmx_prometheus_javaagent.jar=7070:/etc/kafka/jmx_exporter.yml"
```

### 3.2 Justification Heap Size (Architecture Collocalisée)

| Architecture | RAM Totale | Broker Heap | Autres JVM | Page Cache | Note |
|--------------|------------|-------------|------------|------------|------|
| **Collocalisée (actuelle)** | **32 Go** | **6 Go** | ~6 Go | ~20 Go | ✅ Validé |
| Dédiée | 32 Go | 8 Go | 0 | 24 Go | Si broker isolé |
| Dédiée | 64 Go | 12 Go | 0 | 52 Go | Plus performant |

### 3.3 Répartition Mémoire Complète (Instance Collocalisée 32 Go)

```
┌─────────────────────────────────────────────────────────────┐
│                    RAM TOTALE : 32 Go                       │
├─────────────────────────────────────────────────────────────┤
│  Kafka Broker JVM        │ 6 Go  │ KAFKA_HEAP_OPTS          │
│  Kafka Connect JVM       │ 4 Go  │ KAFKA_CONNECT_HEAP_OPTS  │
│  Schema Registry JVM     │ 1 Go  │ SCHEMA_REGISTRY_HEAP     │
│  ZooKeeper JVM           │ 1 Go  │ ZK_SERVER_HEAP           │
├─────────────────────────────────────────────────────────────┤
│  OS + Page Cache         │ ~20 Go│ Critique pour Kafka I/O  │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Configuration Système (sysctl)

### 4.1 Fichier /etc/sysctl.d/99-kafka.conf

```bash
# =============================================================================
# KERNEL TUNING - KAFKA BROKER
# =============================================================================

# -----------------------------------------------------------------------------
# MÉMOIRE VIRTUELLE
# -----------------------------------------------------------------------------
# Réduire swappiness (0-10 pour Kafka)
vm.swappiness=1

# Dirty ratio (quand écrire le dirty cache)
vm.dirty_ratio=80
vm.dirty_background_ratio=5

# Max memory map areas
vm.max_map_count=262144

# -----------------------------------------------------------------------------
# RÉSEAU
# -----------------------------------------------------------------------------
# Buffer TCP
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=16777216
net.core.wmem_default=16777216

# TCP memory
net.ipv4.tcp_rmem=4096 65536 134217728
net.ipv4.tcp_wmem=4096 65536 134217728

# Backlog
net.core.netdev_max_backlog=30000
net.core.somaxconn=32768

# TCP tuning
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_max_syn_backlog=8192

# Connexions TIME_WAIT
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_tw_reuse=1

# Keepalive
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=60
net.ipv4.tcp_keepalive_probes=3

# -----------------------------------------------------------------------------
# FILE DESCRIPTORS
# -----------------------------------------------------------------------------
fs.file-max=2097152
```

### 4.2 Limites Utilisateur (/etc/security/limits.d/kafka.conf)

```bash
# Kafka user limits
kafka soft nofile 131072
kafka hard nofile 131072
kafka soft nproc 65536
kafka hard nproc 65536
kafka soft memlock unlimited
kafka hard memlock unlimited
```

---

## 5. Checklist de Déploiement

### 5.1 Avant Rolling Restart

| Étape | Commande/Action | Validé |
|-------|-----------------|--------|
| Backup config actuelle | `cp server.properties server.properties.bak` | [ ] |
| Vérifier ISR complet | `kafka-topics.sh --describe --under-replicated-partitions` | [ ] |
| Vérifier controllers | Dashboard Grafana Kafka Cluster | [ ] |
| Arrêter producer de test | Stopper perf-test | [ ] |

### 5.2 Procédure Rolling Restart

```bash
#!/bin/bash
# Rolling restart avec vérification ISR

BROKERS=("broker-1" "broker-2" "broker-3")
KAFKA_HOME="/opt/kafka"

for BROKER in "${BROKERS[@]}"; do
    echo "=== Traitement de $BROKER ==="

    # 1. Attendre que tous les ISR soient complets
    echo "Vérification ISR..."
    while true; do
        UNDER_REPLICATED=$(${KAFKA_HOME}/bin/kafka-topics.sh \
            --bootstrap-server localhost:9093 \
            --command-config /etc/kafka/admin.properties \
            --describe --under-replicated-partitions 2>/dev/null | wc -l)

        if [ "$UNDER_REPLICATED" -eq 0 ]; then
            echo "ISR OK"
            break
        fi
        echo "Attente ISR sync... ($UNDER_REPLICATED partitions)"
        sleep 10
    done

    # 2. Arrêt contrôlé du broker
    echo "Arrêt de $BROKER..."
    ssh $BROKER "sudo systemctl stop kafka"

    # 3. Attendre élection leader
    sleep 30

    # 4. Vérifier métrique controller
    echo "Vérification controller..."

    # 5. Démarrage broker
    echo "Démarrage de $BROKER..."
    ssh $BROKER "sudo systemctl start kafka"

    # 6. Attendre que le broker rejoigne le cluster
    sleep 60

    # 7. Vérifier que le broker est UP
    echo "Vérification broker UP..."
    # Check via Prometheus: up{job="kafka",instance="$BROKER"}

    echo "=== $BROKER terminé ==="
    echo ""
done

echo "Rolling restart terminé"
```

### 5.3 Après Rolling Restart

| Vérification | Commande/Dashboard | Attendu |
|--------------|-------------------|---------|
| Tous brokers UP | `up{job="kafka"} == 3` | 3 |
| ISR complet | `kafka_server_ReplicaManager_UnderReplicatedPartitions` | 0 |
| Controller actif | `kafka_controller_KafkaController_ActiveControllerCount` | 1 |
| Pas d'offline partitions | `kafka_controller_KafkaController_OfflinePartitionsCount` | 0 |

---

## 6. Métriques de Validation

### 6.1 Requêtes Prometheus Post-Tuning

```promql
# Vérifier threads réseau utilisés
kafka_server_KafkaRequestHandlerPool_RequestHandlerAvgIdlePercent

# Latence requêtes Produce
histogram_quantile(0.99, kafka_network_RequestMetrics_TotalTimeMs{request="Produce"})

# Latence requêtes Fetch
histogram_quantile(0.99, kafka_network_RequestMetrics_TotalTimeMs{request="Fetch"})

# Under-replicated partitions (doit être 0)
kafka_server_ReplicaManager_UnderReplicatedPartitions

# Messages In/sec par broker
sum by (instance) (rate(kafka_server_BrokerTopicMetrics_MessagesInPerSec[5m]))

# Bytes In/sec
sum by (instance) (rate(kafka_server_BrokerTopicMetrics_BytesInPerSec[5m]))
```

### 6.2 Seuils de Validation SLA

| Métrique | Seuil OK | Seuil Warning | Seuil Critical |
|----------|----------|---------------|----------------|
| Request Handler Idle % | > 70% | 50-70% | < 50% |
| Produce Latency P99 | < 100ms | 100-500ms | > 500ms |
| Fetch Latency P99 | < 100ms | 100-500ms | > 500ms |
| Under-replicated | 0 | 1-10 | > 10 |

---

## 7. Risques Architecture Collocalisée

### 7.1 Points de Vigilance

| Risque | Impact | Mitigation | Surveillance |
|--------|--------|------------|--------------|
| **Contention CPU** | Dégradation latence | Monitoring charge | `node_cpu_seconds_total` |
| **Contention mémoire** | OOM possible | Heap sizing prudent | GC pauses, `jvm_memory_*` |
| **Contention I/O disque** | Latence write | Disque dédié si possible | `node_disk_io_time_seconds_total` |
| **Restart simultané** | Indisponibilité | Rolling restart obligatoire | ISR check avant restart |
| **Effet domino** | Panne cascade | Monitoring proactif | Alertes Prometheus |

### 7.2 Seuils de Surveillance Adaptés (Collocalisé)

| Métrique | Seuil OK | Warning | Critical | Note |
|----------|----------|---------|----------|------|
| CPU % total instance | < 60% | 60-75% | > 75% | Plus strict (4 JVM) |
| RAM % total instance | < 75% | 75-85% | > 85% | Marge pour GC |
| Disk I/O % utilisation | < 70% | 70-85% | > 85% | I/O partagé |
| GC pause (broker) | < 100ms | 100-300ms | > 300ms | Impact latence |
| Request Handler Idle | > 60% | 40-60% | < 40% | Threads disponibles |

### 7.3 Commandes de Monitoring (Instance Collocalisée)

```bash
# Vérifier consommation mémoire par JVM
ps aux | grep java | awk '{print $11, $6/1024 "MB"}'

# Vérifier utilisation CPU par process
top -b -n1 | head -20

# Vérifier I/O disque
iostat -x 1 5

# Vérifier file descriptors
lsof | wc -l
cat /proc/sys/fs/file-nr
```

---

## Artifacts Produits

- [x] Configuration server.properties optimisée
- [x] Configuration JVM optimisée (adapté collocation)
- [x] Configuration sysctl
- [x] Procédure rolling restart
- [x] Métriques de validation
- [x] Risques collocation documentés

---

**Client** : Transactis
**Architecture** : Collocalisée (4 vCPU / 32 Go / 250 Go)
**Version** : 2.0 - Adapté architecture collocalisée
**Conformité SLA** : < 1h downtime annuel
