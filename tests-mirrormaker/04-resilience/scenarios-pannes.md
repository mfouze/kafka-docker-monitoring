# Scénarios de Pannes - Tests de Résilience MirrorMaker 2

## Objectif

Définir les scénarios de pannes à simuler pour valider la résilience de MirrorMaker 2 et sa capacité à respecter le SLA de disponibilité (< 1h d'indisponibilité annuelle).

---

## Pré-requis

- [ ] Tests de performance validés (`03-performance/`)
- [ ] Baseline observabilité établie
- [ ] Procédures de rollback documentées
- [ ] Équipe support prévenue
- [ ] Fenêtre de maintenance réservée

---

## 1. Matrice des Scénarios de Pannes

### 1.1 Vue d'Ensemble

| ID | Scénario | Composant | Impact Attendu | Criticité | Priorité |
|----|----------|-----------|----------------|-----------|----------|
| RES-01 | Panne broker source | Kafka Source | Failover leader | Haute | P1 |
| RES-02 | Panne broker cible | Kafka Cible | Failover production MM2 | Haute | P1 |
| RES-03 | Panne worker MM2 | MirrorMaker 2 | Rebalancing Connect | Haute | P1 |
| RES-04 | Panne ZooKeeper source | ZooKeeper | Impact si perte quorum | Haute | P1 |
| RES-05 | Panne ZooKeeper cible | ZooKeeper | Impact si perte quorum | Haute | P1 |
| RES-06 | Panne réseau inter-DC | Réseau | Interruption réplication | Critique | P1 |
| RES-07 | Panne totale cluster source | Kafka Source | Arrêt réplication | Critique | P2 |
| RES-08 | Restart rolling brokers | Kafka | Continuité service | Moyenne | P2 |
| RES-09 | Restart rolling MM2 | Connect | Continuité service | Moyenne | P2 |
| RES-10 | Saturation disque | Système | Comportement limite | Moyenne | P3 |
| RES-11 | Expiration certificats | Sécurité | Authentification | Haute | P2 |
| RES-12 | Perte credentials SASL | Sécurité | Authentification | Haute | P2 |

### 1.2 Mapping SLA

| Scénario | Temps de Reprise Cible | Budget SLA Consommé |
|----------|------------------------|---------------------|
| RES-01 | < 30 sec | 0.5 min |
| RES-02 | < 30 sec | 0.5 min |
| RES-03 | < 60 sec | 1 min |
| RES-04 | < 30 sec (si quorum) | 0.5 min |
| RES-05 | < 30 sec (si quorum) | 0.5 min |
| RES-06 | Dépend de la panne | Variable |
| RES-07 | N/A (arrêt total) | N/A |
| RES-08 | 0 (rolling) | 0 min |
| RES-09 | < 30 sec par worker | < 1 min |

---

## 2. Scénarios Détaillés

### 2.1 RES-01 : Panne d'un Broker Source

**Description :** Simuler l'arrêt brutal d'un broker du cluster source pour valider le failover des leaders de partitions.

**Contexte Transactis :**
- Cluster NEMO (source) : 3 brokers
- Facteur de réplication : 3
- min.insync.replicas : 2

**Étapes :**

| Étape | Action | Commande/Méthode | Durée |
|-------|--------|------------------|-------|
| 1 | Vérifier état initial | Voir commandes ci-dessous | 2 min |
| 2 | Identifier le broker leader | kafka-topics --describe | 1 min |
| 3 | Démarrer charge de test | kafka-producer-perf-test | Continu |
| 4 | Stopper le broker | systemctl stop kafka | Instant |
| 5 | Mesurer temps de failover | Observer métriques | 5 min |
| 6 | Vérifier continuité réplication | Vérifier lag et erreurs | 5 min |
| 7 | Redémarrer le broker | systemctl start kafka | 2 min |
| 8 | Vérifier retour à la normale | Vérifier ISR complet | 5 min |

**Comportement Attendu :**

| Phase | Comportement | Métriques à Observer |
|-------|--------------|----------------------|
| T0 - T+30s | Détection panne, élection leader | kafka_controller_controllerstats_leaderelectionrateandtimems |
| T+30s - T+60s | Reprise production/consommation | Messages In/sec, Lag |
| T+60s+ | Retour état nominal | Under-replicated = 0 après restart |

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Temps de failover | < 30 sec | > 60 sec |
| Messages perdus | 0 | > 0 |
| Interruption réplication | < 30 sec | > 60 sec |
| Under-replicated après restart | 0 en < 5 min | > 0 après 10 min |

---

### 2.2 RES-02 : Panne d'un Broker Cible

**Description :** Simuler l'arrêt brutal d'un broker du cluster cible pour valider la capacité de MM2 à basculer sur les autres brokers.

**Étapes :**

| Étape | Action | Commande/Méthode | Durée |
|-------|--------|------------------|-------|
| 1 | Vérifier état initial | État cluster cible | 2 min |
| 2 | Démarrer charge de test | Production continue | Continu |
| 3 | Stopper un broker cible | systemctl stop kafka | Instant |
| 4 | Observer comportement MM2 | Logs + métriques | 5 min |
| 5 | Mesurer impact sur lag | Grafana/Prometheus | 5 min |
| 6 | Redémarrer le broker | systemctl start kafka | 2 min |
| 7 | Vérifier récupération | Lag retour baseline | 5 min |

**Comportement Attendu :**

| Phase | Comportement | Impact MM2 |
|-------|--------------|------------|
| T0 - T+30s | MM2 détecte erreur production | Retries, reconnexion |
| T+30s - T+60s | MM2 bascule sur brokers restants | Légère augmentation lag |
| T+60s+ | Production reprend | Lag se résorbe |

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Temps de reconnexion MM2 | < 30 sec | > 60 sec |
| Messages perdus | 0 | > 0 |
| Erreurs FAILED_TO_PRODUCE | Transitoires uniquement | Persistantes |
| Lag max pendant panne | < 50000 records | > 100000 records |

---

### 2.3 RES-03 : Panne d'un Worker MirrorMaker 2

**Description :** Simuler l'arrêt d'un worker Connect pour valider le rebalancing des tâches.

**Contexte Transactis :**
- 2-3 workers Connect (cible: 3 workers)
- 8 tâches totales (6 Source + 1 Checkpoint + 1 Heartbeat)

**Étapes :**

| Étape | Action | Commande/Méthode | Durée |
|-------|--------|------------------|-------|
| 1 | Vérifier distribution des tâches | API REST /connectors?expand=status | 2 min |
| 2 | Démarrer charge de test | Production continue | Continu |
| 3 | Stopper un worker MM2 | systemctl stop kafka-connect | Instant |
| 4 | Observer le rebalancing | Logs + API REST | 5 min |
| 5 | Vérifier redistribution tâches | API REST /connectors | 2 min |
| 6 | Mesurer impact sur lag | Grafana/Prometheus | 5 min |
| 7 | Redémarrer le worker | systemctl start kafka-connect | 2 min |
| 8 | Observer nouveau rebalancing | Logs + API REST | 5 min |

**Comportement Attendu :**

| Phase | Comportement | Métriques |
|-------|--------------|-----------|
| T0 | Worker down détecté | connect_worker_rebalancing = 1 |
| T0 - T+60s | Rebalancing en cours | Tâches en UNASSIGNED |
| T+60s+ | Tâches redistribuées | Toutes tâches RUNNING |

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Temps de rebalancing | < 60 sec | > 120 sec |
| Tâches RUNNING après rebalancing | 100% | < 100% |
| Messages perdus | 0 | > 0 |
| Lag pic | < 100000 records | > 200000 records |

---

### 2.4 RES-04 : Panne ZooKeeper Source

**Description :** Simuler la perte d'un nœud ZooKeeper source pour valider le maintien du quorum.

**Contexte Transactis :**
- Ensemble ZooKeeper NEMO : 3 nœuds
- Quorum requis : 2 nœuds (majorité)

**Scénarios :**

| Sous-scénario | Nœuds down | Quorum | Impact attendu |
|---------------|------------|--------|----------------|
| 4a | 1 nœud | Maintenu | Pas d'impact |
| 4b | 2 nœuds | Perdu (si 3 nœuds) | Cluster indisponible |

**Étapes (scénario 4a - perte 1 nœud) :**

| Étape | Action | Durée |
|-------|--------|-------|
| 1 | Vérifier état ZK ensemble | 2 min |
| 2 | Identifier le leader ZK | 1 min |
| 3 | Démarrer charge de test | Continu |
| 4 | Stopper 1 nœud ZK (follower) | Instant |
| 5 | Vérifier maintien quorum | 2 min |
| 6 | Vérifier pas d'impact Kafka | 5 min |
| 7 | Stopper le leader ZK | Instant |
| 8 | Observer élection nouveau leader | 2 min |
| 9 | Redémarrer nœuds ZK | 5 min |

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Impact sur Kafka (1 nœud down) | Aucun | Interruption |
| Élection leader ZK | < 10 sec | > 30 sec |
| Impact sur MM2 | Aucun | Erreurs |

---

### 2.5 RES-05 : Panne ZooKeeper Cible

**Description :** Similaire à RES-04 mais sur le cluster cible.

**Impact spécifique MM2 :**
- MM2 écrit sur le cluster cible
- Si ZK cible down → brokers cible impactés → MM2 ne peut plus produire

**Critères de Succès :** Identiques à RES-04.

---

### 2.6 RES-06 : Panne Réseau Inter-DC

**Description :** Simuler une coupure réseau entre les clusters source et cible.

**Méthodes de simulation :**

| Méthode | Commande | Réversibilité |
|---------|----------|---------------|
| iptables | `iptables -A INPUT -s ${TARGET_NETWORK} -j DROP` | Facile |
| tc (traffic control) | `tc qdisc add dev eth0 root netem loss 100%` | Facile |
| Firewall physique | Modification règle | Selon infra |

**Étapes :**

| Étape | Action | Durée |
|-------|--------|-------|
| 1 | Vérifier connectivité initiale | 2 min |
| 2 | Démarrer charge de test | Continu |
| 3 | Couper le réseau | Instant |
| 4 | Observer comportement MM2 | 10 min |
| 5 | Mesurer accumulation lag source | 10 min |
| 6 | Rétablir le réseau | Instant |
| 7 | Observer rattrapage | Jusqu'à lag=0 |
| 8 | Valider cohérence données | 10 min |

**Comportement Attendu :**

| Phase | MM2 Comportement | Métriques |
|-------|------------------|-----------|
| T0 | Timeout connexions | Erreurs dans logs |
| T0 - T+résolution | Retries continus | Lag augmente |
| Après résolution | Reconnexion auto | Lag diminue |

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Reconnexion automatique | < 60 sec après rétablissement | Intervention manuelle |
| Messages perdus | 0 | > 0 |
| Temps de rattrapage | Selon volume accumulé | > 2x temps théorique |
| Tâches MM2 après reprise | 100% RUNNING | < 100% |

---

### 2.7 RES-07 : Panne Totale Cluster Source

**Description :** Simuler la perte complète du cluster source.

**Objectif :** Valider le comportement de MM2 et documenter la procédure de reprise.

**Étapes :**

| Étape | Action | Durée |
|-------|--------|-------|
| 1 | Documenter état initial | 5 min |
| 2 | Arrêter tous les brokers source | 2 min |
| 3 | Observer comportement MM2 | 5 min |
| 4 | Documenter état MM2 (FAILED attendu) | 5 min |
| 5 | Redémarrer cluster source | 10 min |
| 6 | Observer reprise MM2 | 10 min |
| 7 | Valider intégrité des données | 10 min |

**Note :** Ce scénario est documentaire. En production, la perte totale du cluster source consomme le budget SLA.

---

### 2.8 RES-08 : Restart Rolling Brokers

**Description :** Valider la continuité de service lors d'un rolling restart des brokers.

**Étapes :**

| Étape | Action | Durée |
|-------|--------|-------|
| 1 | Démarrer charge nominale | Continu |
| 2 | Pour chaque broker (séquentiellement) : | - |
| 2a | Stopper le broker | 30 sec |
| 2b | Attendre stabilisation (URP=0) | 2-5 min |
| 2c | Redémarrer le broker | 30 sec |
| 2d | Attendre ISR complet | 2-5 min |
| 3 | Vérifier 0 message perdu | 5 min |

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Interruption service | 0 | > 0 |
| Messages perdus | 0 | > 0 |
| Lag pendant rolling | Pics < 10000 | > 50000 |

---

### 2.9 RES-09 : Restart Rolling Workers MM2

**Description :** Valider la continuité lors d'un rolling restart des workers Connect.

**Étapes :** Similaire à RES-08 pour les workers MM2.

**Particularité :** À chaque restart, un rebalancing se produit.

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Temps total rolling | < 10 min pour 3 workers | > 20 min |
| Messages perdus | 0 | > 0 |
| Tâches FAILED | 0 | > 0 |

---

### 2.10 RES-10 : Saturation Disque

**Description :** Simuler une saturation disque sur un broker ou worker.

**Méthode :**
```bash
# Créer un fichier volumineux pour remplir le disque
dd if=/dev/zero of=/var/kafka-logs/fill.tmp bs=1G count=50
```

**Comportement Attendu :**
- Broker : Erreurs d'écriture, rejection des messages
- MM2 : Erreurs de production, lag augmente

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Détection par alerting | < 5 min | > 15 min |
| Pas de corruption données | 0 corruption | Corruption |
| Reprise après nettoyage | Automatique | Intervention manuelle |

---

### 2.11 RES-11 : Expiration Certificats TLS

**Description :** Simuler l'impact de certificats expirés.

**Méthode :** Utiliser des certificats de test avec courte validité ou modifier la date système.

**Comportement Attendu :**
- Erreurs SSL handshake
- Connexions refusées
- MM2 passe en FAILED

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Alerting avant expiration | 30 jours avant | Pas d'alerte |
| Reprise après renouvellement | < 5 min | > 15 min |

---

### 2.12 RES-12 : Perte Credentials SASL

**Description :** Simuler des credentials invalides ou révoqués.

**Méthode :**
```bash
# Modifier le password dans Kafka
kafka-configs.sh --alter --entity-type users --entity-name mm2-user \
    --add-config 'SCRAM-SHA-512=[password=newpassword]'
```

**Comportement Attendu :**
- Erreurs d'authentification
- MM2 passe en FAILED

**Critères de Succès :**

| Critère | Seuil OK | Seuil KO |
|---------|----------|----------|
| Détection erreur auth | Immédiate | Retardée |
| Reprise après correction | < 2 min | > 10 min |

---

## 3. Priorités et Planning

### 3.1 Ordre d'Exécution Recommandé

| Priorité | Scénarios | Jour |
|----------|-----------|------|
| P1 | RES-01, RES-02, RES-03 | J1 |
| P1 | RES-04, RES-05, RES-06 | J2 |
| P2 | RES-08, RES-09, RES-11, RES-12 | J3 |
| P3 | RES-07, RES-10 | J4 |

### 3.2 Temps Estimé par Scénario

| Scénario | Préparation | Exécution | Analyse | Total |
|----------|-------------|-----------|---------|-------|
| RES-01 | 10 min | 20 min | 15 min | 45 min |
| RES-02 | 10 min | 20 min | 15 min | 45 min |
| RES-03 | 10 min | 25 min | 15 min | 50 min |
| RES-04/05 | 10 min | 30 min | 15 min | 55 min |
| RES-06 | 15 min | 45 min | 20 min | 80 min |
| RES-07 | 10 min | 30 min | 15 min | 55 min |
| RES-08/09 | 10 min | 40 min | 15 min | 65 min |

---

## 4. Risques et Mitigations

| Scénario | Risque Principal | Mitigation |
|----------|------------------|------------|
| RES-01/02 | Perte de données si RF=1 | Vérifier RF ≥ 2 avant test |
| RES-03 | Rebalancing long | Ajuster session.timeout.ms |
| RES-06 | Impossibilité de restaurer | Avoir accès hors-bande |
| RES-07 | Non-reprise automatique | Procédure manuelle documentée |
| RES-10 | Corruption données | Backup avant test |

---

## Artifacts Produits

- [ ] Fiches de résultats par scénario
- [ ] Logs des incidents simulés
- [ ] Métriques MTTR mesurées
- [ ] Rapport de résilience

---

**Client** : Transactis
**Confluent Platform** : 7.7.3
**SLA** : < 1h downtime annuel (99.9886%)
**Version** : 2.0
