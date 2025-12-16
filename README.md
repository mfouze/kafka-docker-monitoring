# Configuration Prometheus pour Kafka Stack

Ce package contient tous les fichiers nécessaires pour monitorer Kafka, Kafka Connect, Zookeeper et les métriques système avec Prometheus et Grafana.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Host                               │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │   Prometheus    │───▶│     Grafana     │                     │
│  │   :9090         │    │     :3000       │                     │
│  └────────┬────────┘    └─────────────────┘                     │
└───────────┼─────────────────────────────────────────────────────┘
            │
            │ scrape metrics
            ▼
┌───────────────────────────────────────────────────────────────────┐
│                      VMs CentOS                                    │
│                                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐          │
│  │ Kafka        │   │ Kafka Connect│   │ Zookeeper    │          │
│  │ JMX :9991    │   │ JMX :9992    │   │ JMX :9993    │          │
│  │ Node :9100   │   │ Node :9100   │   │ Node :9100   │          │
│  └──────────────┘   └──────────────┘   └──────────────┘          │
└───────────────────────────────────────────────────────────────────┘
```

## Ports utilisés

| Service        | Port | Description               |
|----------------|------|---------------------------|
| Kafka JMX      | 9991 | Métriques JMX Kafka       |
| Connect JMX    | 9992 | Métriques JMX Connect     |
| Zookeeper JMX  | 9993 | Métriques JMX Zookeeper   |
| Node Exporter  | 9100 | Métriques système         |
| Prometheus     | 9090 | Interface Prometheus      |
| Grafana        | 3000 | Interface Grafana         |

## Structure des fichiers

```
prometheus/
├── docker-compose.yml                    # Docker Compose pour Prometheus/Grafana
├── prometheus.yml                        # Configuration Prometheus
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml            # Auto-config datasource
│       └── dashboards/
│           └── dashboards.yml            # Auto-config dashboards
├── jmx-exporter/
│   ├── kafka-jmx-exporter.yml            # Config JMX pour Kafka
│   ├── kafka-connect-jmx-exporter.yml    # Config JMX pour Connect
│   └── zookeeper-jmx-exporter.yml        # Config JMX pour Zookeeper
└── vm-config/
    ├── setup-kafka-jmx.sh                # Script setup Kafka
    ├── setup-kafka-connect-jmx.sh        # Script setup Connect
    ├── setup-zookeeper-jmx.sh            # Script setup Zookeeper
    └── setup-node-exporter.sh            # Script setup Node Exporter
```

## Installation

### Étape 1: Configuration des VMs (sur chaque VM CentOS)

#### 1.1 Installer Node Exporter (sur TOUTES les VMs)

```bash
chmod +x setup-node-exporter.sh
sudo ./setup-node-exporter.sh
```

#### 1.2 Configurer JMX Exporter sur les brokers Kafka

```bash
# Copier les fichiers sur la VM
scp jmx-exporter/kafka-jmx-exporter.yml user@kafka-broker:/opt/jmx-exporter/

# Sur la VM Kafka
chmod +x setup-kafka-jmx.sh
sudo ./setup-kafka-jmx.sh

# Éditer le service Kafka pour ajouter KAFKA_OPTS
sudo vi /etc/systemd/system/kafka.service
# Ajouter: Environment="KAFKA_OPTS=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9991:/opt/jmx-exporter/kafka-jmx-exporter.yml"

sudo systemctl daemon-reload
sudo systemctl restart kafka
```

#### 1.3 Configurer JMX Exporter sur Kafka Connect

```bash
# Copier les fichiers sur la VM
scp jmx-exporter/kafka-connect-jmx-exporter.yml user@kafka-connect:/opt/jmx-exporter/

# Sur la VM Kafka Connect
chmod +x setup-kafka-connect-jmx.sh
sudo ./setup-kafka-connect-jmx.sh

# Éditer le service Kafka Connect pour ajouter KAFKA_OPTS
sudo vi /etc/systemd/system/kafka-connect.service
# Ajouter: Environment="KAFKA_OPTS=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9992:/opt/jmx-exporter/kafka-connect-jmx-exporter.yml"

