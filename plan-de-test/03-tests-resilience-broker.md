# Section 3 : Tests de Résilience Broker

**Objectif** : Valider la haute disponibilité lors de pannes de brokers  
**Durée estimée** : 4 heures  
**Prérequis** : Cluster stable, charge de fond active  
**SLA cible** : RTO < 30 secondes pour perte d'un broker

---

## 3.1 Objectifs de cette Section

| Objectif | Description | SLA |
|----------|-------------|-----|
| Failover leader | Temps d'élection nouveau leader | < 30 s |
| Continuité service | Pas d'interruption pour les clients | 0 erreur |
| Réplication | Rattrapage du broker après redémarrage | < 5 min |
| Données | Aucune perte de données | 0 message perdu |

---

## 3.2 Configuration de Fond de Charge

### Charge Continue Pendant les Tests

```bash
# À exécuter en arrière-plan pendant tous les tests de résilience
kafka-producer-perf-test \
  --topic resilience-broker-test \
  --num-records 10000000 \
  --record-size 1024 \
  --throughput 2000 \
  --producer.config producer-tls.properties &

PRODUCER_PID=$!
echo "Producteur de fond lancé (PID: ${PRODUCER_PID})"
```

### Configuration Producteur Résiliente

```properties
# producer-resilient.properties
bootstrap.servers=broker1:9092,broker2:9092,broker3:9092

# Garanties de livraison
acks=all
retries=2147483647
max.in.flight.requests.per.connection=5
enable.idempotence=true

# Timeouts
request.timeout.ms=30000
delivery.timeout.ms=120000
retry.backoff.ms=100

# Sécurité
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
```

---

## 3.3 Test 3.1 - Arrêt Graceful d'un Broker (Non-Controller)

### Objectif

Valider le comportement lors d'un arrêt planifié d'un broker non-controller.

### Prérequis

```bash
# Identifier le controller actuel
kafka-metadata --snapshot /var/kafka-logs/__cluster_metadata-0/00000000000000000000.log \
  --command "cat" | grep "controller"

# OU via ZooKeeper
echo "get /controller" | zkcli
```

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier état initial (3/3 brokers UP) | ___:___ |
| 2 | Noter le controller ID | Broker ID: ___ |
| 3 | Sélectionner un broker NON-controller | Broker ID: ___ |
| 4 | Démarrer la charge de fond | ___:___ |
| 5 | Exécuter arrêt graceful | ___:___ |
| 6 | Mesurer temps d'élection leaders | ___:___ |
| 7 | Vérifier continuité production | ___:___ |
| 8 | Redémarrer le broker | ___:___ |
| 9 | Mesurer temps de rattrapage ISR | ___:___ |

### Commandes

```bash
# Étape 5 - Arrêt graceful
systemctl stop kafka

# Étape 8 - Redémarrage
systemctl start kafka
```

### Métriques à Collecter

| Métrique | Avant Arrêt | Pendant Arrêt | Après Redém. |
|----------|-------------|---------------|--------------|
| Brokers actifs | 3 | 2 | 3 |
| Under-replicated partitions | 0 | _____ | 0 |
| Offline partitions | 0 | 0 | 0 |
| Throughput production | _____ | _____ | _____ |
| Erreurs production | 0 | _____ | 0 |

### Grille de Temps

| Événement | Timestamp | Durée |
|-----------|-----------|-------|
| Arrêt initié | ___:___:___ | - |
| Leaders ré-élus | ___:___:___ | _____ s |
| Production reprise | ___:___:___ | _____ s |
| Broker redémarré | ___:___:___ | - |
| ISR complet | ___:___:___ | _____ s |

### Critères de Succès

- [ ] Temps élection leaders < 30 secondes
- [ ] Aucune offline partition
- [ ] Aucune perte de message
- [ ] Retour ISR complet < 5 minutes
- [ ] Erreurs production < 10 (retries réussis)

---

## 3.4 Test 3.2 - Arrêt Forcé d'un Broker (Kill -9)

### Objectif

Simuler un crash brutal de broker (panne matérielle).

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier état initial | ___:___ |
| 2 | Sélectionner un broker non-controller | Broker ID: ___ |
| 3 | Démarrer la charge de fond | ___:___ |
| 4 | Exécuter kill -9 sur le processus Kafka | ___:___ |
| 5 | Mesurer temps de détection | ___:___ |
| 6 | Mesurer temps d'élection leaders | ___:___ |
| 7 | Vérifier continuité production | ___:___ |
| 8 | Redémarrer le broker | ___:___ |
| 9 | Mesurer temps de recovery | ___:___ |

