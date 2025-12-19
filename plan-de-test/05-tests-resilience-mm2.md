# Section 5 : Tests de Résilience MirrorMaker 2

**Objectif** : Valider la haute disponibilité de la réplication MM2  
**Durée estimée** : 4 heures  
**Prérequis** : MM2 Connect-based opérationnel, 3 workers  
**SLA cible** : RTO < 60 secondes, RPO < 1 minute de lag

---

## 5.1 Objectifs de cette Section

| Objectif | Description | SLA |
|----------|-------------|-----|
| Failover worker | Rebalancing après perte d'un worker | < 60 s |
| Continuité réplication | Pas d'interruption de flux | 0 message perdu |
| Lag contrôlé | Lag max acceptable pendant incident | < 60 s |
| Auto-recovery | Reprise automatique après incident | 100% |

---

## 5.2 Architecture MM2 Connect-Based

### Configuration Actuelle

| Worker | AZ | Connecteurs Hébergés |
|--------|----|-----------------------|
| Connect Worker 1 | Paris1 | MirrorSourceConnector (tasks) |
| Connect Worker 2 | Paris2 | MirrorCheckpointConnector |
| Connect Worker 3 | North1 | MirrorHeartbeatConnector |

### Connecteurs Déployés

| Connecteur | Rôle | Tasks |
|------------|------|-------|
| MirrorSourceConnector | Réplication données | 3 |
| MirrorCheckpointConnector | Sync offsets | 1 |
| MirrorHeartbeatConnector | Heartbeat | 1 |

### Vérification État Initial

```bash
# Lister les connecteurs
curl -s http://connect:8083/connectors | jq .

# Statut de chaque connecteur
for CONNECTOR in mirror-source mirror-checkpoint mirror-heartbeat; do
  echo "=== ${CONNECTOR} ==="
  curl -s http://connect:8083/connectors/${CONNECTOR}/status | jq .
done

# Lister les workers du cluster Connect
curl -s http://connect:8083/ | jq .
```

---

## 5.3 Test 5.1 - Perte d'un Worker Connect

### Objectif

Valider le rebalancing automatique des tâches après perte d'un worker.

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier état initial (3 workers, tous connecteurs RUNNING) | ___:___ |
| 2 | Démarrer production continue sur cluster source | ___:___ |
| 3 | Démarrer consommation sur cluster target | ___:___ |
| 4 | Noter distribution des tasks | ___:___ |
| 5 | Arrêter un worker Connect | ___:___ |
| 6 | Mesurer temps de rebalancing | ___:___ |
| 7 | Vérifier continuité réplication | ___:___ |
| 8 | Redémarrer le worker | ___:___ |
| 9 | Observer nouveau rebalancing | ___:___ |

### Commandes

```bash
# Étape 4 - Distribution des tasks avant
curl -s http://connect:8083/connectors/mirror-source/status | jq '.tasks[] | {id: .id, worker_id: .worker_id}'

# Étape 5 - Arrêt d'un worker
ssh connect-worker1 "systemctl stop kafka-connect"
START_TIME=$(date +%s%3N)

# Étape 6 - Attendre rebalancing et vérifier
sleep 30
curl -s http://connect:8083/connectors/mirror-source/status | jq '.tasks[] | {id: .id, worker_id: .worker_id, state: .state}'
END_TIME=$(date +%s%3N)
echo "Temps rebalancing: $((END_TIME - START_TIME)) ms"

# Étape 8 - Redémarrage
ssh connect-worker1 "systemctl start kafka-connect"
```

### Métriques à Collecter

| Métrique | Avant | Pendant | Après Rebal. |
|----------|-------|---------|--------------|
| Workers actifs | 3 | 2 | 3 |
| Tasks RUNNING | _____ | _____ | _____ |
| Tasks FAILED | 0 | _____ | 0 |
| Lag réplication (messages) | _____ | _____ | _____ |
| Throughput source | _____ msg/s | _____ msg/s | _____ msg/s |
| Throughput target | _____ msg/s | _____ msg/s | _____ msg/s |

### Grille de Temps

| Événement | Timestamp | Durée |
|-----------|-----------|-------|
| Arrêt worker initié | ___:___:___ | - |
| Rebalancing déclenché | ___:___:___ | _____ s |
| Tasks redistribuées | ___:___:___ | _____ s |
| Réplication reprise | ___:___:___ | _____ s |

### Critères de Succès

- [ ] Rebalancing < 60 secondes
- [ ] Aucune task en état FAILED après rebalancing
- [ ] Lag maximum < 60 secondes de données
- [ ] Aucune perte de message

---

## 5.4 Test 5.2 - Perte de Deux Workers (Quorum Connect)

### Objectif

Valider le comportement avec perte de majorité des workers.

### Comportement Attendu

