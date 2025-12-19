# Section 6 : Tests de Failover Multi-AZ

**Objectif** : Valider la résilience lors de perte d'une zone de disponibilité complète  
**Durée estimée** : 4 heures  
**Prérequis** : Architecture 3 AZ validée  
**SLA cible** : RTO < 2 minutes pour perte d'une AZ

---

## 6.1 Objectifs de cette Section

| Objectif | Description | SLA |
|----------|-------------|-----|
| Continuité service | Service maintenu avec 2/3 AZ | 100% |
| Failover automatique | Pas d'intervention manuelle | Auto |
| Données préservées | Aucune perte de données | 0 msg |
| Récupération | Retour à la normale après restauration AZ | < 10 min |

---

## 6.2 Architecture Multi-AZ

### Répartition des Composants

| Composant | AZ1 (Paris1) | AZ2 (Paris2) | AZ3 (North1) |
|-----------|--------------|--------------|--------------|
| Kafka Broker | Broker 1 | Broker 2 | Broker 3 |
| ZooKeeper | ZK 1 | ZK 2 | ZK 3 |
| Connect Worker | Worker 1 | Worker 2 | Worker 3 |
| Schema Registry | SR 1 | - | - |

### Hypothèses

- Chaque AZ contient 1/3 des composants
- RF=3, min.insync.replicas=2
- Perte d'une AZ = perte de 1 broker + 1 ZK + 1 worker

---

## 6.3 Test 6.1 - Perte AZ1 (Paris1 / Marcoussis)

### Composants Impactés

- Broker 1
- ZooKeeper 1
- Connect Worker 1

### Procédure

| Étape | Action | Timestamp |
|-------|--------|-----------|
| 1 | Vérifier état initial complet | ___:___ |
| 2 | Démarrer charge production continue | ___:___ |
| 3 | Démarrer consommation continue | ___:___ |
| 4 | Simuler perte AZ1 (arrêt simultané de tous les composants) | ___:___ |
| 5 | Mesurer temps de détection | ___:___ |
| 6 | Mesurer temps de failover complet | ___:___ |
| 7 | Vérifier continuité service | ___:___ |
| 8 | Laisser tourner 10 minutes en mode dégradé | ___:___ |
| 9 | Restaurer AZ1 | ___:___ |
| 10 | Mesurer temps de récupération complète | ___:___ |

### Commandes de Simulation

```bash
#!/bin/bash
# Script de simulation perte AZ1

echo "=== Arrêt AZ1 (Paris1) ==="
START_TIME=$(date +%s%3N)

# Arrêt simultané
ssh broker1 "systemctl stop kafka" &
ssh zk1 "systemctl stop zookeeper" &
ssh connect1 "systemctl stop kafka-connect" &
wait

echo "AZ1 arrêtée à $(date)"

# Monitoring
while true; do
  echo "=== État à $(date) ==="
  echo "Brokers actifs: $(kafka-broker-api-versions --bootstrap-server broker2:9092,broker3:9092 2>/dev/null | grep -c 'ApiVersion')"
  echo "ZK quorum: $(echo 'stat' | nc zk2 2181 | grep Mode)"
  echo "Connect workers: $(curl -s http://connect2:8083/ | jq -r '.kafka_cluster_id // "N/A"')"
  sleep 10
done
```

### Grille de Temps - Failover

| Événement | Timestamp | Durée depuis T0 |
|-----------|-----------|-----------------|
| T0: Arrêt AZ1 initié | ___:___:___ | 0 |
| ZK1 détecté down | ___:___:___ | _____ s |
| Broker1 détecté down | ___:___:___ | _____ s |
| Élection leaders partitions | ___:___:___ | _____ s |
| Rebalancing Connect | ___:___:___ | _____ s |
| Service pleinement opérationnel | ___:___:___ | _____ s |

### Métriques Pendant Mode Dégradé (2 AZ)

| Métrique | Valeur | Attendu |
|----------|--------|---------|
| Brokers actifs | 2 | 2 |
| Nœuds ZK actifs | 2 | 2 (quorum maintenu) |
| Workers Connect actifs | 2 | 2 |
| Under-replicated partitions | _____ | > 0 (attendu) |
| Offline partitions | 0 | 0 |
| Throughput production | _____ msg/s | > 70% nominal |
| Latence P99 | _____ ms | < 200 ms |
| Erreurs production | _____ | < 100 |