### Commandes

```bash
# Étape 4 - Kill forcé
kill -9 $(pgrep -f kafka.Kafka)

# OU
pkill -9 -f "kafka.Kafka"

# Étape 8 - Redémarrage
systemctl start kafka
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Temps détection panne (ZK session timeout) | _____ s |
| Temps élection nouveaux leaders | _____ s |
| Nombre de partitions affectées | _____ |
| Erreurs production pendant panne | _____ |
| Temps recovery (ISR complet) | _____ s |

### Comparaison Graceful vs Forcé

| Métrique | Graceful (3.1) | Forcé (3.2) | Écart |
|----------|----------------|-------------|-------|
| Temps élection | _____ s | _____ s | _____ s |
| Erreurs production | _____ | _____ | _____ |
| Temps recovery ISR | _____ s | _____ s | _____ s |

### Critères de Succès

- [ ] Détection panne < zookeeper.session.timeout.ms (18s configuré)
- [ ] Élection leaders < 30 secondes après détection
- [ ] Aucune perte de message (acks=all)
- [ ] Recovery < 10 minutes

---

## 3.5 Test 3.3 - Perte du Broker Controller

### Objectif

Valider le failover du controller Kafka.

### Prérequis

```bash
# Identifier le controller
CONTROLLER_ID=$(kafka-metadata --command "cat" | grep controller | awk '{print $NF}')
echo "Controller actuel: Broker ${CONTROLLER_ID}"
```

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Identifier le broker controller | Broker ID: ___ |
| 2 | Démarrer la charge de fond | ___:___ |
| 3 | Arrêter le broker controller | ___:___ |
| 4 | Mesurer temps d'élection nouveau controller | ___:___ |
| 5 | Mesurer temps d'élection des leaders | ___:___ |
| 6 | Vérifier continuité production | ___:___ |
| 7 | Redémarrer l'ancien controller | ___:___ |
| 8 | Vérifier qu'il devient follower (pas re-controller) | ___:___ |

### Commandes

```bash
# Sur le broker controller
systemctl stop kafka

# Vérifier le nouveau controller
echo "get /controller" | zkcli
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Temps élection nouveau controller | _____ s |
| Temps élection leaders partitions | _____ s |
| Erreurs production | _____ |
| Nouveau controller ID | Broker ___ |

### Critères de Succès

- [ ] Nouveau controller élu < 30 secondes
- [ ] Leaders partitions ré-élus < 30 secondes
- [ ] Aucune perte de message
- [ ] Ancien controller devient follower au redémarrage

---

## 3.6 Test 3.4 - Perte de Deux Brokers Simultanés

### Objectif

Valider le comportement avec perte de quorum (2/3 brokers down).

### Prérequis

- Configuration : min.insync.replicas = 2
- Replication factor = 3

### Comportement Attendu

Avec RF=3 et min.insync.replicas=2, la perte de 2 brokers doit :
- Rendre les partitions indisponibles en écriture
- Préserver les données (pas de perte)
- Permettre la lecture sur le broker restant

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier état initial | ___:___ |
| 2 | Démarrer la charge de fond | ___:___ |
| 3 | Arrêter broker 1 | ___:___ |
| 4 | Arrêter broker 2 (immédiatement après) | ___:___ |
| 5 | Observer comportement production | ___:___ |
| 6 | Tester consommation | ___:___ |
| 7 | Redémarrer broker 1 | ___:___ |
| 8 | Observer reprise production | ___:___ |
| 9 | Redémarrer broker 2 | ___:___ |
| 10 | Vérifier intégrité données | ___:___ |

### Commandes

```bash
# Étapes 3-4 - Arrêts séquentiels rapides
ssh broker1 "systemctl stop kafka"
ssh broker2 "systemctl stop kafka"

# Étapes 7-9 - Redémarrages
ssh broker1 "systemctl start kafka"
sleep 60
ssh broker2 "systemctl start kafka"
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Under-replicated partitions | _____ |
| Offline partitions | _____ |
| Erreurs production (NOT_ENOUGH_REPLICAS) | _____ |
| Consommation possible | ☐ Oui ☐ Non |
| Temps retour service après 1er redémarrage | _____ s |

### Critères de Succès

- [ ] Production bloquée (comportement attendu avec min.isr=2)
- [ ] Aucune perte de données
- [ ] Consommation possible sur broker restant
- [ ] Reprise immédiate après redémarrage du 1er broker

---

## 3.7 Test 3.5 - Redémarrage Rolling des Brokers

### Objectif

Valider une procédure de maintenance sans interruption de service.

### Procédure

| Étape | Broker | Action | Durée Down |
|-------|--------|--------|------------|
| 1 | Broker 1 | Stop → Start → Wait ISR | _____ s |
| 2 | Broker 2 | Stop → Start → Wait ISR | _____ s |
| 3 | Broker 3 | Stop → Start → Wait ISR | _____ s |

### Script de Rolling Restart

```bash
#!/bin/bash
BROKERS="broker1 broker2 broker3"