Avec 1/3 workers, le cluster Connect devrait :
- Continuer à fonctionner (pas de quorum requis pour Connect)
- Héberger toutes les tasks sur le worker restant
- Potentiellement être limité en capacité

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier état initial | ___:___ |
| 2 | Démarrer charge réplication | ___:___ |
| 3 | Arrêter worker 1 | ___:___ |
| 4 | Arrêter worker 2 | ___:___ |
| 5 | Observer comportement | ___:___ |
| 6 | Vérifier toutes tasks sur worker 3 | ___:___ |
| 7 | Mesurer capacité résiduelle | ___:___ |
| 8 | Redémarrer workers | ___:___ |

### Commandes

```bash
# Arrêts séquentiels
ssh connect-worker1 "systemctl stop kafka-connect"
sleep 5
ssh connect-worker2 "systemctl stop kafka-connect"

# Vérifier état
curl -s http://connect-worker3:8083/connectors/mirror-source/status | jq .

# Redémarrages
ssh connect-worker1 "systemctl start kafka-connect"
ssh connect-worker2 "systemctl start kafka-connect"
```

### Métriques à Collecter

| Métrique | 3 Workers | 1 Worker | Restauré |
|----------|-----------|----------|----------|
| Tasks RUNNING | _____ | _____ | _____ |
| Throughput réplication | _____ msg/s | _____ msg/s | _____ msg/s |
| Lag max | _____ | _____ | _____ |
| CPU worker restant | ___% | ___% | ___% |

### Critères de Succès

- [ ] Toutes les tasks hébergées sur le worker restant
- [ ] Réplication continue (même dégradée)
- [ ] Aucune perte de message
- [ ] Retour à la normale après redémarrage

---

## 5.5 Test 5.3 - Restart d'un Connecteur

### Objectif

Valider le comportement lors du restart d'un connecteur.

### Procédure pour chaque connecteur

| Connecteur | Action | Impact Attendu |
|------------|--------|----------------|
| MirrorSourceConnector | Restart | Pause réplication |
| MirrorCheckpointConnector | Restart | Pause sync offsets |
| MirrorHeartbeatConnector | Restart | Pause heartbeats |

### Commandes

```bash
# Restart MirrorSourceConnector
curl -X POST http://connect:8083/connectors/mirror-source/restart

# Restart avec tasks
curl -X POST http://connect:8083/connectors/mirror-source/restart?includeTasks=true

# Pause puis Resume
curl -X PUT http://connect:8083/connectors/mirror-source/pause
sleep 10
curl -X PUT http://connect:8083/connectors/mirror-source/resume
```

### Grille de Résultats

| Connecteur | Temps Restart | Lag Induit | Erreurs |
|------------|---------------|------------|---------|
| mirror-source | _____ s | _____ msg | _____ |
| mirror-checkpoint | _____ s | N/A | _____ |
| mirror-heartbeat | _____ s | N/A | _____ |

### Critères de Succès

- [ ] Restart < 30 secondes
- [ ] Reprise automatique de la réplication
- [ ] Lag rattrapé en < 5 minutes

---

## 5.6 Test 5.4 - Échec de Task et Auto-Restart

### Objectif

Valider le mécanisme d'auto-restart des tasks en échec.

### Configuration Requise

```json
{
  "errors.retry.timeout": "300000",
  "errors.retry.delay.max.ms": "60000",
  "errors.tolerance": "all",
  "errors.log.enable": "true"
}
```

### Procédure

| Étape | Action |
|-------|--------|
| 1 | Identifier une task du MirrorSourceConnector |
| 2 | Provoquer un échec (ex: couper accès au topic source) |
| 3 | Observer le passage en état FAILED |
| 4 | Observer l'auto-restart |
| 5 | Restaurer l'accès |
| 6 | Vérifier la reprise |

### Commandes

```bash
# Statut d'une task spécifique
curl -s http://connect:8083/connectors/mirror-source/tasks/0/status | jq .

# Restart manuel d'une task
curl -X POST http://connect:8083/connectors/mirror-source/tasks/0/restart
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Temps avant FAILED | _____ s |
| Nombre de retries | _____ |
| Temps avant auto-restart | _____ s |
| Temps récupération totale | _____ s |

### Critères de Succès

- [ ] Task détecte l'erreur rapidement
- [ ] Auto-restart fonctionne
- [ ] Reprise sans intervention manuelle

---

## 5.7 Test 5.5 - Perte de Connectivité Cluster Source

### Objectif

Valider le comportement MM2 lors de perte de connectivité vers le cluster source.

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier état initial réplication OK | ___:___ |
| 2 | Couper connectivité vers cluster source (iptables) | ___:___ |
| 3 | Observer comportement MM2 | ___:___ |
| 4 | Mesurer temps avant état FAILED | ___:___ |
| 5 | Restaurer connectivité | ___:___ |
| 6 | Mesurer temps de récupération | ___:___ |
| 7 | Vérifier intégrité données | ___:___ |

### Commandes

```bash
# Couper connectivité (sur workers Connect)
iptables -A OUTPUT -d source-broker1 -j DROP
iptables -A OUTPUT -d source-broker2 -j DROP
iptables -A OUTPUT -d source-broker3 -j DROP

