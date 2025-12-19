# Recommandations - Synthèse MirrorMaker 2 Transactis

## Objectif

Fournir des recommandations concrètes et actionnables pour améliorer la performance, la résilience et la conformité SLA de l'infrastructure MirrorMaker 2 Transactis (NEMO → Applicatif).

---

## Pré-requis

- [ ] Analyse des goulots complétée (`analyse-goulots.md`)
- [x] Constats J1/J2 documentés
- [x] Observabilité opérationnelle (validé J2)

---

## Contexte Transactis - Priorités Issues J1/J2

| Priorité | Recommandation | Justification |
|----------|----------------|---------------|
| **P0** | Migrer MM2 vers Connect distribué | Éliminer SPOF |
| **P0** | Implémenter ACLs | Sécurité |
| P1 | Ajouter 3ème worker MM2 | HA |
| P1 | Séparer VMs Brokers/MM2 | Contention |
| P2 | Vérifier/renouveler certificats | Maintenance |

**SLA Cible :** < 1h downtime annuel (99.9886%)

---

## 1. Recommandations de Performance

### 1.1 Configuration Kafka Brokers

#### REC-PERF-01 : Optimisation des Threads I/O

**Problème identifié :** Latence I/O élevée sous charge

**Recommandation :**

```properties
# server.properties - Ajuster selon le nombre de cores
num.io.threads=${NUM_CPU_CORES}
num.network.threads=${NUM_CPU_CORES / 2}
num.replica.fetchers=4
```

**Impact attendu :** Réduction de 20-30% de la latence I/O

**Priorité :** Haute

**Effort :** Faible (changement de configuration, rolling restart)

---

#### REC-PERF-02 : Optimisation du Buffer de Socket

**Problème identifié :** Throughput réseau limité

**Recommandation :**

```properties
# server.properties
socket.send.buffer.bytes=1048576
socket.receive.buffer.bytes=1048576
socket.request.max.bytes=104857600
```

**Impact attendu :** Amélioration du throughput réseau de 15-25%

**Priorité :** Moyenne

---

#### REC-PERF-03 : Ajustement des Log Segments

**Problème identifié :** Fragmentation disque, GC sur segments

**Recommandation :**

```properties
# server.properties
log.segment.bytes=1073741824      # 1GB segments
log.retention.check.interval.ms=300000
log.cleaner.threads=2
```

**Impact attendu :** Réduction des pauses de compaction

**Priorité :** Moyenne

---

### 1.2 Configuration MirrorMaker 2

#### REC-PERF-04 : Augmentation du Parallélisme

**Problème identifié :** Sous-utilisation des ressources MM2

**Recommandation :**

```json
{
  "tasks.max": "${TOPIC_PARTITIONS / 2}",
  "consumer.max.poll.records": "1000",
  "consumer.fetch.max.bytes": "52428800"
}
```

**Impact attendu :** Doublement potentiel du throughput

**Priorité :** Haute

---

#### REC-PERF-05 : Optimisation du Producer MM2

**Problème identifié :** Latence de production élevée

**Recommandation :**

```json
{
  "producer.batch.size": "65536",
  "producer.linger.ms": "5",
  "producer.buffer.memory": "67108864",
  "producer.compression.type": "lz4"
}
```

**Impact attendu :** Réduction de 30-40% de la latence de production

**Priorité :** Haute

---

#### REC-PERF-06 : Ajustement de la JVM MM2

**Problème identifié :** Pauses GC impactant le throughput

**Recommandation :**

```bash
# connect-distributed.sh ou service file
KAFKA_HEAP_OPTS="-Xms4G -Xmx4G"
KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC \
    -XX:MaxGCPauseMillis=200 \
    -XX:InitiatingHeapOccupancyPercent=35 \
    -XX:G1HeapRegionSize=16M \
    -XX:+ExplicitGCInvokesConcurrent"
```

**Impact attendu :** Réduction des pauses GC > 500ms de 80%

**Priorité :** Moyenne

---

### 1.3 Configuration Réseau

#### REC-PERF-07 : Tuning TCP pour Haute Performance

**Problème identifié :** Throughput réseau inter-DC limité

**Recommandation :**

```bash
# /etc/sysctl.conf sur tous les serveurs Kafka et MM2
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 65536 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.core.netdev_max_backlog=30000
```

**Impact attendu :** Amélioration du throughput réseau de 20-40%

**Priorité :** Moyenne

---

## 2. Recommandations de Résilience

### 2.1 Haute Disponibilité

#### REC-RES-01 : Augmentation du Nombre de Workers MM2

**Problème identifié :** SPOF si moins de 3 workers

**Recommandation :**

- Minimum 3 workers MM2
- Répartition sur des racks/serveurs physiques différents
- Configuration anti-affinité

**Impact attendu :** Élimination du SPOF, rebalancing plus rapide

