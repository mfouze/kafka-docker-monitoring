# Section 4 : Tests de Résilience ZooKeeper

**Objectif** : Valider la haute disponibilité du quorum ZooKeeper  
**Durée estimée** : 3 heures  
**Prérequis** : Cluster stable, 3 nœuds ZK opérationnels  
**SLA cible** : RTO < 10 secondes pour perte d'un nœud ZK

---

## 4.1 Objectifs de cette Section

| Objectif | Description | SLA |
|----------|-------------|-----|
| Quorum maintenu | Service ZK disponible avec 2/3 nœuds | 100% |
| Failover leader ZK | Élection nouveau leader ZK | < 10 s |
| Impact Kafka | Aucune interruption Kafka | 0 erreur |
| Latence ZK | Maintien latence acceptable | < 100 ms |

---

## 4.2 Architecture ZooKeeper

### Configuration Actuelle

| Nœud | AZ | Rôle | ID |
|------|----|----|-----|
| ZK1 | Paris1 (Marcoussis) | Leader/Follower | 1 |
| ZK2 | Paris2 (Pantin) | Leader/Follower | 2 |
| ZK3 | North1 (Seclin) | Leader/Follower | 3 |

### Vérification État Initial

```bash
# Vérifier le statut de chaque nœud ZK
for ZK in zk1 zk2 zk3; do
  echo "=== ${ZK} ==="
  echo "stat" | nc ${ZK} 2181 | grep Mode
done

# Identifier le leader
for ZK in zk1 zk2 zk3; do
  MODE=$(echo "stat" | nc ${ZK} 2181 | grep Mode | awk '{print $2}')
  if [ "$MODE" == "leader" ]; then
    echo "Leader ZK: ${ZK}"
  fi
done
```

---

## 4.3 Test 4.1 - Perte d'un Follower ZooKeeper

### Objectif

Valider le maintien du service avec perte d'un follower.

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Identifier le leader ZK | Leader: ZK___ |
| 2 | Sélectionner un follower | Follower: ZK___ |
| 3 | Démarrer charge Kafka de fond | ___:___ |
| 4 | Arrêter le follower ZK | ___:___ |
| 5 | Vérifier quorum maintenu | ___:___ |
| 6 | Vérifier continuité Kafka | ___:___ |
| 7 | Redémarrer le follower | ___:___ |
| 8 | Vérifier rejointe au quorum | ___:___ |

### Commandes

```bash
# Étape 4 - Arrêt follower
ssh zk-follower "systemctl stop zookeeper"

# Étape 5 - Vérifier quorum
echo "stat" | nc zk-leader 2181

# Étape 7 - Redémarrage
ssh zk-follower "systemctl start zookeeper"
```

### Métriques à Collecter

| Métrique | Avant | Pendant | Après |
|----------|-------|---------|-------|
| Nœuds ZK actifs | 3 | 2 | 3 |
| Latence ZK (avg) | _____ ms | _____ ms | _____ ms |
| Throughput Kafka | _____ msg/s | _____ msg/s | _____ msg/s |
| Erreurs Kafka | 0 | _____ | 0 |

### Critères de Succès

- [ ] Quorum maintenu (2/3 = majorité)
- [ ] Aucune interruption Kafka
- [ ] Latence ZK < 100 ms
- [ ] Rejointe au quorum < 30 secondes

---

## 4.4 Test 4.2 - Perte du Leader ZooKeeper

### Objectif

Valider l'élection d'un nouveau leader ZK.

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Identifier le leader ZK actuel | Leader: ZK___ |
| 2 | Démarrer charge Kafka de fond | ___:___ |
| 3 | Arrêter le leader ZK | ___:___ |
| 4 | Mesurer temps élection nouveau leader | ___:___ |
| 5 | Vérifier continuité Kafka | ___:___ |
| 6 | Redémarrer l'ancien leader | ___:___ |
| 7 | Vérifier qu'il devient follower | ___:___ |

### Commandes

```bash
# Identifier le leader
LEADER=$(for ZK in zk1 zk2 zk3; do
  MODE=$(echo "stat" | nc ${ZK} 2181 | grep Mode | awk '{print $2}')
  if [ "$MODE" == "leader" ]; then echo ${ZK}; fi
done)
echo "Leader actuel: ${LEADER}"

# Arrêter le leader
ssh ${LEADER} "systemctl stop zookeeper"
START_TIME=$(date +%s%3N)

# Attendre et vérifier nouveau leader
sleep 5
NEW_LEADER=$(for ZK in zk1 zk2 zk3; do
  MODE=$(echo "stat" | nc ${ZK} 2181 2>/dev/null | grep Mode | awk '{print $2}')
  if [ "$MODE" == "leader" ]; then echo ${ZK}; fi
done)
END_TIME=$(date +%s%3N)
ELECTION_TIME=$((END_TIME - START_TIME))

echo "Nouveau leader: ${NEW_LEADER}"
echo "Temps élection: ${ELECTION_TIME} ms"
```