### Grille de Temps - Récupération

| Événement | Timestamp | Durée depuis restauration |
|-----------|-----------|---------------------------|
| T1: Démarrage restauration AZ1 | ___:___:___ | 0 |
| ZK1 rejoint quorum | ___:___:___ | _____ s |
| Broker1 rejoint cluster | ___:___:___ | _____ s |
| Connect1 rejoint cluster | ___:___:___ | _____ s |
| ISR complet (under-rep = 0) | ___:___:___ | _____ s |
| Rebalancing Connect terminé | ___:___:___ | _____ s |

### Critères de Succès

- [ ] Failover total < 2 minutes
- [ ] Quorum ZK maintenu (2/3)
- [ ] Service Kafka opérationnel
- [ ] Aucune perte de message
- [ ] Récupération complète < 10 minutes

---

## 6.4 Test 6.2 - Perte AZ2 (Paris2 / Pantin)

### Procédure

Identique au Test 6.1, mais pour AZ2.

### Grille de Résultats

| Métrique | Valeur |
|----------|--------|
| Temps failover total | _____ s |
| Erreurs pendant failover | _____ |
| Temps récupération | _____ s |
| Messages perdus | _____ |

---

## 6.5 Test 6.3 - Perte AZ3 (North1 / Seclin)

### Procédure

Identique au Test 6.1, mais pour AZ3.

### Grille de Résultats

| Métrique | Valeur |
|----------|--------|
| Temps failover total | _____ s |
| Erreurs pendant failover | _____ |
| Temps récupération | _____ s |
| Messages perdus | _____ |

---

## 6.6 Test 6.4 - Perte Séquentielle de Deux AZ

### Objectif

Valider le comportement lors de pannes successives.

### Scénario

```
T0: État normal (3 AZ)
T1: Perte AZ1 → Failover → État dégradé (2 AZ)
T2: Perte AZ2 → Perte de service (1 AZ)
T3: Restauration AZ1 → Reprise service (2 AZ)
T4: Restauration AZ2 → État normal (3 AZ)
```

### Procédure

| Étape | Action | État | Timestamp |
|-------|--------|------|-----------|
| 1 | État initial | 3 AZ | ___:___ |
| 2 | Arrêt AZ1 | 2 AZ | ___:___ |
| 3 | Attente stabilisation | 2 AZ | ___:___ |
| 4 | Arrêt AZ2 | 1 AZ | ___:___ |
| 5 | Observer perte service | Dégradé | ___:___ |
| 6 | Restauration AZ1 | 2 AZ | ___:___ |
| 7 | Observer reprise | Opérationnel | ___:___ |
| 8 | Restauration AZ2 | 3 AZ | ___:___ |

### Métriques à Collecter

| Phase | Brokers | ZK Quorum | Service | Production |
|-------|---------|-----------|---------|------------|
| 3 AZ | 3 | Oui | OK | _____ msg/s |
| 2 AZ | 2 | Oui | OK | _____ msg/s |
| 1 AZ | 1 | Non | KO | 0 msg/s |
| 2 AZ (restauré) | 2 | Oui | OK | _____ msg/s |
| 3 AZ (restauré) | 3 | Oui | OK | _____ msg/s |

### Comportement Attendu avec 1 AZ

| Composant | État | Raison |
|-----------|------|--------|
| Kafka | Indisponible | min.insync.replicas=2, seul 1 broker |
| ZooKeeper | Indisponible | Quorum perdu (1/3 < majorité) |
| Connect | Dégradé | Pas de cluster Kafka disponible |

### Critères de Succès

- [ ] Transition 3 AZ → 2 AZ transparente
- [ ] Comportement 1 AZ documenté (perte service attendue)
- [ ] Reprise automatique à 2 AZ
- [ ] Aucune corruption de données

---

## 6.7 Test 6.5 - Isolation Réseau d'une AZ (Split-Brain)

### Objectif

Valider le comportement lors d'une partition réseau (AZ isolée mais fonctionnelle).

### Scénario

AZ1 devient isolée mais ses composants continuent de fonctionner localement.

### Procédure

| Étape | Action |
|-------|--------|
| 1 | Bloquer le trafic réseau entre AZ1 et AZ2/AZ3 |
| 2 | Observer le comportement de chaque côté de la partition |
| 3 | Vérifier qu'un seul côté accepte les writes |
| 4 | Restaurer la connectivité |
| 5 | Vérifier la réconciliation |