**Priorité :** Haute (si < 3 workers actuellement)

---

#### REC-RES-02 : Configuration des Timeouts Connect

**Problème identifié :** Rebalancing trop lent ou trop fréquent

**Recommandation :**

```properties
# connect-distributed.properties
session.timeout.ms=30000
heartbeat.interval.ms=10000
rebalance.timeout.ms=60000
```

**Impact attendu :** Détection de panne en 30s max, stabilité améliorée

**Priorité :** Moyenne

---

#### REC-RES-03 : Réplication Adéquate des Topics Internes

**Problème identifié :** Topics internes Connect vulnérables

**Recommandation :**

```properties
# connect-distributed.properties
config.storage.replication.factor=3
offset.storage.replication.factor=3
status.storage.replication.factor=3
```

**Impact attendu :** Résilience des métadonnées Connect

**Priorité :** Haute

---

### 2.2 Monitoring et Alerting

#### REC-RES-04 : Alertes Proactives

**Problème identifié :** Détection tardive des problèmes

**Recommandation :**

```yaml
# Alertes Prometheus à ajouter
- alert: MM2LagIncreasing
  expr: |
    deriv(sum(kafka_consumer_fetch_manager_records_lag{job="mm2-connect"})[5m:1m]) > 500
  for: 2m
  labels:
    severity: warning

- alert: MM2TaskFailed
  expr: kafka_connect_connector_task_status{status="failed"} > 0
  for: 1m
  labels:
    severity: critical

- alert: KafkaBrokerOffline
  expr: count(up{job="kafka"} == 1) < ${EXPECTED_BROKER_COUNT}
  for: 1m
  labels:
    severity: critical
```

**Impact attendu :** Détection des problèmes en < 5 minutes

**Priorité :** Haute

---

#### REC-RES-05 : Dashboard de Santé Unifié

**Problème identifié :** Visibilité fragmentée

**Recommandation :**

Créer un dashboard Grafana unifié avec :
- État des connecteurs MM2 (gauge)
- Lag en temps réel (graph + gauge)
- Throughput source vs réplication (comparison)
- Latence E2E (percentiles)
- Alertes actives (table)

**Impact attendu :** Temps de diagnostic réduit de 50%

**Priorité :** Moyenne

---

## 3. Recommandations de Sécurité

### 3.1 Gestion des Certificats

#### REC-SEC-01 : Automatisation du Renouvellement

**Problème identifié :** Risque d'expiration non détectée

**Recommandation :**

- Implémenter un job de vérification quotidien
- Alertes à J-90, J-30, J-7 avant expiration
- Procédure de renouvellement automatisée (si possible)

**Impact attendu :** 0 incident lié aux certificats expirés

**Priorité :** Haute

---

#### REC-SEC-02 : Rotation des Credentials

**Problème identifié :** Credentials statiques

**Recommandation :**

- Mettre en place une rotation trimestrielle des mots de passe SASL
- Documenter la procédure de rotation sans interruption
- Tester la procédure régulièrement

**Impact attendu :** Conformité sécurité, réduction du risque

**Priorité :** Moyenne

---

### 3.2 Hardening

#### REC-SEC-03 : Désactivation des Protocoles Obsolètes

**Problème identifié :** TLS 1.0/1.1 potentiellement actifs

**Recommandation :**

```properties
# server.properties
ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3
```

**Impact attendu :** Conformité sécurité

**Priorité :** Moyenne

---

## 4. Recommandations Opérationnelles

### 4.1 Procédures

#### REC-OPS-01 : Runbook de Réponse aux Incidents

**Problème identifié :** Procédures non documentées

**Recommandation :**

Créer des runbooks pour :
- Panne broker Kafka
- Panne worker MM2
- Lag excessif
- Panne réseau inter-DC
- Expiration certificat

**Impact attendu :** MTTR réduit de 30-50%

**Priorité :** Haute

---

#### REC-OPS-02 : Tests de Résilience Périodiques

**Problème identifié :** Pas de validation régulière

**Recommandation :**

- Chaos Engineering trimestriel
- Simulation de panne mensuelle (en heures creuses)
- Drill d'incident semestriel

**Impact attendu :** Équipe préparée, procédures validées

**Priorité :** Moyenne

---

### 4.2 Maintenance

#### REC-OPS-03 : Planning de Maintenance

**Problème identifié :** Maintenances non planifiées

**Recommandation :**

- Fenêtre de maintenance hebdomadaire (dimanche nuit)
- Procédure de rolling restart documentée
- Pré-vérifications et post-vérifications formalisées

**Impact attendu :** Réduction des incidents liés aux maintenances

**Priorité :** Moyenne

---

## 5. Tableau de Synthèse des Recommandations

