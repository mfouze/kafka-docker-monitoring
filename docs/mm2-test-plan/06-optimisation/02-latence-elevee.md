# Symptôme : Latence p99 Explose

## Diagnostic

### Dashboard à Consulter

**`mm2-replication.json`** → Panels "Avg/Max Replication Latency"

### Identifier le Goulot d'Étranglement

| Vérification | Dashboard/Commande | Seuil |
|--------------|-------------------|-------|
| Réseau source→worker | `ping kafka-source-1` | < 10ms |
| Réseau worker→target | `ping kafka-target-1` | < 10ms |
| Throttle time | mm2-detailed "Throttle Time" | < 100ms |
| Commit time | mm2-detailed "Offset Commit Time" | < 5000ms |
| Buffer utilization | mm2-detailed | < 70% |

---

## Actions Correctives

### Priorité P0 (Immédiat)

| Cause | Action | Paramètre |
|-------|--------|-----------|
| **Quota atteint** | Augmenter quota target | `producer_byte_rate` |
| **linger.ms élevé** | Réduire | `producer.linger.ms=0` |

```bash
# Vérifier/modifier quota
kafka-configs.sh --bootstrap-server $KAFKA_TARGET \
  --describe --entity-type users --entity-name mm2-user

kafka-configs.sh --bootstrap-server $KAFKA_TARGET \
  --alter --add-config 'producer_byte_rate=104857600' \
  --entity-type users --entity-name mm2-user
```

### Priorité P1 (Court terme)

| Cause | Action | Impact |
|-------|--------|--------|
| **Compression lente** | Changer pour lz4 | `compression.type=lz4` |
| **acks=all lent** | acks=1 (si acceptable) | ⚠️ Durabilité réduite |
| **Batch trop gros** | Réduire batch | `batch.size=16384` |

### Priorité P2 (Moyen terme)

| Action | Détail |
|--------|--------|
| Rapprocher workers des clusters | Architecture réseau |
| Dédier NIC pour replication | Isolation trafic |
| Optimiser JVM | Tuning GC |

---

## Vérification Réseau

### Latence Inter-Datacenter

```bash
# Mesurer RTT
for host in kafka-source-1 kafka-target-1; do
  echo "=== $host ==="
  ping -c 10 $host | tail -1
done
```

### Bande Passante

```bash
# Sur un worker, vers target
iperf3 -c kafka-target-1 -t 10
```

---

## Impact Configuration Producer MM2

| Paramètre | Effet sur Latence | Trade-off |
|-----------|-------------------|-----------|
| `linger.ms=0` | ↓ Latence | ↓ Throughput |
| `batch.size` petit | ↓ Latence | ↓ Throughput |
| `acks=1` | ↓ Latence | ↓ Durabilité |
| `compression=none` | ↓ Latence | ↑ Bande passante |

---

## Procédure de Résolution

```
Latence élevée
   │
   ├─► Throttle time > 0 ?
   │   └─► OUI → Augmenter quotas
   │
   ├─► Latence réseau > 50ms ?
   │   └─► OUI → Rapprocher workers
   │
   ├─► Buffer > 80% ?
   │   └─► OUI → Backpressure, voir lag
   │
   ├─► linger.ms > 10 ?
   │   └─► OUI → Réduire linger.ms
   │
   └─► Aucun des above ?
       └─► Vérifier GC, CPU, IOPS
```