### Grille de Temps

| Événement | Timestamp | Durée |
|-----------|-----------|-------|
| Arrêt leader initié | ___:___:___ | - |
| Nouveau leader élu | ___:___:___ | _____ ms |
| Kafka reconnecté | ___:___:___ | _____ ms |

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Temps élection leader ZK | _____ ms |
| Ancien leader | ZK___ |
| Nouveau leader | ZK___ |
| Erreurs Kafka pendant élection | _____ |
| Pic latence ZK | _____ ms |

### Critères de Succès

- [ ] Nouveau leader élu < 10 secondes
- [ ] Aucune perte de message Kafka
- [ ] Kafka reconnecte automatiquement
- [ ] Ancien leader devient follower au redémarrage

---

## 4.5 Test 4.3 - Perte de Quorum ZooKeeper (2/3 nœuds)

### Objectif

Valider le comportement avec perte de quorum (scénario catastrophique).

### Comportement Attendu

Avec 1/3 nœuds ZK, le quorum est perdu :
- ZooKeeper devient indisponible en lecture/écriture
- Les brokers Kafka ne peuvent plus élire de leaders
- Les opérations de métadonnées échouent

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Démarrer charge Kafka de fond | ___:___ |
| 2 | Arrêter ZK1 | ___:___ |
| 3 | Arrêter ZK2 (immédiatement après) | ___:___ |
| 4 | Observer comportement Kafka | ___:___ |
| 5 | Redémarrer ZK1 | ___:___ |
| 6 | Observer reprise quorum | ___:___ |
| 7 | Redémarrer ZK2 | ___:___ |
| 8 | Vérifier intégrité | ___:___ |

### Commandes

```bash
# Perte de quorum
ssh zk1 "systemctl stop zookeeper"
ssh zk2 "systemctl stop zookeeper"

# Vérifier état du nœud restant
echo "stat" | nc zk3 2181
# Attendu: erreur ou "This ZooKeeper instance is not currently serving requests"

# Restauration
ssh zk1 "systemctl start zookeeper"
# Attendre quelques secondes
ssh zk2 "systemctl start zookeeper"
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Durée perte quorum | _____ s |
| Erreurs Kafka (type) | _____ |
| Kafka: nouvelles connections | ☐ Bloquées |
| Kafka: production existante | ☐ Bloquée ☐ Dégradée |
| Temps reprise après restauration quorum | _____ s |

### Critères de Succès

- [ ] Comportement dégradé documenté et cohérent
- [ ] Aucune corruption de données
- [ ] Reprise automatique après restauration quorum
- [ ] Aucune perte de message (messages bufferisés côté client)

---

## 4.6 Test 4.4 - Latence Réseau ZooKeeper

### Objectif

Mesurer l'impact de la latence réseau entre nœuds ZK.

### Contexte

Observation Jour 3 : Latence ZK ~80 ms (élevée vs best practice < 10 ms).

### Procédure

| Étape | Action |
|-------|--------|
| 1 | Mesurer latence réseau inter-ZK |
| 2 | Mesurer latence ZK actuelle |
| 3 | Injecter latence artificielle (tc) |
| 4 | Mesurer impact sur Kafka |
| 5 | Retirer latence artificielle |

### Commandes

```bash
# Mesurer latence réseau actuelle
for ZK in zk1 zk2 zk3; do
  echo "=== Latence vers ${ZK} ==="
  ping -c 10 ${ZK} | tail -1
done

# Mesurer latence ZK (4 letter words)
for ZK in zk1 zk2 zk3; do
  echo "=== ZK ${ZK} ==="
  echo "srvr" | nc ${ZK} 2181 | grep Latency
done

# Injecter latence (sur un nœud ZK - tc netem)
# ATTENTION: Environnement de test uniquement!
ssh zk1 "tc qdisc add dev eth0 root netem delay 100ms"

# Retirer latence
ssh zk1 "tc qdisc del dev eth0 root"
```

### Grille de Résultats

| Configuration | Latence ZK Avg | Latence Kafka P99 | Throughput |
|---------------|----------------|-------------------|------------|
| Normal | _____ ms | _____ ms | _____ msg/s |
| +50ms inter-ZK | _____ ms | _____ ms | _____ msg/s |
| +100ms inter-ZK | _____ ms | _____ ms | _____ msg/s |
| +200ms inter-ZK | _____ ms | _____ ms | _____ msg/s |

### Critères de Succès

- [ ] Impact latence ZK sur Kafka documenté
- [ ] Seuil critique identifié
- [ ] Recommandations formulées

---

## 4.7 Test 4.5 - Rolling Restart ZooKeeper

### Objectif

Valider une procédure de maintenance ZK sans perte de quorum.

### Procédure

| Étape | Nœud | Action | Durée |
|-------|------|--------|-------|
| 1 | ZK1 (follower) | Stop → Start → Wait | _____ s |
| 2 | ZK2 (follower) | Stop → Start → Wait | _____ s |
| 3 | ZK3 (leader) | Stop → Start → Wait | _____ s |

### Script de Rolling Restart

```bash
#!/bin/bash