### Commandes (sur les routeurs/firewalls)

```bash
# Isolation AZ1 (sur AZ1)
iptables -A INPUT -s AZ2_SUBNET -j DROP
iptables -A INPUT -s AZ3_SUBNET -j DROP
iptables -A OUTPUT -d AZ2_SUBNET -j DROP
iptables -A OUTPUT -d AZ3_SUBNET -j DROP

# Restauration
iptables -F
```

### Comportement Attendu

| Côté | ZK | Kafka | Accepte Writes |
|------|----|----|----------------|
| AZ1 (isolée) | Perd quorum | Broker sans controller | Non |
| AZ2 + AZ3 | Quorum (2/3) | Controller élu | Oui |

### Critères de Succès

- [ ] Un seul côté accepte les writes (pas de split-brain)
- [ ] Côté majoritaire maintient le service
- [ ] Réconciliation automatique après restauration
- [ ] Aucune perte de données

---

## 6.8 Test 6.6 - Latence Inter-AZ Dégradée

### Objectif

Valider l'impact d'une latence réseau élevée entre AZ.

### Procédure

| Étape | Latence Injectée | Observation |
|-------|------------------|-------------|
| 1 | 0 ms (baseline) | Mesure performance |
| 2 | 10 ms | Mesure performance |
| 3 | 50 ms | Mesure performance |
| 4 | 100 ms | Mesure performance |
| 5 | 200 ms | Mesure performance |

### Commandes

```bash
# Injection latence (sur broker/ZK)
tc qdisc add dev eth0 root netem delay 50ms

# Retrait
tc qdisc del dev eth0 root
```

### Grille de Résultats

| Latence Inter-AZ | Latence Kafka P99 | Throughput | ZK Latency | Statut |
|------------------|-------------------|------------|------------|--------|
| 0 ms | _____ ms | _____ msg/s | _____ ms | ☐ OK |
| 10 ms | _____ ms | _____ msg/s | _____ ms | ☐ OK |
| 50 ms | _____ ms | _____ msg/s | _____ ms | ☐ OK |
| 100 ms | _____ ms | _____ msg/s | _____ ms | ☐ Dégradé |
| 200 ms | _____ ms | _____ msg/s | _____ ms | ☐ Critique |

### Seuils Identifiés

| Seuil | Latence Inter-AZ |
|-------|------------------|
| Performance nominale | < _____ ms |
| Performance dégradée | > _____ ms |
| Service critique | > _____ ms |

---

## 6.9 Synthèse Multi-AZ

### Matrice de Disponibilité

| Configuration | Kafka | ZooKeeper | MM2 | Service Global |
|---------------|-------|-----------|-----|----------------|
| 3/3 AZ | ✓ | ✓ | ✓ | Nominal |
| 2/3 AZ | ✓ (dégradé) | ✓ | ✓ (dégradé) | Opérationnel |
| 1/3 AZ | ✗ | ✗ | ✗ | Indisponible |

### Temps de Récupération par Scénario

| Scénario | RTO Mesuré | RTO Cible | RPO |
|----------|------------|-----------|-----|
| Perte AZ1 | _____ s | < 120 s | 0 |
| Perte AZ2 | _____ s | < 120 s | 0 |
| Perte AZ3 | _____ s | < 120 s | 0 |
| Split-brain | _____ s | < 120 s | 0 |

---

## 6.10 Checklist de Fin de Section

### Validation des Tests

- [ ] Test 6.1 - Perte AZ1
- [ ] Test 6.2 - Perte AZ2
- [ ] Test 6.3 - Perte AZ3
- [ ] Test 6.4 - Perte séquentielle
- [ ] Test 6.5 - Split-brain
- [ ] Test 6.6 - Latence inter-AZ

### Résultat Global Section 6

| Critère | Statut |
|---------|--------|
| Failover AZ < 2 min | ☐ PASS ☐ FAIL |
| Service maintenu avec 2/3 AZ | ☐ PASS ☐ FAIL |
| Aucune perte données | ☐ PASS ☐ FAIL |
| Split-brain géré correctement | ☐ PASS ☐ FAIL |

---

**Section précédente** : [Tests de Résilience MirrorMaker 2](05-tests-resilience-mm2.md)  
**Section suivante** : [Tests de Réplication Bout-en-Bout](07-tests-replication-e2e.md)
