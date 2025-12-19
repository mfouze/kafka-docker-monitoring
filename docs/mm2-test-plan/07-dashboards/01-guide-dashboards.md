# Guide des Dashboards Grafana pour Tests MM2

## Vue d'Ensemble des Dashboards

| Dashboard | Fichier | Rôle Principal |
|-----------|---------|----------------|
| **MM2 Replication** | `mm2-replication.json` | Latence, throughput, santé réplication |
| **MM2 Detailed** | `mm2-detailed-metrics.json` | Tasks, buffer, erreurs, producer |
| **Kafka Connect Cluster** | `kafka-connect-cluster.json` | Workers, connecteurs, rebalances |
| **Kafka Cluster** | `kafka-cluster.json` | Brokers, partitions, ISR |
| **Kafka Consumer** | `kafka-consumer.json` | Lag consumer groups |
| **Node Exporter** | `Node-Eporter.json` | CPU, RAM, disque, réseau |

---

## Dashboard par Phase de Test

| Phase | Dashboard Principal | Dashboards Secondaires |
|-------|---------------------|------------------------|
| Phase 0 - Préparation | kafka-connect-cluster | kafka-cluster |
| Phase 1 - Smoke Test | mm2-replication | mm2-detailed |
| Phase 2 - Charge Nominale | mm2-replication | mm2-detailed, Node-Exporter |
| Phase 3 - Latence E2E | mm2-replication | - |
| Phase 4 - Montée Charge | mm2-detailed | Node-Exporter |
| Phase 5 - Long Run | TOUS | - |
| Phase 6 - Résilience | kafka-connect-cluster | mm2-replication |
| Phase 7 - Erreurs | mm2-detailed | kafka-connect-cluster |

---

## MM2 Replication Dashboard

**Fichier** : `grafana/dashboards/mm2-replication.json`

### Panels Principaux

| Panel | Ce qu'il montre | Quand le regarder |
|-------|-----------------|-------------------|
| **Avg Replication Latency** | Latence moyenne source→target | Validation SLO |
| **Max Replication Latency** | Pire cas de latence | Pics |
| **Total Records Replicated** | Compteur cumulé | Progression |
| **Total Bytes Replicated** | Volume total | Throughput |
| **Replication Latency by Topic/Partition** | Détail par partition | Hot partitions |
| **Record Rate by Topic** | Throughput par topic | Distribution |
| **Byte Rate by Topic** | Débit par topic | Distribution |
| **Avg/Max Record Age** | Âge des messages | Backlog |

### Variables de Filtrage

- `$topic` : Filtrer par topic

### Seuils Configurés

```
Latence :
  Vert   : < 100ms
  Jaune  : 100-500ms
  Orange : 500-1000ms
  Rouge  : > 1000ms
```

### Utilisation Typique

1. Ouvrir le dashboard
2. Sélectionner la fenêtre temporelle (ex: Last 30 minutes)
3. Observer les panels de latence
4. Si pic visible → zoomer pour identifier le moment
5. Vérifier si toutes les partitions sont uniformes

---

## MM2 Detailed Metrics Dashboard

**Fichier** : `grafana/dashboards/mm2-detailed-metrics.json`

### Panels Principaux

| Panel | Ce qu'il montre | Seuil Warning | Seuil Critical |
|-------|-----------------|---------------|----------------|
| **Total Records Polled** | Messages lus du source | - | - |
| **Total Records Written** | Messages écrits sur target | - | - |
| **Active Records (Lag)** | Messages en cours de traitement | > 5000 | > 10000 |
| **Replication Ratio** | write/poll % | < 99% | < 95% |
| **Offset Commit Max Time** | Temps de commit | > 5000ms | > 10000ms |
| **Offset Commit Failure %** | Échecs de commit | > 1% | > 5% |
| **Buffer Total vs Available** | État du buffer producer | - | - |
| **Buffer Utilization %** | Remplissage buffer | > 70% | > 90% |
| **Buffer Exhausted Total** | Événements buffer plein | > 0 | > 10 |
| **Producer Throttle Time Max** | Limitation par quota | > 100ms | > 1000ms |
| **Producer Record Error Total** | Erreurs d'envoi | > 0 | - |
| **Last Error Timestamp** | Quand la dernière erreur | - | - |

### Variables de Filtrage

- `$env` : Environnement
- `$kafka_connect_cluster` : Cluster Connect
- `$connector` : Nom du connecteur
- `$instance` : Worker spécifique

### Utilisation Typique