# Ordre: followers d'abord, leader en dernier
ZK_ORDER="zk1 zk2"  # Followers
ZK_LEADER="zk3"      # Leader (à identifier dynamiquement)

for ZK in ${ZK_ORDER} ${ZK_LEADER}; do
  echo "=== Redémarrage ${ZK} ==="
  
  # Arrêt
  ssh ${ZK} "systemctl stop zookeeper"
  sleep 5
  
  # Redémarrage
  ssh ${ZK} "systemctl start zookeeper"
  
  # Attente synchronisation
  while true; do
    MODE=$(echo "stat" | nc ${ZK} 2181 2>/dev/null | grep Mode | awk '{print $2}')
    if [ -n "$MODE" ]; then
      echo "${ZK} mode: ${MODE}"
      break
    fi
    sleep 2
  done
  
  # Pause entre nœuds
  echo "Pause 30s avant prochain nœud..."
  sleep 30
done

echo "Rolling restart ZK terminé"
```

### Métriques à Collecter

| Nœud | Temps Indispo | Impact Kafka | Nouveau Mode |
|------|---------------|--------------|--------------|
| ZK1 | _____ s | _____ erreurs | _____ |
| ZK2 | _____ s | _____ erreurs | _____ |
| ZK3 | _____ s | _____ erreurs | _____ |

### Critères de Succès

- [ ] Quorum toujours maintenu (2/3 minimum)
- [ ] Aucune interruption Kafka
- [ ] Temps total < 5 minutes

---

## 4.8 Test 4.6 - Corruption Transaction Log ZK

### Objectif

Valider la récupération après corruption de données ZK.

### Procédure

| Étape | Action |
|-------|--------|
| 1 | Arrêter un nœud ZK follower |
| 2 | Supprimer/Corrompre le dataDir |
| 3 | Redémarrer le nœud |
| 4 | Observer la resynchronisation |

### Commandes

```bash
# Arrêt du follower
ssh zk-follower "systemctl stop zookeeper"

# Backup puis suppression des données (simulation corruption)
ssh zk-follower "mv /var/zookeeper/version-2 /var/zookeeper/version-2.bak"

# Redémarrage (va resync depuis le leader)
ssh zk-follower "systemctl start zookeeper"

# Vérifier la synchronisation
echo "stat" | nc zk-follower 2181
```

### Métriques à Collecter

| Métrique | Valeur |
|----------|--------|
| Temps de resynchronisation | _____ s |
| Taille données resync | _____ MB |
| Erreurs pendant resync | _____ |
| Impact Kafka | _____ |

### Critères de Succès

- [ ] Resynchronisation automatique
- [ ] Aucune perte de données
- [ ] Quorum maintenu pendant recovery

---

## 4.9 Métriques ZooKeeper Clés

### Métriques à Surveiller

| Métrique | Source | Seuil Alerte | Seuil Critique |
|----------|--------|--------------|----------------|
| zk_avg_latency | JMX | > 20 ms | > 100 ms |
| zk_max_latency | JMX | > 100 ms | > 500 ms |
| zk_outstanding_requests | JMX | > 10 | > 100 |
| zk_num_alive_connections | JMX | < 10 | < 3 |
| zk_synced_followers | JMX | < 2 | < 1 |
| zk_pending_syncs | JMX | > 5 | > 10 |

### Requêtes PromQL

```promql
# Latence moyenne ZK
avg(zk_avg_latency)

# Requêtes en attente
sum(zk_outstanding_requests)

# Connexions actives
sum(zk_num_alive_connections)
```

---

## 4.10 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 4.1 - Perte follower ZK
- [ ] Test 4.2 - Perte leader ZK
- [ ] Test 4.3 - Perte quorum
- [ ] Test 4.4 - Latence réseau
- [ ] Test 4.5 - Rolling restart
- [ ] Test 4.6 - Corruption données

### Synthèse des Temps de Récupération

| Scénario | RTO Mesuré | RTO Cible | Statut |
|----------|------------|-----------|--------|
| Perte follower | _____ s | < 10 s | ☐ OK |
| Perte leader | _____ s | < 10 s | ☐ OK |
| Perte quorum | _____ s | N/A | ☐ OK |
| Rolling restart | _____ s/nœud | < 60 s | ☐ OK |

### Résultat Global Section 4

| Critère | Statut |
|---------|--------|
| Failover leader ZK < 10s | ☐ PASS ☐ FAIL |
| Quorum maintenu avec 2/3 | ☐ PASS ☐ FAIL |
| Impact latence documenté | ☐ PASS ☐ FAIL |
| Rolling restart sans interruption | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests de Résilience Broker](03-tests-resilience-broker.md)  
**Section suivante** : [Tests de Résilience MirrorMaker 2](05-tests-resilience-mm2.md)