sudo systemctl daemon-reload
sudo systemctl restart kafka-connect
```

#### 1.4 Configurer JMX Exporter sur Zookeeper

```bash
# Copier les fichiers sur la VM
scp jmx-exporter/zookeeper-jmx-exporter.yml user@zookeeper:/opt/jmx-exporter/

# Sur la VM Zookeeper
chmod +x setup-zookeeper-jmx.sh
sudo ./setup-zookeeper-jmx.sh

# Éditer le service Zookeeper pour ajouter KAFKA_OPTS
sudo vi /etc/systemd/system/zookeeper.service
# Ajouter: Environment="KAFKA_OPTS=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9993:/opt/jmx-exporter/zookeeper-jmx-exporter.yml"

sudo systemctl daemon-reload
sudo systemctl restart zookeeper
```

### Étape 2: Configuration de Prometheus (sur le serveur Docker)

#### 2.1 Modifier prometheus.yml

Adapter les IPs dans `prometheus.yml` et `docker-compose.yml` selon votre environnement:

```yaml
# prometheus.yml - exemple
- job_name: 'kafka'
  static_configs:
    - targets:
        - '192.168.1.10:9991'   # IP réelle du broker 1
        - '192.168.1.11:9991'   # IP réelle du broker 2
        - '192.168.1.12:9991'   # IP réelle du broker 3
```

#### 2.2 Démarrer Prometheus et Grafana

```bash
cd prometheus/
docker-compose up -d
```

### Étape 3: Vérification

```bash
# Vérifier que les targets sont UP dans Prometheus
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'

# Accéder à Grafana
# URL: http://localhost:3000
# Login: admin / admin
```

## Métriques principales collectées

### Kafka Brokers
- `kafka_server_brokertopicmetrics_*` - Débit messages/bytes
- `kafka_server_replicamanager_*` - État des réplicas
- `kafka_controller_kafkacontroller_*` - État du controller
- `kafka_network_requestmetrics_*` - Latence des requêtes
- `kafka_cluster_partition_*` - État des partitions

### Kafka Connect
- `kafka_connect_worker_*` - Métriques worker
- `kafka_connect_connector_*` - État des connecteurs
- `kafka_connect_source_task_*` - Métriques source tasks
- `kafka_connect_sink_task_*` - Métriques sink tasks
- `kafka_connect_task_error_*` - Erreurs des tasks

### Zookeeper
- `zookeeper_*` - Latence, connexions, watches
- `zookeeper_node_count` - Nombre de znodes
- `zookeeper_outstanding_requests` - Requêtes en attente

### Node Exporter (Système)
- `node_cpu_*` - Utilisation CPU
- `node_memory_*` - Utilisation mémoire
- `node_disk_*` - I/O disque
- `node_network_*` - Trafic réseau
- `node_filesystem_*` - Espace disque

## Dashboards Grafana recommandés

Importer ces dashboards depuis grafana.com:

| ID    | Nom                           | Description                    |
|-------|-------------------------------|--------------------------------|
| 7589  | Kafka Exporter Overview       | Vue d'ensemble Kafka           |
| 11962 | Kafka Connect Overview        | Vue d'ensemble Connect         |
| 10465 | Zookeeper                     | Métriques Zookeeper            |
| 1860  | Node Exporter Full            | Métriques système complètes    |
| 11074 | Node Exporter Dashboard       | Vue simplifiée système         |

## Dépannage

### Les métriques JMX ne remontent pas

```bash
# Vérifier que le port JMX est ouvert
curl http://<IP>:9991/metrics

# Vérifier les logs Kafka
journalctl -u kafka -f

# Vérifier que KAFKA_OPTS est bien défini
ps aux | grep kafka | grep javaagent
```

### Node Exporter ne répond pas

```bash
# Vérifier le service
sudo systemctl status node_exporter

# Vérifier le firewall
sudo firewall-cmd --list-ports
```

### Prometheus ne scrape pas les targets

```bash
# Vérifier la connectivité depuis le container Docker
docker exec prometheus wget -qO- http://<IP>:9991/metrics

# Vérifier les logs Prometheus
docker logs prometheus
```