1. **Pendant charge** : Surveiller "Active Records (Lag)" et "Replication Ratio"
2. **Si problème** : Regarder "Buffer Utilization" et "Throttle Time"
3. **Après incident** : Vérifier "Last Error Timestamp"

---

## Kafka Connect Cluster Dashboard

**Fichier** : `grafana/dashboards/kafka-connect-cluster.json`

### Panels Principaux

| Panel | Ce qu'il montre | Attendu |
|-------|-----------------|---------|
| **Workers Online** | Nombre de workers UP | Tous |
| **Connector Count** | Nombre de connecteurs | Stable |
| **Task Count** | Nombre total de tasks | Stable |
| **Failed Connectors** | Connecteurs en erreur | 0 |
| **Failed Tasks** | Tasks en erreur | 0 |
| **Rebalance Count** | Nombre de rebalances | Minimal |

### Utilisation Typique

1. **Phase 0** : Vérifier tous les workers UP
2. **Phase 6** : Observer pendant restart worker
3. **Troubleshooting** : Identifier connector/task en échec

---

## Kafka Cluster Dashboard

**Fichier** : `grafana/dashboards/kafka-cluster.json`

### Panels Principaux

| Panel | Ce qu'il montre | Seuil |
|-------|-----------------|-------|
| **Online Brokers** | Brokers disponibles | Tous |
| **Under Replicated Partitions** | Partitions sous-répliquées | 0 |
| **Offline Partitions** | Partitions inaccessibles | 0 |
| **ISR Shrink Rate** | Fréquence réduction ISR | ~0 |
| **ISR Expand Rate** | Fréquence expansion ISR | ~0 |

### Utilisation Typique

- Vérifier santé du cluster avant tests
- Surveiller pendant test de résilience broker

---

## Node Exporter Dashboard

**Fichier** : `grafana/dashboards/Node-Eporter.json`

### Panels Principaux

| Panel | Métrique | Seuil Warning | Seuil Critical |
|-------|----------|---------------|----------------|
| **CPU Usage** | Utilisation CPU | > 70% | > 85% |
| **Memory Usage** | Utilisation RAM | > 80% | > 90% |
| **Disk Usage** | Espace disque | > 80% | > 90% |
| **Network I/O** | Trafic réseau | Pic anormal | Saturation |
| **Load Average** | Charge système | > cores | > 2× cores |

### Utilisation Typique

1. **Long Run** : Vérifier tendance memory (leak?)
2. **Montée Charge** : Observer CPU approche saturation
3. **Performance** : Identifier bottleneck (CPU/RAM/IO)

---

## Configuration des Alertes dans Grafana

### Exemple : Alerte Lag Élevé

1. Ouvrir panel "Active Records (Lag)"
2. Edit → Alert tab
3. Configurer :
   - Condition: `WHEN avg() OF query IS ABOVE 10000`
   - For: `5m`
   - Notifications: Slack/Email

### Alertes Recommandées

| Panel | Condition | Délai | Sévérité |
|-------|-----------|-------|----------|
| Lag | > 10000 | 5 min | Critical |
| Latence avg | > 5000ms | 5 min | Critical |
| Buffer Utilization | > 90% | 2 min | Warning |
| Failed Tasks | > 0 | 2 min | Critical |
| Workers Online | < expected | 2 min | Critical |

---

## Checklist Dashboards par Phase

### Phase 1 - Smoke Test

```
☐ Ouvrir mm2-replication.json
☐ Vérifier "Total Records Polled" augmente après envoi messages
☐ Vérifier "Total Records Written" ≈ Polled
☐ Noter latence baseline dans "Avg Replication Latency"
☐ Vérifier "Replication Latency by Topic/Partition" uniforme
```

### Phase 2 - Charge Nominale

```
☐ Ouvrir mm2-replication.json en premier écran
☐ Ouvrir mm2-detailed-metrics.json en second écran
☐ Surveiller "Active Records (Lag)" reste stable
☐ Surveiller latence reste < 1000ms
☐ Ouvrir Node-Exporter.json pour CPU/RAM
```

### Phase 5 - Long Run

```
☐ Ouvrir tous les dashboards
☐ Configurer auto-refresh 30s
☐ À chaque checkpoint, noter :
   - Latence (mm2-replication)
   - Lag (mm2-detailed)
   - CPU/Memory (Node-Exporter)
☐ Vérifier tendance stable (pas de dérive)
```

### Phase 6 - Résilience

```
☐ Ouvrir kafka-connect-cluster.json
☐ Surveiller "Workers Online" pendant restart
☐ Observer "Rebalance Count" augmenter
☐ Mesurer durée avant retour à normal
☐ Basculer sur mm2-replication pour vérifier pic latence
```