| ID | Catégorie | Description | Priorité | Effort | Impact |
|----|-----------|-------------|----------|--------|--------|
| REC-PERF-01 | Performance | Threads I/O | Haute | Faible | Élevé |
| REC-PERF-02 | Performance | Buffer socket | Moyenne | Faible | Moyen |
| REC-PERF-03 | Performance | Log segments | Moyenne | Faible | Moyen |
| REC-PERF-04 | Performance | Parallélisme MM2 | Haute | Faible | Élevé |
| REC-PERF-05 | Performance | Producer MM2 | Haute | Faible | Élevé |
| REC-PERF-06 | Performance | JVM MM2 | Moyenne | Faible | Moyen |
| REC-PERF-07 | Performance | Tuning TCP | Moyenne | Moyen | Moyen |
| REC-RES-01 | Résilience | Workers MM2 | Haute* | Élevé | Élevé |
| REC-RES-02 | Résilience | Timeouts Connect | Moyenne | Faible | Moyen |
| REC-RES-03 | Résilience | Topics internes | Haute | Faible | Élevé |
| REC-RES-04 | Résilience | Alertes proactives | Haute | Moyen | Élevé |
| REC-RES-05 | Résilience | Dashboard unifié | Moyenne | Moyen | Moyen |
| REC-SEC-01 | Sécurité | Renouvellement cert | Haute | Moyen | Élevé |
| REC-SEC-02 | Sécurité | Rotation credentials | Moyenne | Moyen | Moyen |
| REC-SEC-03 | Sécurité | TLS hardening | Moyenne | Faible | Moyen |
| REC-OPS-01 | Opérations | Runbooks | Haute | Moyen | Élevé |
| REC-OPS-02 | Opérations | Tests résilience | Moyenne | Moyen | Moyen |
| REC-OPS-03 | Opérations | Planning maintenance | Moyenne | Faible | Moyen |

---

## 6. Plan d'Implémentation Proposé

### 6.1 Phase 1 : Quick Wins (Semaine 1-2)

| Action | ID Recommandation | Responsable | Livrable |
|--------|-------------------|-------------|----------|
| Optimiser config MM2 | REC-PERF-04, 05 | - | Config déployée |
| Ajouter alertes critiques | REC-RES-04 | - | Alertes actives |
| Vérifier certificats | REC-SEC-01 | - | Rapport validité |

### 6.2 Phase 2 : Améliorations (Semaine 3-4)

| Action | ID Recommandation | Responsable | Livrable |
|--------|-------------------|-------------|----------|
| Optimiser JVM | REC-PERF-06 | - | Config déployée |
| Créer runbooks | REC-OPS-01 | - | Documentation |
| Dashboard unifié | REC-RES-05 | - | Dashboard Grafana |

### 6.3 Phase 3 : Consolidation (Mois 2)

| Action | ID Recommandation | Responsable | Livrable |
|--------|-------------------|-------------|----------|
| Tuning réseau | REC-PERF-07 | - | Config déployée |
| Tests résilience | REC-OPS-02 | - | Rapport de test |
| Hardening TLS | REC-SEC-03 | - | Config validée |

---

## 7. Suivi des Recommandations

### 7.1 Template de Suivi

| ID | Statut | Date Implémentation | Validé Par | Résultat |
|----|--------|---------------------|------------|----------|
| REC-PERF-01 | ⬜ À faire | - | - | - |
| REC-PERF-02 | ⬜ À faire | - | - | - |
| ... | ... | ... | ... | ... |

**Légende statut :** ⬜ À faire | 🔄 En cours | ✅ Terminé | ❌ Annulé

---

## 7. Recommandations Spécifiques Transactis (J1/J2)

### 7.1 Actions P0 - Bloquantes Production

| ID | Recommandation | Impact | Effort |
|----|----------------|--------|--------|
| REC-TRS-01 | Migrer MM2 standalone → Connect distribué | Éliminer SPOF | Élevé |
| REC-TRS-02 | Créer ACLs sur NEMO et Applicatif | Sécurité | Moyen |

### 7.2 Actions P1 - Amélioration HA

| ID | Recommandation | Impact | Effort |
|----|----------------|--------|--------|
| REC-TRS-03 | Ajouter 3ème worker MM2 | HA, throughput | Moyen |
| REC-TRS-04 | Séparer VMs brokers/MM2 | Réduire contention | Élevé |

### 7.3 Configurations Tuning (cf. `08-tuning/`)

Voir les fichiers de tuning détaillés :
- `08-tuning/tuning-brokers.md` - server.properties, JVM, sysctl
- `08-tuning/tuning-mm2-connect.md` - Connect config, JSON connecteurs

---

## Artifacts Produits

- [ ] Liste des recommandations priorisées
- [ ] Plan d'implémentation
- [ ] Templates de suivi

---

**Client** : Transactis
**SLA** : < 1h downtime annuel
**Version** : 2.0