# Restaurer
iptables -D OUTPUT -d source-broker1 -j DROP
iptables -D OUTPUT -d source-broker2 -j DROP
iptables -D OUTPUT -d source-broker3 -j DROP
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Temps avant détection perte | _____ s |
| État connecteurs après perte | _____ |
| Temps reconnexion après restauration | _____ s |
| Messages perdus | _____ |
| Lag à rattraper | _____ messages |
| Temps rattrapage | _____ s |

### Critères de Succès

- [ ] Détection de la perte < 30 secondes
- [ ] Reconnexion automatique
- [ ] Aucune perte de message (grâce aux offsets)
- [ ] Rattrapage du lag < 5 minutes

---

## 5.8 Test 5.6 - Perte de Connectivité Cluster Target

### Objectif

Valider le comportement MM2 lors de perte de connectivité vers le cluster target.

### Procédure

Similaire au test 5.5, mais en coupant la connectivité vers le cluster target.

### Comportement Attendu

- MM2 continue de consommer depuis la source
- Les messages sont bufferisés
- Risque de backpressure si coupure prolongée

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Temps avant saturation buffer | _____ s |
| Messages bufferisés | _____ |
| Erreurs de production | _____ |
| Temps récupération après restauration | _____ s |

---

## 5.9 Test 5.7 - Changement de Configuration à Chaud

### Objectif

Valider la modification de configuration MM2 sans redémarrage.

### Configurations à Tester

| Paramètre | Valeur Initiale | Nouvelle Valeur |
|-----------|-----------------|-----------------|
| tasks.max | 3 | 5 |
| topics.regex | `test-.*` | `test-.*\|prod-.*` |
| sync.group.offsets.enabled | true | false |

### Commandes

```bash
# Récupérer config actuelle
curl -s http://connect:8083/connectors/mirror-source/config | jq .

# Modifier configuration
curl -X PUT http://connect:8083/connectors/mirror-source/config \
  -H "Content-Type: application/json" \
  -d '{
    "connector.class": "org.apache.kafka.connect.mirror.MirrorSourceConnector",
    "tasks.max": "5",
    "topics": "test-.*|prod-.*",
    "source.cluster.alias": "source",
    "target.cluster.alias": "target",
    ...
  }'
```

### Métriques à Collecter

| Modification | Temps Apply | Rebalancing | Impact Réplication |
|--------------|-------------|-------------|-------------------|
| tasks.max | _____ s | ☐ Oui ☐ Non | _____ |
| topics.regex | _____ s | ☐ Oui ☐ Non | _____ |
| sync.group.offsets | _____ s | ☐ Oui ☐ Non | _____ |

### Critères de Succès

- [ ] Modification appliquée sans redémarrage
- [ ] Interruption minimale (< 30 secondes)
- [ ] Pas de perte de message

---

## 5.10 Métriques MM2 Clés

### Métriques à Surveiller

| Métrique | Source | Seuil Alerte | Seuil Critique |
|----------|--------|--------------|----------------|
| record-count | JMX | - | = 0 prolongé |
| record-send-rate | JMX | < 100/s | = 0 |
| replication-latency-ms-avg | JMX | > 1000 ms | > 5000 ms |
| byte-rate | JMX | < 1 MB/s | = 0 |
| source-record-poll-rate | JMX | < 100/s | = 0 |
| source-record-active-count | JMX | - | = 0 prolongé |

### Requêtes PromQL

```promql
# Lag de réplication MM2
kafka_connect_mirror_source_connector_replication_latency_ms_avg

# Throughput réplication
rate(kafka_connect_mirror_source_connector_record_count[5m])

# Tasks en échec
kafka_connect_connector_task_status{status="failed"}
```

---

## 5.11 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 5.1 - Perte d'un worker
- [ ] Test 5.2 - Perte de deux workers
- [ ] Test 5.3 - Restart connecteur
- [ ] Test 5.4 - Échec de task
- [ ] Test 5.5 - Perte connectivité source
- [ ] Test 5.6 - Perte connectivité target
- [ ] Test 5.7 - Config à chaud

### Synthèse des Temps de Récupération

| Scénario | RTO Mesuré | RTO Cible | Statut |
|----------|------------|-----------|--------|
| Perte 1 worker | _____ s | < 60 s | ☐ OK |
| Perte 2 workers | _____ s | < 120 s | ☐ OK |
| Restart connecteur | _____ s | < 30 s | ☐ OK |
| Perte connectivité | _____ s | < 60 s | ☐ OK |

### Résultat Global Section 5

| Critère | Statut |
|---------|--------|
| Failover worker < 60s | ☐ PASS ☐ FAIL |
| Aucune perte message | ☐ PASS ☐ FAIL |
| Auto-recovery fonctionnel | ☐ PASS ☐ FAIL |
| Config à chaud opérationnelle | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests de Résilience ZooKeeper](04-tests-resilience-zookeeper.md)  
**Section suivante** : [Tests de Failover Multi-AZ](06-tests-failover-az.md)