for BROKER in ${BROKERS}; do
  echo "=== Redémarrage ${BROKER} ==="
  
  # Arrêt
  ssh ${BROKER} "systemctl stop kafka"
  START_TIME=$(date +%s)
  
  # Attente arrêt
  sleep 10
  
  # Redémarrage
  ssh ${BROKER} "systemctl start kafka"
  
  # Attente ISR complet
  while true; do
    URP=$(kafka-topics --describe --bootstrap-server ${BOOTSTRAP} | grep -c "Isr:")
    if [ "$URP" -eq "0" ]; then
      break
    fi
    sleep 5
  done
  
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  echo "${BROKER} recovery: ${DURATION}s"
  
  # Pause entre brokers
  sleep 30
done
```

### Métriques à Collecter

| Broker | Temps Down | Erreurs Prod | Under-Rep Max |
|--------|------------|--------------|---------------|
| Broker 1 | _____ s | _____ | _____ |
| Broker 2 | _____ s | _____ | _____ |
| Broker 3 | _____ s | _____ | _____ |

### Critères de Succès

- [ ] Aucune interruption de service
- [ ] Erreurs production = 0 (avec retries)
- [ ] Offline partitions = 0 pendant tout le process
- [ ] Temps total < 15 minutes

---

## 3.8 Test 3.6 - Saturation Disque Broker

### Objectif

Valider le comportement lors d'une saturation disque.

### Procédure

| Étape | Action |
|-------|--------|
| 1 | Identifier le répertoire de logs Kafka |
| 2 | Créer un fichier volumineux pour saturer le disque |
| 3 | Observer le comportement du broker |
| 4 | Libérer l'espace disque |
| 5 | Vérifier la récupération |

### Commandes

```bash
# Saturer le disque (ATTENTION: environnement de test uniquement!)
dd if=/dev/zero of=/var/kafka-logs/dummy-fill.dat bs=1G count=200

# Vérifier espace disque
df -h /var/kafka-logs

# Libérer
rm /var/kafka-logs/dummy-fill.dat
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Espace disque avant saturation | _____ GB |
| Comportement broker | ☐ Erreur ☐ Ralenti ☐ Stop |
| Erreurs de log observées | _____ |
| Temps récupération après libération | _____ s |

### Critères de Succès

- [ ] Broker détecte la saturation et refuse les writes
- [ ] Pas de corruption de données
- [ ] Récupération automatique après libération

---

## 3.9 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 3.1 - Arrêt graceful
- [ ] Test 3.2 - Arrêt forcé (kill -9)
- [ ] Test 3.3 - Perte controller
- [ ] Test 3.4 - Perte 2 brokers
- [ ] Test 3.5 - Rolling restart
- [ ] Test 3.6 - Saturation disque

### Synthèse des Temps de Récupération

| Scénario | RTO Mesuré | RTO Cible | Statut |
|----------|------------|-----------|--------|
| Arrêt graceful | _____ s | < 30 s | ☐ OK |
| Arrêt forcé | _____ s | < 30 s | ☐ OK |
| Perte controller | _____ s | < 30 s | ☐ OK |
| Perte 2 brokers | _____ s | N/A (dégradé) | ☐ OK |
| Rolling restart | _____ s/broker | < 120 s | ☐ OK |

### Résultat Global Section 3

| Critère | Statut |
|---------|--------|
| RTO < 30s pour perte 1 broker | ☐ PASS ☐ FAIL |
| Aucune perte de données | ☐ PASS ☐ FAIL |
| Rolling restart sans interruption | ☐ PASS ☐ FAIL |
| Comportement dégradé documenté | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests de Charge et Stress](02-tests-charge-stress.md)  
**Section suivante** : [Tests de Résilience ZooKeeper](04-tests-resilience-zookeeper.md)
